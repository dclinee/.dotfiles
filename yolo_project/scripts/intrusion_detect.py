#!/usr/bin/env python3
"""
智慧工地 - 危险区域入侵检测
检测人员是否进入预设的危险区域 (多边形/线段)
"""

import argparse
import json
import os
import sys
from pathlib import Path
from datetime import datetime
import cv2
import numpy as np
from ultralytics import YOLO

# 添加项目根目录到 path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from utils.notify import LarkNotifier, alarm_intrusion


class IntrusionDetector:
    """危险区域入侵检测器"""

    def __init__(self, model_path, danger_zones, conf=0.3, device="0",
                 notify=False, personnel_config="configs/personnel.json"):
        """
        Args:
            model_path: YOLO 模型路径
            danger_zones: 危险区域列表, 每个区域是 [(x1,y1), (x2,y2), ...] 多边形顶点
            conf: 置信度阈值
        """
        self.model = YOLO(model_path)
        self.danger_zones = danger_zones  # 归一化坐标 (0~1)
        self.conf = conf
        self.device = device

        self.alarm_log = []
        self.alarm_cooldown = {}

        # 飞书通知
        self.notify = notify
        self.notifier = LarkNotifier(personnel_config) if notify else None

    def set_danger_zones(self, zones):
        """设置危险区域 (归一化坐标 0~1)"""
        self.danger_zones = zones
        print(f"已设置 {len(zones)} 个危险区域")

    def point_in_polygon(self, point, polygon):
        """判断点是否在多边形内 (射线法)"""
        x, y = point
        n = len(polygon)
        inside = False

        j = n - 1
        for i in range(n):
            xi, yi = polygon[i]
            xj, yj = polygon[j]

            if ((yi > y) != (yj > y)) and (x < (xj - xi) * (y - yi) / (yj - yi) + xi):
                inside = not inside
            j = i

        return inside

    def box_center_in_zone(self, box_xyxy, zone, img_w, img_h):
        """判断检测框中心是否在危险区域内"""
        x1, y1, x2, y2 = box_xyxy
        cx = (x1 + x2) / 2
        cy = (y1 + y2) / 2

        # 将归一化 zone 坐标转为像素坐标
        zone_px = [(x * img_w, y * img_h) for x, y in zone]
        return self.point_in_polygon((cx, cy), zone_px)

    def detect(self, source, save=True, show=False, alarm_interval=5):
        """执行入侵检测"""
        results = self.model.predict(
            source=source,
            conf=self.conf,
            device=self.device,
            save=save,
            project="runs/intrusion",
            name=datetime.now().strftime("%Y%m%d_%H%M%S"),
            show=show,
            stream=True,
        )

        frame_count = 0
        intrusion_count = 0

        for result in results:
            frame_count += 1
            boxes = result.boxes

            if boxes is None or len(boxes) == 0:
                continue

            # 获取原始图片尺寸
            img = result.orig_img
            if img is None:
                continue
            img_h, img_w = img.shape[:2]

            # 筛选人员类别 (class 0)
            person_boxes = []
            for box in boxes:
                if int(box.cls[0]) == 0 and float(box.conf[0]) >= self.conf:
                    person_boxes.append(box.xyxy[0].tolist())

            # 检查入侵
            frame_intrusions = []
            for pb in person_boxes:
                for zi, zone in enumerate(self.danger_zones):
                    if self.box_center_in_zone(pb, zone, img_w, img_h):
                        frame_intrusions.append({
                            "zone_id": zi,
                            "box": pb,
                        })
                        break

            if frame_intrusions:
                intrusion_count += 1
                self._log_intrusion(frame_count, frame_intrusions, alarm_interval)

        print(f"\n{'='*50}")
        print(f"入侵检测完成")
        print(f"总帧数: {frame_count}")
        print(f"入侵帧数: {intrusion_count}")
        print(f"报警记录: {len(self.alarm_log)} 条")
        print(f"{'='*50}")

    def _log_intrusion(self, frame_id, intrusions, alarm_interval):
        """记录入侵事件"""
        now = datetime.now()
        timestamp = now.strftime("%Y-%m-%d %H:%M:%S")

        for intr in intrusions:
            zone_id = intr["zone_id"]
            cooldown_key = f"zone_{zone_id}"

            if cooldown_key in self.alarm_cooldown:
                if (now - self.alarm_cooldown[cooldown_key]).seconds < alarm_interval:
                    continue

            self.alarm_cooldown[cooldown_key] = now
            msg = f"[{timestamp}] Frame {frame_id}: 人员闯入危险区域 #{zone_id}"
            self.alarm_log.append(msg)
            print(f"  [INTRUSION] {msg}")

            # 飞书通知
            if self.notify:
                zone_name = f"Zone_{zone_id}"
                # 尝试从 danger_zones 配置中获取区域名称
                danger_zones_config = getattr(self, "danger_zones_config", None)
                if danger_zones_config and zone_id < len(danger_zones_config):
                    zone_name = danger_zones_config[zone_id].get("name", zone_name)
                self.notifier.send_alarm(
                    "intrusion",
                    camera_id=getattr(self, "camera_id", None),
                    zone_name=zone_name,
                )

    def save_log(self, path="runs/intrusion/intrusion_log.txt"):
        """保存入侵日志"""
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w") as f:
            f.write("\n".join(self.alarm_log))
        print(f"入侵日志已保存: {path}")

    def draw_zones(self, image, alpha=0.3):
        """在图片上绘制危险区域 (用于标注工具)"""
        overlay = image.copy()
        h, w = image.shape[:2]

        for zi, zone in enumerate(self.danger_zones):
            zone_px = np.array([(int(x * w), int(y * h)) for x, y in zone], dtype=np.int32)
            color = (0, 0, 255)  # 红色
            cv2.fillPoly(overlay, [zone_px], color)
            cv2.polylines(overlay, [zone_px], True, (0, 0, 200), 2)

            # 区域编号
            cx = int(np.mean(zone_px[:, 0]))
            cy = int(np.mean(zone_px[:, 1]))
            cv2.putText(overlay, f"Zone {zi}", (cx - 20, cy),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255, 255, 255), 2)

        return cv2.addWeighted(overlay, alpha, image, 1 - alpha, 0)


def load_zones_from_file(path):
    """
    **升级版**: 使用统一加载器识别 danger_zones.json / site_geofence.json / 纯数组
    返回 (zones_legacy, zones_config) 双元组：
      - zones_legacy : 纯多边形坐标列表  [[(x,y),...], [...]]  (给 self.danger_zones 用)
      - zones_config : 带 name/id 的 dict 列表  (给 self.danger_zones_config 用)
    会自动过滤掉非视频坐标(GPS)的区域，并给出提示。
    """
    from utils.common import (
        load_unified_zones, print_zones_summary,
        ZoneCoords, ZoneType,
    )
    import os
    all_zones = load_unified_zones(path)
    if not all_zones:
        return [], []
    # 只取视频坐标系 (pixel_norm / pixel_abs)
    video_zones = [z for z in all_zones
                   if z["coords"] in (ZoneCoords.PIXEL_NORM.value, ZoneCoords.PIXEL_ABS.value)]
    gps_zones = [z for z in all_zones if z["coords"] == ZoneCoords.GPS_WGS84.value]
    if gps_zones:
        print(f"[Zones] ⚠️  跳过 {len(gps_zones)} 个 GPS 区域 (入侵检测仅支持视频像素坐标, "
              f"请用 zones_tool extract 从 geofence 中提取后再使用): "
              f"{[z['id'] for z in gps_zones]}")
    # 对 pixel_abs 转成 pixel_norm (粗略按 1920×1080 归一化; 更精确需 reference_resolution 提供)
    def to_norm_points(z):
        pts = z["points"]
        if z["coords"] == ZoneCoords.PIXEL_NORM.value:
            return [(float(p[0]), float(p[1])) for p in pts]
        # pixel_abs: 用 reference_resolution=[W,H] 换算; 无则假设 1920×1080
        w, h = z.get("reference_resolution") or (1920, 1080)
        return [(float(p[0]) / w, float(p[1]) / h) for p in pts]

    print_zones_summary(video_zones,
                        title=f"video入侵检测 加载 {os.path.basename(path)}")
    if not video_zones:
        return [], []
    zones_legacy = [to_norm_points(z) for z in video_zones]
    zones_config = [
        {"id": z["id"], "name": z["name"], "type": z["type"],
         "alert_level": z.get("alert_level", "high"),
         "description": z.get("description", "")}
        for z in video_zones
    ]
    return zones_legacy, zones_config


def save_zones_to_file(zones, path):
    """保存危险区域到 JSON 文件 (输出 standard-zones 统一格式 v1.0)"""
    import os
    sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    out_zones = []
    for i, z in enumerate(zones):
        # zones 元素可能是纯点列表，也可能是带 name 的 dict
        if isinstance(z, dict):
            name = z.get("name", f"区域_{i+1}")
            pts = z.get("points", z.get("boundary", []))
            zid = z.get("id", f"zone_{i+1:02d}_danger")
            ztype = z.get("type", ZoneType.DANGER.value)
            coords = z.get("coords", ZoneCoords.PIXEL_NORM.value)
        else:
            name = f"区域_{i+1}"
            pts = list(z)
            zid = f"zone_{i+1:02d}_danger"
            ztype = ZoneType.DANGER.value
            coords = ZoneCoords.PIXEL_NORM.value
        out_zones.append({
            "id": zid,
            "name": name,
            "type": ztype,
            "coords": coords,
            "alert_level": "high" if ztype == ZoneType.DANGER.value else "mid",
            "points": [[float(p[0]), float(p[1])] for p in pts],
        })
    data = {
        "_version": "1.0",
        "_schema": "standard-zones",
        "zones": out_zones,
    }
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    print(f"✅ 危险区域已保存 (standard-zones v1.0): {path}  (共 {len(out_zones)} 个)")


# ---- 兼容旧调用: save_zones_to_file 需要 ZoneType/ZoneCoords ----
from utils.common import ZoneType, ZoneCoords  # noqa: E402


def interactive_zone_selector(image_path, output_path):
    """
    交互式危险区域标注工具
    使用鼠标点击绘制多边形危险区域
    """
    img = cv2.imread(image_path)
    if img is None:
        raise FileNotFoundError(f"无法读取图片: {image_path}")

    h, w = img.shape[:2]
    zones = []
    current_zone = []
    clone = img.copy()

    def mouse_callback(event, x, y, flags, param):
        nonlocal current_zone, clone

        if event == cv2.EVENT_LBUTTONDOWN:
            current_zone.append((x / w, y / h))  # 归一化坐标
            cv2.circle(clone, (x, y), 5, (0, 255, 0), -1)

            if len(current_zone) > 1:
                pts = [(int(px * w), int(py * h)) for px, py in current_zone]
                cv2.polylines(clone, [np.array(pts)], False, (0, 255, 0), 2)

        elif event == cv2.EVENT_RBUTTONDOWN:
            if len(current_zone) >= 3:
                # 闭合多边形
                pts = [(int(px * w), int(py * h)) for px, py in current_zone]
                cv2.polylines(clone, [np.array(pts)], True, (0, 0, 255), 2)

                zones.append(current_zone.copy())
                print(f"区域 #{len(zones)-1} 已添加 ({len(current_zone)} 个顶点)")
                current_zone.clear()

    cv2.namedWindow("Danger Zone Selector")
    cv2.setMouseCallback("Danger Zone Selector", mouse_callback)

    print("使用说明:")
    print("  左键点击: 添加多边形顶点")
    print("  右键点击: 闭合当前多边形")
    print("  按 's' 键: 保存并退出")
    print("  按 'r' 键: 撤销当前区域")
    print("  按 'q' 键: 退出不保存")

    while True:
        cv2.imshow("Danger Zone Selector", clone)
        key = cv2.waitKey(1) & 0xFF

        if key == ord("s"):
            save_zones_to_file(zones, output_path)
            break
        elif key == ord("r"):
            if zones:
                zones.pop()
                print(f"已撤销，当前剩余 {len(zones)} 个区域")
            clone = img.copy()
            for zi, zone in enumerate(zones):
                pts = [(int(px * w), int(py * h)) for px, py in zone]
                cv2.polylines(clone, [np.array(pts)], True, (0, 0, 255), 2)
                cx = int(np.mean([p[0] for p in pts]))
                cy = int(np.mean([p[1] for p in pts]))
                cv2.putText(clone, f"Z{zi}", (cx, cy),
                            cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255, 255, 255), 2)
        elif key == ord("q"):
            break

    cv2.destroyAllWindows()
    return zones


def main():
    parser = argparse.ArgumentParser(description="智慧工地 - 危险区域入侵检测")
    parser.add_argument("--model", type=str, required=True, help="训练好的模型路径")
    parser.add_argument("--source", type=str, required=True, help="图片/视频/摄像头(0)")
    parser.add_argument("--zones", type=str, default=None, help="危险区域 JSON 文件路径")
    parser.add_argument("--conf", type=float, default=0.3, help="置信度阈值")
    parser.add_argument("--device", type=str, default="0", help="设备")
    parser.add_argument("--nosave", action="store_true", help="不保存结果")
    parser.add_argument("--show", action="store_true", help="实时显示")
    parser.add_argument("--alarm_interval", type=int, default=5, help="报警间隔(秒)")
    parser.add_argument("--notify", action="store_true", help="启用飞书告警通知")
    parser.add_argument("--personnel-config", type=str, default="configs/personnel.json",
                        help="人员配置文件路径")
    parser.add_argument("--camera-id", type=str, default=None, help="摄像头编号")

    # 交互式标注子命令
    parser.add_argument("--annotate", type=str, default=None,
                        help="交互式标注模式: 指定一张图片来标注危险区域")
    parser.add_argument("--annotate_output", type=str, default="configs/danger_zones.json",
                        help="标注输出文件")

    args = parser.parse_args()

    if args.annotate:
        interactive_zone_selector(args.annotate, args.annotate_output)
        return

    # 加载危险区域
    if args.zones:
        zones_tuple, zones_config = load_zones_from_file(args.zones)
        zones = zones_tuple  # 传给 detector.danger_zones: [[(x,y),...], ...]
    else:
        # 默认危险区域 (示例, 需要根据实际场景调整)
        print("未指定危险区域, 使用默认示例区域")
        zones = [
            [(0.1, 0.1), (0.3, 0.1), (0.3, 0.4), (0.1, 0.4)],  # 左上区域
        ]
        zones_config = [
            {"id": "zone_default_01", "name": "示例区域_左上", "type": "danger",
             "alert_level": "high", "description": ""}
        ]

    print(f"已加载 {len(zones)} 个危险区域")

    detector = IntrusionDetector(
        model_path=args.model,
        danger_zones=zones,
        conf=args.conf,
        device=args.device,
        notify=args.notify,
        personnel_config=args.personnel_config,
    )
    detector.camera_id = args.camera_id
    detector.danger_zones_config = zones_config  # 保存带 name 的区域配置 (含 id/type/alert_level)

    source = args.source
    if source.isdigit():
        source = int(source)

    detector.detect(
        source=source,
        save=not args.nosave,
        show=args.show,
        alarm_interval=args.alarm_interval,
    )

    detector.save_log()


if __name__ == "__main__":
    main()