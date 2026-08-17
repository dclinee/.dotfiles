# utils 包 (延迟导入重型依赖, 避免基础脚本被 matplotlib 等阻塞)
from .common import (
    CLASS_NAMES, CLASS_COLORS, SAFETY_VIOLATION_CLASSES,
    point_in_polygon, polygon_area, bbox_iou, bbox_area, clamp,
    ensure_dir, safe_json_load, safe_json_dump,
    format_duration, format_timestamp, now_str, timestamp_now,
    calc_rate, moving_average, EARTH_RADIUS_M, ALERT_COOLDOWN,
)


def draw_boxes(*args, **kwargs):
    from .visualize import draw_boxes as _f
    return _f(*args, **kwargs)


def plot_training_results(*args, **kwargs):
    from .visualize import plot_training_results as _f
    return _f(*args, **kwargs)


from .notify import LarkNotifier, get_notifier
from .notify import (
    alarm_no_helmet,
    alarm_no_vest,
    alarm_intrusion,
    alarm_helmet_compliance,
    alarm_vest_compliance,
)
from .positioning import (
    WorkerTracker,
    GeofenceEngine,
    WorkerStatus,
    WorkerLocation,
    haversine_distance,
    get_tracker,
)