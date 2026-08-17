#!/usr/bin/env python3
"""
智慧工地 - 统一区域管理工具
============================

功能：
  1) list     : 解析并展示现有区域配置（自动识别格式）
  2) validate : 校验 JSON 配置合法性（顶点数、自交、坐标范围、重叠等）
  3) convert  : 从 site_geofence.json (GPS danger) → 另存为 danger_zones.json
     或  danger_zones.json → 转换坐标系统
  4) extract  : 从 site_geofence.json 提取指定类型/区域，输出单独文件

用法：
  python scripts/zones_tool.py list configs/danger_zones.json
  python scripts/zones_tool.py list configs/site_geofence.json
  python scripts/zones_tool.py validate configs/danger_zones.json
  python scripts/zones_tool.py extract configs/site_geofence.json --type danger --out configs/danger_zones_from_geofence.json
  python scripts/zones_tool.py validate configs/site_geofence.json --coords gps_wgs84
"""
import argparse
import json
import sys
import os
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from utils.common import (
    load_unified_zones,
    print_zones_summary,
    ZoneType,
    ZoneCoords,
    polygon_area,
    point_in_polygon,
)


def cmd_list(args) -> int:
    zones = load_unified_zones(args.input)
    if not zones:
        print("⚠️  未加载到任何区域")
        return 1
    print_zones_summary(zones, title=os.path.basename(args.input))
    return 0


def _self_intersects(points) -> bool:
    """简单检查：线段两两相交（除相邻外）"""
    from shapely.geometry import Polygon
    try:
        p = Polygon(points)
        return not p.is_simple
    except Exception:
        return False


def cmd_validate(args) -> int:
    zones = load_unified_zones(args.input)
    if not zones:
        print("❌ 未加载到任何区域")
        return 1
    errors = 0
    warns = 0
    print(f"📋 校验: {args.input}")
    print(f"  区域总数: {len(zones)}")
    print("-" * 64)
    for z in zones:
        ok = True
        pts = z["points"]
        # 基本检查
        if len(pts) < 3:
            print(f"❌ [{z['id']}] 顶点数 {len(pts)} < 3")
            errors += 1
            continue
        # 坐标范围检查
        coords = z["coords"]
        xs = [p[0] for p in pts]
        ys = [p[1] for p in pts]
        if coords == ZoneCoords.PIXEL_NORM.value:
            if not (0.0 <= min(xs) and max(xs) <= 1.05 and 0.0 <= min(ys) and max(ys) <= 1.05):
                print(f"❌ [{z['id']}] pixel_norm 坐标超出 0~1: "
                      f"x∈[{min(xs):.3f},{max(xs):.3f}] y∈[{min(ys):.3f},{max(ys):.3f}]")
                errors += 1
                ok = False
        # 自相交检查 (尝试 import shapely)
        try:
            if _self_intersects(pts):
                print(f"⚠️  [{z['id']}] 多边形可能存在自交")
                warns += 1
        except Exception:
            pass
        # 面积检查 (不同坐标系的阈值不同)
        area = abs(polygon_area([(p[0], p[1]) for p in pts]))
        # pixel_norm: 区域太小 < 0.01×0.01=1e-4 才告警 (小于约 6×6 像素@640p)
        # gps_wgs84 : 1e-10 平方度 ≈ 1㎡，小于此算极小无效区
        # pixel_abs : 小于 100 像素²(约10×10)算无效
        min_area = {
            ZoneCoords.PIXEL_NORM.value: 1e-5,
            ZoneCoords.GPS_WGS84.value: 1e-12,
            ZoneCoords.PIXEL_ABS.value: 100.0,
        }.get(z["coords"], 1e-8)
        if area < min_area:
            print(f"❌ [{z['id']}] 面积极小无效 ({area:.2e} < 阈值 {min_area:.2e})")
            errors += 1
            ok = False
        # 首末点是否闭合 (不强制, 仅提示)
        if pts[0][0] != pts[-1][0] or pts[0][1] != pts[-1][1]:
            pass  # point_in_polygon 已支持非闭合
        status = "✅" if ok else "❌"
        print(f"{status} [{z['id']:22s}] {z['name']:16s} type={z['type']:10s} "
              f"coords={z['coords']:11s} 顶点={len(pts):2d} 面积={area:.4f}")
    # 坐标过滤一致性 (仅警告)
    if args.coords:
        bad = [z for z in zones if z["coords"] != args.coords]
        if bad:
            print(f"⚠️  {len(bad)} 个区域坐标系不是 {args.coords}: "
                  f"{[z['id'] for z in bad]}")
            warns += 1
    print("-" * 64)
    print(f"结果: 错误={errors}  警告={warns}")
    return 1 if errors else 0


def cmd_extract(args) -> int:
    filter_types = None
    if args.type:
        map_ = {"danger": ZoneType.DANGER, "restricted": ZoneType.RESTRICTED,
                "work": ZoneType.WORK, "safe": ZoneType.SAFE}
        ts = []
        for t in args.type.split(","):
            t = t.strip()
            if t in map_:
                ts.append(map_[t])
            else:
                print(f"❌ 未知类型 {t}，支持: danger/restricted/work/safe")
                return 1
        filter_types = ts
    filter_coords = None
    if args.coords:
        map_ = {"pixel_norm": ZoneCoords.PIXEL_NORM,
                "pixel_abs": ZoneCoords.PIXEL_ABS,
                "gps_wgs84": ZoneCoords.GPS_WGS84}
        cs = []
        for c in args.coords.split(","):
            c = c.strip()
            if c in map_:
                cs.append(map_[c])
            else:
                print(f"❌ 未知 coords {c}，支持: pixel_norm/pixel_abs/gps_wgs84")
                return 1
        filter_coords = cs
    zones = load_unified_zones(args.input, filter_types=filter_types, filter_coords=filter_coords)
    if not zones:
        print("⚠️  过滤后结果为空，未生成输出")
        return 1
    print_zones_summary(zones, title="提取结果")
    out = {
        "_version": "1.0",
        "_schema": "standard-zones",
        "_source": args.input,
        "zones": zones,
    }
    Path(args.out).parent.mkdir(parents=True, exist_ok=True)
    with open(args.out, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, indent=2)
    print(f"\n✅ 已写入 {args.out}  (共 {len(zones)} 个区域)")
    return 0


def cmd_convert(args) -> int:
    """危险区域配置 → site_geofence 子区域 / 或反向"""
    zones = load_unified_zones(args.input)
    if not zones:
        print("❌ 源区域为空")
        return 1
    if args.format == "danger_zones":
        out = {"_version": "1.0", "_schema": "standard-zones", "zones": zones}
    elif args.format == "site_geofence_subzones":
        sub_zones = []
        for z in zones:
            sub_zones.append({
                "id": z["id"],
                "name": z["name"],
                "type": z["type"],
                "boundary": z["points"],
                "alert_level": z.get("alert_level", "low"),
                "description": z.get("description", ""),
            })
        out = {"sub_zones": sub_zones}
    else:
        print(f"❌ 未知格式: {args.format}")
        return 1
    Path(args.out).parent.mkdir(parents=True, exist_ok=True)
    with open(args.out, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, indent=2)
    print(f"✅ 已转换 {len(zones)} 个区域 → {args.out}  (格式={args.format})")
    return 0


def main():
    parser = argparse.ArgumentParser(description="智慧工地统一区域管理工具",
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="cmd", required=True)

    p_list = sub.add_parser("list", help="列出区域")
    p_list.add_argument("input", help="JSON 文件路径")
    p_list.set_defaults(func=cmd_list)

    p_val = sub.add_parser("validate", help="校验配置")
    p_val.add_argument("input", help="JSON 文件路径")
    p_val.add_argument("--coords", choices=["pixel_norm", "pixel_abs", "gps_wgs84"],
                       default=None, help="强制检查所有区域坐标系")
    p_val.set_defaults(func=cmd_validate)

    p_ext = sub.add_parser("extract", help="按类型/坐标提取子集")
    p_ext.add_argument("input", help="源 JSON")
    p_ext.add_argument("--type", help="类型过滤，逗号分隔：danger,restricted,work,safe")
    p_ext.add_argument("--coords", help="坐标过滤，逗号分隔：pixel_norm,pixel_abs,gps_wgs84")
    p_ext.add_argument("--out", required=True, help="输出文件")
    p_ext.set_defaults(func=cmd_extract)

    p_cvt = sub.add_parser("convert", help="格式转换")
    p_cvt.add_argument("input", help="源 JSON")
    p_cvt.add_argument("--format", required=True,
                       choices=["danger_zones", "site_geofence_subzones"])
    p_cvt.add_argument("--out", required=True, help="输出文件")
    p_cvt.set_defaults(func=cmd_convert)

    args = parser.parse_args()
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
