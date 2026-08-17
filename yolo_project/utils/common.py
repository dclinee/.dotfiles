"""
智慧工地 - 公共工具模块
统一管理项目中重复使用的函数和工具

包含:
  - 几何计算: point_in_polygon, polygon_area, bbox_iou
  - 文件工具: ensure_dir, safe_json_load, safe_json_dump
  - 时间工具: format_duration, format_timestamp
  - 颜色常量: 检测类别对应颜色
"""

import json
import math
from pathlib import Path
from datetime import datetime
from enum import Enum
from typing import List, Tuple, Dict, Any, Optional


# ============================================================
# 类别定义 & 颜色
# ============================================================

CLASS_NAMES: Dict[int, str] = {
    0: "person",
    1: "helmet",
    2: "no_helmet",
    3: "vest",
    4: "no_vest",
    5: "vehicle",
    6: "smoke_fire",
}

CLASS_COLORS: Dict[int, Tuple[int, int, int]] = {
    0: (0, 255, 0),       # person     - 绿色
    1: (255, 255, 0),     # helmet     - 青色
    2: (0, 0, 255),       # no_helmet  - 红色
    3: (0, 255, 255),     # vest       - 黄色
    4: (255, 0, 255),     # no_vest    - 紫色
    5: (255, 128, 0),     # vehicle    - 橙色
    6: (128, 128, 128),   # smoke_fire - 灰色
}

SAFETY_VIOLATION_CLASSES: Dict[int, str] = {
    2: "no_helmet",
    4: "no_vest",
}

# ============================================================
# 几何计算
# ============================================================

def point_in_polygon(x: float, y: float, polygon: List[Tuple[float, float]]) -> bool:
    """
    射线法判断点是否在多边形内

    Args:
        x, y: 点坐标
        polygon: 多边形顶点列表 [(x1,y1), (x2,y2), ...]

    Returns:
        True 如果点在多边形内
    """
    n = len(polygon)
    if n < 3:
        return False

    inside = False
    j = n - 1
    for i in range(n):
        xi, yi = polygon[i]
        xj, yj = polygon[j]
        if ((yi > y) != (yj > y)) and \
           (x < (xj - xi) * (y - yi) / (yj - yi + 1e-10) + xi):
            inside = not inside
        j = i
    return inside


def polygon_area(polygon: List[Tuple[float, float]]) -> float:
    """计算多边形面积 (Shoelace formula)"""
    n = len(polygon)
    if n < 3:
        return 0.0
    area = 0.0
    j = n - 1
    for i in range(n):
        area += polygon[i][0] * polygon[j][1]
        area -= polygon[j][0] * polygon[i][1]
        j = i
    return abs(area) / 2.0


def bbox_iou(box1: Tuple[float, float, float, float],
             box2: Tuple[float, float, float, float]) -> float:
    """计算两个边界框的 IoU"""
    x1 = max(box1[0], box2[0])
    y1 = max(box1[1], box2[1])
    x2 = min(box1[2], box2[2])
    y2 = min(box1[3], box2[3])

    inter = max(0, x2 - x1) * max(0, y2 - y1)
    area1 = (box1[2] - box1[0]) * (box1[3] - box1[1])
    area2 = (box2[2] - box2[0]) * (box2[3] - box2[1])
    union = area1 + area2 - inter

    return inter / union if union > 0 else 0.0


def bbox_area(box: Tuple[float, float, float, float]) -> float:
    """计算边界框面积"""
    return max(0, box[2] - box[0]) * max(0, box[3] - box[1])


def clamp(value: float, low: float, high: float) -> float:
    """限制值在 [low, high] 范围内"""
    return max(low, min(high, value))


# ============================================================
# 文件工具
# ============================================================

def ensure_dir(dir_path: Path) -> Path:
    """确保目录存在, 不存在则创建"""
    dir_path = Path(dir_path)
    dir_path.mkdir(parents=True, exist_ok=True)
    return dir_path


def safe_json_load(path: str, default: Any = None) -> Any:
    """安全加载 JSON 文件"""
    try:
        with open(path, "r", encoding="utf-8") as f:
            return json.load(f)
    except (FileNotFoundError, json.JSONDecodeError) as e:
        if default is not None:
            return default
        raise e


def safe_json_dump(data: Any, path: str, indent: int = 2) -> None:
    """安全写入 JSON 文件"""
    ensure_dir(Path(path).parent)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=indent, ensure_ascii=False)


def safe_yaml_load(path: str) -> dict:
    """安全加载 YAML 文件"""
    try:
        import yaml
        with open(path, "r", encoding="utf-8") as f:
            data = yaml.safe_load(f)
            return data if data else {}
    except ImportError:
        raise ImportError("需要安装 PyYAML: pip install pyyaml")


# ============================================================
# 时间工具
# ============================================================

def format_duration(seconds: float) -> str:
    """格式化时长 (秒 → HH:MM:SS)"""
    if seconds < 0:
        seconds = 0
    hours = int(seconds // 3600)
    minutes = int((seconds % 3600) // 60)
    secs = int(seconds % 60)
    if hours > 0:
        return f"{hours:02d}:{minutes:02d}:{secs:02d}"
    return f"{minutes:02d}:{secs:02d}"


def format_timestamp(ts: float, fmt: str = "%Y-%m-%d %H:%M:%S") -> str:
    """格式化 Unix 时间戳"""
    if ts <= 0:
        return "N/A"
    return datetime.fromtimestamp(ts).strftime(fmt)


def now_str(fmt: str = "%Y-%m-%d %H:%M:%S") -> str:
    """当前时间字符串"""
    return datetime.now().strftime(fmt)


def timestamp_now() -> float:
    """当前 Unix 时间戳"""
    return datetime.now().timestamp()


# ============================================================
# 网络工具
# ============================================================

def is_port_open(host: str, port: int, timeout: float = 2.0) -> bool:
    """检查端口是否可连接"""
    import socket
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(timeout)
        result = sock.connect_ex((host, port))
        sock.close()
        return result == 0
    except Exception:
        return False


def check_url(url: str, timeout: float = 5.0) -> bool:
    """检查 URL 是否可访问"""
    try:
        import urllib.request
        urllib.request.urlopen(url, timeout=timeout)
        return True
    except Exception:
        return False


# ============================================================
# 统计工具
# ============================================================

def calc_rate(numerator: int, denominator: int) -> float:
    """计算百分比, 安全处理除零"""
    return round(numerator / denominator * 100, 1) if denominator > 0 else 0.0


def moving_average(values: List[float], window: int = 5) -> List[float]:
    """计算移动平均"""
    if len(values) < window:
        return values[:]
    return [sum(values[i:i+window]) / window
            for i in range(len(values) - window + 1)]


# ============================================================
# 常量
# ============================================================

# 地球半径 (米)
EARTH_RADIUS_M = 6371000.0

# 常见告警冷却时间 (秒)
ALERT_COOLDOWN = {
    "no_helmet": 300,
    "no_vest": 300,
    "intrusion": 60,
    "compliance_low": 600,
}


# ============================================================
# 统一危险区域/电子栅栏 数据模型与加载器
# ============================================================

class ZoneCoords(str, Enum):
    """坐标系枚举：
    - pixel_norm: 视频像素坐标归一化 0~1 (视频流用)
    - pixel_abs:  视频像素绝对坐标 (x,y 像素单位，需知道画面分辨率)
    - gps_wgs84:  GPS WGS84 经纬度 (手机定位用)
    """
    PIXEL_NORM = "pixel_norm"
    PIXEL_ABS = "pixel_abs"
    GPS_WGS84 = "gps_wgs84"


class ZoneType(str, Enum):
    """区域类型语义：
    - danger:  绝对禁止进入，触发高危告警
    - restricted: 受限制区域，需授权
    - work:    普通施工区
    - safe:    安全区/办公区
    """
    DANGER = "danger"
    RESTRICTED = "restricted"
    WORK = "work"
    SAFE = "safe"


# 统一 Zone 字典 (TypedDict，仅做文档和类型标注)
# 字段:
#   id:                  稳定ID (跨脚本引用)
#   name:                展示名称
#   type:                ZoneType
#   coords:              ZoneCoords
#   points:              [(x,y), ...]  多边形顶点 (与 coords 对应)
#   alert_level:         "low" / "mid" / "high"  告警级别提示
#   description:         可选说明
#   reference_resolution:[W, H]  (pixel_norm/pixel_abs 时，记录参考分辨率，便于换算；可选)
StandardZone = Dict[str, Any]


def _norm_points(raw_points) -> List[List[float]]:
    """把各种 points/boundary 格式规范化为 [[float,float], ...]"""
    if raw_points is None:
        return []
    out = []
    for p in raw_points:
        if isinstance(p, (list, tuple)) and len(p) >= 2:
            out.append([float(p[0]), float(p[1])])
    return out


def _infer_coords_from_range(points: List[List[float]]) -> ZoneCoords:
    """根据坐标数值范围粗略推断坐标系：
    - 全部 0~1.5 且绝对值小 → pixel_norm
    - 大整数 (100~10000)    → pixel_abs
    - 经纬度范围 (lon∈70~140, lat∈15~55 中国工地常见) → gps_wgs84
    """
    if not points:
        return ZoneCoords.PIXEL_NORM
    xs = [p[0] for p in points]
    ys = [p[1] for p in points]
    max_abs = max(max(abs(v) for v in xs), max(abs(v) for v in ys))
    min_abs = min(min(abs(v) for v in xs), min(abs(v) for v in ys))
    if max_abs <= 1.5 and min_abs >= 0:
        return ZoneCoords.PIXEL_NORM
    if 70 <= min(xs) <= max(xs) <= 140 and 15 <= min(ys) <= max(ys) <= 55:
        return ZoneCoords.GPS_WGS84
    return ZoneCoords.PIXEL_ABS


def load_unified_zones(zones_input: Any, *,
                       default_type: ZoneType = ZoneType.DANGER,
                       filter_types: Optional[List[ZoneType]] = None,
                       filter_coords: Optional[List[ZoneCoords]] = None,
                       ) -> List[StandardZone]:
    """**统一区域加载器**

    自动识别以下 4 种输入格式并归一化为 StandardZone 列表：
      1) dict( danger_zones.json 格式 ): {"zones": [{name, points}, ...]}
         - 默认 coords=PIXEL_NORM  type=DANGER
      2) dict( site_geofence.json 格式 ): {"sub_zones": [{id,name,type,boundary}, ...]}
         - coords 从 range 自动推断 (gps_wgs84)
      3) list (纯区域数组): [{name, points|boundary, ...}]  或  [[points], ...]
         - coords 从 range 自动推断；默认 type=default_type
      4) str (文件路径) : 读 JSON 后再按 1~3 识别

    Args:
        zones_input:      JSON路径、dict、list 任一
        default_type:     缺省时默认区域类型
        filter_types:     只保留指定类型（None=全部）
        filter_coords:    只保留指定坐标系（None=全部）
    """
    # ---- 步骤1: 若入参是字符串，读 JSON 文件 ----
    if isinstance(zones_input, str):
        path = zones_input
        data = safe_json_load(path, default=None)
        if data is None:
            print(f"[Zones] ⚠️ 无法读取文件: {path}，返回空区域列表")
            return []
        return load_unified_zones(data,
                                  default_type=default_type,
                                  filter_types=filter_types,
                                  filter_coords=filter_coords)

    raw_list: List[Dict[str, Any]] = []

    # ---- 步骤2: 识别 dict 包装格式 ----
    if isinstance(zones_input, dict):
        # 格式A: danger_zones.json — {"zones": [...]}
        if "zones" in zones_input and isinstance(zones_input["zones"], list):
            for z in zones_input["zones"]:
                if not isinstance(z, dict):
                    continue
                raw_list.append({
                    "_src": "danger_zones",
                    "id": z.get("id"),
                    "name": z.get("name", "unnamed_zone"),
                    "type": z.get("type"),
                    "points_raw": z.get("points") or z.get("boundary"),
                    "coords": z.get("coords"),
                    "alert_level": z.get("alert_level"),
                    "description": z.get("description"),
                    "reference_resolution": z.get("reference_resolution"),
                })
        # 格式B: site_geofence.json — {"sub_zones": [...]}
        elif "sub_zones" in zones_input and isinstance(zones_input["sub_zones"], list):
            for z in zones_input["sub_zones"]:
                if not isinstance(z, dict):
                    continue
                raw_list.append({
                    "_src": "site_geofence",
                    "id": z.get("id"),
                    "name": z.get("name", "unnamed_zone"),
                    "type": z.get("type"),
                    "points_raw": z.get("boundary") or z.get("points"),
                    "coords": z.get("coords"),
                    "alert_level": z.get("alert_level"),
                    "description": z.get("description"),
                    "reference_resolution": z.get("reference_resolution"),
                })
        # 格式C: 单区域字典
        elif any(k in zones_input for k in ("points", "boundary", "polygon")):
            raw_list.append({
                "_src": "single_dict",
                "id": zones_input.get("id"),
                "name": zones_input.get("name", "unnamed_zone"),
                "type": zones_input.get("type"),
                "points_raw": zones_input.get("points") or zones_input.get("boundary"),
                "coords": zones_input.get("coords"),
                "alert_level": zones_input.get("alert_level"),
                "description": zones_input.get("description"),
                "reference_resolution": zones_input.get("reference_resolution"),
            })
        else:
            print(f"[Zones] ⚠️ 无法识别的字典结构 (keys={list(zones_input.keys())[:6]})")
            return []

    # ---- 步骤2b: list 输入 ----
    elif isinstance(zones_input, list):
        if not zones_input:
            return []
        # 子元素 是 dict → 区域数组
        if isinstance(zones_input[0], dict):
            for z in zones_input:
                if not isinstance(z, dict):
                    continue
                raw_list.append({
                    "_src": "list_dict",
                    "id": z.get("id"),
                    "name": z.get("name", "unnamed_zone"),
                    "type": z.get("type"),
                    "points_raw": z.get("points") or z.get("boundary"),
                    "coords": z.get("coords"),
                    "alert_level": z.get("alert_level"),
                    "description": z.get("description"),
                    "reference_resolution": z.get("reference_resolution"),
                })
        # 子元素 是 list/tuple (且第一个元素是坐标对) → 裸多边形 points
        elif (isinstance(zones_input[0], (list, tuple))
              and len(zones_input[0]) >= 2
              and all(isinstance(v, (int, float)) for v in zones_input[0][:2])):
            raw_list.append({
                "_src": "list_poly",
                "id": None,
                "name": "unnamed_zone",
                "type": None,
                "points_raw": zones_input,
                "coords": None,
            })
        else:
            print(f"[Zones] ⚠️ 无法识别的 list 结构 (首元素 type={type(zones_input[0]).__name__})")
            return []

    else:
        print(f"[Zones] ⚠️ 不支持的 zones_input type: {type(zones_input).__name__}")
        return []

    # ---- 步骤3: 字段规范化 + 推断 ----
    out: List[StandardZone] = []
    for i, r in enumerate(raw_list):
        pts = _norm_points(r["points_raw"])
        if len(pts) < 3:
            print(f"[Zones] ⚠️ 跳过区域 '{r['name']}': 有效顶点数 {len(pts)} < 3")
            continue
        # coords 推断
        coords = r["coords"]
        if coords is None:
            coords = _infer_coords_from_range(pts).value
        # type 推断
        ztype = r["type"]
        if ztype is None:
            # site_geofence 源的 type 一般有值；danger_zones 源默认 DANGER
            if r["_src"] == "site_geofence":
                ztype = ZoneType.WORK.value
            else:
                ztype = default_type.value
        # id 补全
        zid = r["id"] or f"zone_{i+1:02d}_{ztype}"
        # alert_level 推断
        alert_level = r["alert_level"]
        if alert_level is None:
            if ztype == ZoneType.DANGER.value:
                alert_level = "high"
            elif ztype == ZoneType.RESTRICTED.value:
                alert_level = "mid"
            else:
                alert_level = "low"
        zone: StandardZone = {
            "id": zid,
            "name": r["name"],
            "type": ztype,
            "coords": coords,
            "points": pts,
            "alert_level": alert_level,
        }
        if r.get("description"):
            zone["description"] = r["description"]
        if r.get("reference_resolution"):
            zone["reference_resolution"] = r["reference_resolution"]
        out.append(zone)

    # ---- 步骤4: 过滤 ----
    if filter_types:
        allowed = {t.value if isinstance(t, ZoneType) else t for t in filter_types}
        out = [z for z in out if z["type"] in allowed]
    if filter_coords:
        allowed = {c.value if isinstance(c, ZoneCoords) else c for c in filter_coords}
        out = [z for z in out if z["coords"] in allowed]
    return out


def zone_to_legacy_points(zone: StandardZone, *, to_legacy_format: str = "video_verify"):
    """
    把 StandardZone 转成旧格式方便对接遗留代码：
    - "video_verify": {"name": str, "points": [[x,y],...]}
    - "intrusion_detect": (name, [(x,y),...])   (tuple pair)
    """
    if to_legacy_format == "video_verify":
        return {"name": zone["name"], "points": zone["points"]}
    elif to_legacy_format == "intrusion_detect":
        return (zone["name"], [(p[0], p[1]) for p in zone["points"]])
    else:
        raise ValueError(f"unknown legacy format: {to_legacy_format}")


def zones_to_videoverify_list(zones: List[StandardZone]) -> List[Dict]:
    """批量转 video_verify 旧格式"""
    return [zone_to_legacy_points(z, to_legacy_format="video_verify") for z in zones]


def zones_to_intrusion_list(zones: List[StandardZone]) -> List[Tuple[str, List[Tuple[float, float]]]]:
    """批量转 intrusion_detect 旧格式"""
    return [zone_to_legacy_points(z, to_legacy_format="intrusion_detect") for z in zones]


def print_zones_summary(zones: List[StandardZone], *, title: str = "加载的区域"):
    """漂亮地打印区域汇总"""
    if not zones:
        print(f"  [{title}] (空)")
        return
    print(f"  [{title}] 共 {len(zones)} 个区域:")
    by_type: Dict[str, int] = {}
    by_coords: Dict[str, int] = {}
    for z in zones:
        by_type[z["type"]] = by_type.get(z["type"], 0) + 1
        by_coords[z["coords"]] = by_coords.get(z["coords"], 0) + 1
        pts = len(z["points"])
        print(f"    • [{z['id']:18s}] {z['name']:12s}  type={z['type']:10s}  "
              f"coords={z['coords']:11s}  level={z['alert_level']}  顶点={pts}")
    print(f"    └ 按类型统计: {dict(by_type)}")
    print(f"    └ 按坐标系统计: {dict(by_coords)}")