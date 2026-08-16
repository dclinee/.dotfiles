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