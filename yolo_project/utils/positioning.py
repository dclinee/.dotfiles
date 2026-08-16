#!/usr/bin/env python3
"""
智慧工地 - 手机定位 & 电子栅栏核心模块

功能:
  1. GPS 坐标处理 (Haversine 距离计算)
  2. 电子栅栏 (多边形内/外判断)
  3. 工人定位状态管理 (在场/离场/进入危险区)
  4. 班组统计 (各班人数/总人数)
  5. 自动考勤 (进出场记录)
"""

import json
import math
import time
from pathlib import Path
from datetime import datetime
from collections import defaultdict, OrderedDict
from dataclasses import dataclass, field
from typing import Dict, List, Optional, Tuple


# ============================================================
# GPS 坐标工具
# ============================================================

def haversine_distance(lat1: float, lon1: float,
                       lat2: float, lon2: float) -> float:
    """
    Haversine 公式计算两点间距离 (米)

    Args:
        lat1, lon1: 点1 纬度, 经度 (度)
        lat2, lon2: 点2 纬度, 经度 (度)

    Returns:
        距离 (米)
    """
    R = 6371000  # 地球半径 (米)

    lat1_r = math.radians(lat1)
    lat2_r = math.radians(lat2)
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)

    a = (math.sin(dlat / 2) ** 2 +
         math.cos(lat1_r) * math.cos(lat2_r) * math.sin(dlon / 2) ** 2)
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))

    return R * c


def point_in_polygon(lat: float, lon: float,
                     polygon: List[Tuple[float, float]]) -> bool:
    """
    射线法判断点是否在多边形内

    Args:
        lat, lon: 目标点坐标
        polygon: 多边形顶点 [(lat, lon), ...]

    Returns:
        是否在多边形内
    """
    n = len(polygon)
    if n < 3:
        return False

    inside = False
    j = n - 1
    for i in range(n):
        lat_i, lon_i = polygon[i]
        lat_j, lon_j = polygon[j]

        if ((lon_i > lon) != (lon_j > lon)) and \
           (lat < (lat_j - lat_i) * (lon - lon_i) / (lon_j - lon_i) + lat_i):
            inside = not inside
        j = i

    return inside


def distance_to_polygon_center(lat: float, lon: float,
                               polygon: List[Tuple[float, float]]) -> float:
    """计算点到多边形中心的距离"""
    if not polygon:
        return float("inf")
    center_lat = sum(p[0] for p in polygon) / len(polygon)
    center_lon = sum(p[1] for p in polygon) / len(polygon)
    return haversine_distance(lat, lon, center_lat, center_lon)


# ============================================================
# 定位状态
# ============================================================

@dataclass
class WorkerLocation:
    """工人定位数据"""
    worker_id: str
    name: str
    phone: str
    team: str
    role: str
    latitude: float
    longitude: float
    accuracy: float = 0.0       # GPS 精度 (米)
    speed: float = 0.0           # 移动速度 (m/s)
    timestamp: float = field(default_factory=time.time)
    battery: int = 100           # 手机电量
    provider: str = "gps"        # 定位来源: gps/network/simulated


@dataclass
class WorkerStatus:
    """工人实时状态"""
    worker_id: str
    name: str
    team: str
    role: str

    # 位置
    latitude: float = 0.0
    longitude: float = 0.0
    accuracy: float = 0.0

    # 状态
    on_site: bool = False           # 是否在工地内
    current_zone: str = ""          # 当前所在区域
    zone_type: str = ""             # safe/work/danger
    in_danger_zone: bool = False    # 是否在危险区
    is_moving: bool = False         # 是否在移动

    # 时间
    last_update: float = 0.0
    first_seen_today: float = 0.0   # 今日首次进场
    last_seen: float = 0.0          # 最后定位时间
    on_site_duration: float = 0.0   # 在场时长 (秒)

    # 考勤
    checkin_time: str = ""          # 签到时间
    checkout_time: str = ""         # 签退时间
    is_late: bool = False           # 是否迟到
    is_early_leave: bool = False    # 是否早退

    # 事件
    events_today: List[dict] = field(default_factory=list)


# ============================================================
# 电子栅栏 & 工人追踪引擎
# ============================================================

class GeofenceEngine:
    """电子栅栏引擎 - 管理工地边界和区域"""

    def __init__(self, geofence_config_path: str = "configs/site_geofence.json"):
        self.config = self._load_config(geofence_config_path)
        self.site_boundary = self.config["site_geofence"]["boundary"]
        self.site_center = self.config["site_geofence"]["center"]
        self.site_radius = self.config["site_geofence"]["radius_meters"]

        # 子区域
        self.sub_zones = {}
        self.danger_zones = {}
        for zone in self.config.get("sub_zones", []):
            self.sub_zones[zone["id"]] = zone
            if zone["type"] == "danger":
                self.danger_zones[zone["id"]] = zone

        # 告警配置
        self.alerts = self.config.get("alerts", {})

    def _load_config(self, path: str) -> dict:
        path = Path(path)
        if not path.exists():
            raise FileNotFoundError(f"电子栅栏配置不存在: {path}")
        with open(path, "r") as f:
            return json.load(f)

    def is_on_site(self, lat: float, lon: float) -> bool:
        """判断坐标是否在工地范围内"""
        return point_in_polygon(lat, lon, self.site_boundary)

    def distance_to_site(self, lat: float, lon: float) -> float:
        """计算到工地中心的距离"""
        return haversine_distance(
            lat, lon, self.site_center[0], self.site_center[1]
        )

    def locate_zone(self, lat: float, lon: float) -> Tuple[str, str]:
        """
        定位工人在哪个区域

        Returns:
            (zone_id, zone_type) 或 ("", "")
        """
        for zone_id, zone in self.sub_zones.items():
            if point_in_polygon(lat, lon, zone["boundary"]):
                return zone_id, zone["type"]
        return "", ""

    def is_in_danger_zone(self, lat: float, lon: float) -> Tuple[bool, str]:
        """
        判断是否在危险区域

        Returns:
            (是否在危险区, 危险区名称)
        """
        for zone_id, zone in self.danger_zones.items():
            if point_in_polygon(lat, lon, zone["boundary"]):
                return True, zone["name"]
        return False, ""

    def get_site_boundary(self) -> List[Tuple[float, float]]:
        return self.site_boundary

    def get_all_zones(self) -> dict:
        return self.sub_zones


class WorkerTracker:
    """
    工人实时追踪引擎

    核心功能:
      - 实时追踪每个工人的位置和状态
      - 基于电子栅栏判断在场/离场
      - 自动考勤 (签到/签退)
      - 班组统计
      - 危险区域预警
    """

    def __init__(self,
                 workers_config_path: str = "configs/workers.json",
                 geofence_config_path: str = "configs/site_geofence.json",
                 attendance_rules: dict = None):
        # 加载工人数据
        self.workers_db = self._load_workers(workers_config_path)
        self.worker_by_phone = {
            w["phone"]: w for w in self.workers_db["workers"]
        }
        self.worker_by_id = {
            w["id"]: w for w in self.workers_db["workers"]
        }
        self.teams = self.workers_db.get("teams", {})

        # 考勤规则
        self.attendance_rules = attendance_rules or self.workers_db.get(
            "attendance_rules", {}
        )
        self.work_start = self.attendance_rules.get("work_start", "08:00")
        self.work_end = self.attendance_rules.get("work_end", "17:00")
        self.late_threshold = self.attendance_rules.get(
            "late_threshold_minutes", 30
        )
        self.auto_checkin_dist = self.attendance_rules.get(
            "auto_checkin_distance_meters", 50
        )
        self.auto_checkout_dist = self.attendance_rules.get(
            "auto_checkout_distance_meters", 100
        )

        # 电子栅栏引擎
        self.geofence = GeofenceEngine(geofence_config_path)

        # 实时状态
        self.worker_statuses: Dict[str, WorkerStatus] = {}
        self._init_statuses()

        # 事件回调
        self._event_callbacks = {
            "checkin": [],
            "checkout": [],
            "enter_danger": [],
            "leave_site": [],
            "return_site": [],
        }

        # 统计缓存
        self._stats_cache = {}
        self._stats_cache_time = 0

    def _load_workers(self, path: str) -> dict:
        path = Path(path)
        if not path.exists():
            raise FileNotFoundError(f"工人数据库不存在: {path}")
        with open(path, "r") as f:
            return json.load(f)

    def _init_statuses(self):
        """初始化所有工人的状态"""
        for w in self.workers_db["workers"]:
            self.worker_statuses[w["id"]] = WorkerStatus(
                worker_id=w["id"],
                name=w["name"],
                team=w["team"],
                role=w["role"],
            )

    def on(self, event: str, callback):
        """注册事件回调"""
        if event in self._event_callbacks:
            self._event_callbacks[event].append(callback)

    def _emit(self, event: str, **kwargs):
        """触发事件"""
        for cb in self._event_callbacks.get(event, []):
            try:
                cb(**kwargs)
            except Exception as e:
                print(f"[Tracker] 事件回调异常 ({event}): {e}")

    # ============================================================
    # 核心: 更新工人位置
    # ============================================================

    def update_location(self, phone: str, lat: float, lon: float,
                        accuracy: float = 0.0, speed: float = 0.0,
                        timestamp: float = None,
                        battery: int = 100,
                        provider: str = "gps") -> WorkerStatus:
        """
        更新工人位置 (由手机端 GPS 上报调用)

        Args:
            phone: 手机号 (工人唯一标识)
            lat: 纬度
            lon: 经度
            accuracy: GPS 精度
            speed: 移动速度
            timestamp: 定位时间戳
            battery: 手机电量
            provider: 定位来源

        Returns:
            WorkerStatus 更新后的状态
        """
        # 查找工人
        worker = self.worker_by_phone.get(phone)
        if not worker:
            raise ValueError(f"未找到手机号对应的工人: {phone}")

        worker_id = worker["id"]
        status = self.worker_statuses[worker_id]
        now = timestamp or time.time()

        # 更新位置
        status.latitude = lat
        status.longitude = lon
        status.accuracy = accuracy
        status.is_moving = speed > 0.5
        status.last_update = now

        # 判断是否在工地内
        was_on_site = status.on_site
        status.on_site = self.geofence.is_on_site(lat, lon)

        # 定位所在区域
        zone_id, zone_type = self.geofence.locate_zone(lat, lon)
        status.current_zone = zone_id
        status.zone_type = zone_type

        # 判断是否在危险区
        in_danger, danger_name = self.geofence.is_in_danger_zone(lat, lon)
        status.in_danger_zone = in_danger

        # 距离工地中心
        dist_to_site = self.geofence.distance_to_site(lat, lon)

        # ===== 进出场事件 =====
        if status.on_site:
            if status.first_seen_today == 0:
                # 今日首次进场
                status.first_seen_today = now
                status.checkin_time = datetime.fromtimestamp(now).strftime(
                    "%H:%M:%S"
                )
                # 判断是否迟到
                status.is_late = self._check_late(now)
                status.events_today.append({
                    "type": "checkin",
                    "time": status.checkin_time,
                    "is_late": status.is_late,
                })
                self._emit("checkin",
                           worker=worker, status=status,
                           time=status.checkin_time,
                           is_late=status.is_late)

            elif not was_on_site:
                # 返回工地
                status.events_today.append({
                    "type": "return",
                    "time": datetime.fromtimestamp(now).strftime("%H:%M:%S"),
                })
                self._emit("return_site", worker=worker, status=status)
        else:
            if was_on_site:
                # 离开工地
                status.checkout_time = datetime.fromtimestamp(now).strftime(
                    "%H:%M:%S"
                )
                status.is_early_leave = self._check_early_leave(now)
                status.events_today.append({
                    "type": "checkout",
                    "time": status.checkout_time,
                    "is_early_leave": status.is_early_leave,
                })
                self._emit("leave_site",
                           worker=worker, status=status,
                           dist_to_site=dist_to_site)

        # ===== 危险区域事件 =====
        if in_danger:
            status.events_today.append({
                "type": "danger_enter",
                "zone": danger_name,
                "time": datetime.fromtimestamp(now).strftime("%H:%M:%S"),
            })
            self._emit("enter_danger",
                       worker=worker, status=status,
                       zone_name=danger_name)

        # 更新在场时长
        if status.on_site and status.first_seen_today > 0:
            status.on_site_duration = now - status.first_seen_today

        status.last_seen = now

        # 清除统计缓存
        self._stats_cache_time = 0

        return status

    # ============================================================
    # 考勤判断
    # ============================================================

    def _check_late(self, timestamp: float) -> bool:
        """判断是否迟到"""
        dt = datetime.fromtimestamp(timestamp)
        work_start = datetime.strptime(self.work_start, "%H:%M").time()
        arrival = dt.time()
        late_minutes = (arrival.hour * 60 + arrival.minute) - \
                       (work_start.hour * 60 + work_start.minute)
        return late_minutes > self.late_threshold

    def _check_early_leave(self, timestamp: float) -> bool:
        """判断是否早退"""
        dt = datetime.fromtimestamp(timestamp)
        work_end = datetime.strptime(self.work_end, "%H:%M").time()
        leave = dt.time()
        remain_minutes = (work_end.hour * 60 + work_end.minute) - \
                         (leave.hour * 60 + leave.minute)
        return remain_minutes > self.attendance_rules.get(
            "early_leave_threshold_minutes", 30
        )

    # ============================================================
    # 班组统计
    # ============================================================

    def get_team_stats(self) -> dict:
        """
        获取班组统计

        Returns:
            {
                "total_workers": 总人数,
                "on_site": 在场总人数,
                "off_site": 离场总人数,
                "teams": {
                    "A班组": {"total": 4, "on_site": 3, "off_site": 1, "workers": [...]},
                    ...
                }
            }
        """
        # 缓存 2 秒
        now = time.time()
        if now - self._stats_cache_time < 2 and self._stats_cache:
            return self._stats_cache

        stats = {
            "total_workers": len(self.worker_statuses),
            "on_site": 0,
            "off_site": 0,
            "teams": {},
            "updated_at": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        }

        for team_name, team_info in self.teams.items():
            stats["teams"][team_name] = {
                "type": team_info.get("type", ""),
                "leader": team_info.get("leader_name", ""),
                "work_area": team_info.get("work_area", ""),
                "total": 0,
                "on_site": 0,
                "off_site": 0,
                "workers": [],
            }

        # 未归类班组
        stats["teams"]["未分组"] = {
            "total": 0, "on_site": 0, "off_site": 0, "workers": [],
        }

        for w in self.workers_db["workers"]:
            wid = w["id"]
            status = self.worker_statuses.get(wid)
            if not status:
                continue

            team = w["team"]
            if team not in stats["teams"]:
                stats["teams"][team] = {
                    "total": 0, "on_site": 0, "off_site": 0, "workers": [],
                }

            worker_info = {
                "id": wid,
                "name": w["name"],
                "phone": w["phone"],
                "role": w["role"],
                "on_site": status.on_site,
                "zone": status.current_zone,
                "zone_type": status.zone_type,
                "in_danger": status.in_danger_zone,
                "latitude": status.latitude,
                "longitude": status.longitude,
                "is_moving": status.is_moving,
                "last_update": datetime.fromtimestamp(
                    status.last_update
                ).strftime("%H:%M:%S") if status.last_update > 0 else "N/A",
                "on_site_duration": self._format_duration(
                    status.on_site_duration
                ),
                "checkin_time": status.checkin_time or "N/A",
                "is_late": status.is_late,
            }

            stats["teams"][team]["total"] += 1
            if status.on_site:
                stats["teams"][team]["on_site"] += 1
                stats["on_site"] += 1
            else:
                stats["teams"][team]["off_site"] += 1
                stats["off_site"] += 1

            stats["teams"][team]["workers"].append(worker_info)

        # 移除空的未分组
        if stats["teams"]["未分组"]["total"] == 0:
            del stats["teams"]["未分组"]

        self._stats_cache = stats
        self._stats_cache_time = now
        return stats

    def get_worker_status(self, worker_id: str) -> Optional[WorkerStatus]:
        """获取单个工人状态"""
        return self.worker_statuses.get(worker_id)

    def get_on_site_workers(self) -> List[dict]:
        """获取所有在场工人"""
        stats = self.get_team_stats()
        on_site = []
        for team_name, team_data in stats["teams"].items():
            for w in team_data["workers"]:
                if w["on_site"]:
                    w["team"] = team_name
                    on_site.append(w)
        return on_site

    def get_workers_in_danger_zone(self) -> List[dict]:
        """获取所有在危险区的工人"""
        on_site = self.get_on_site_workers()
        return [w for w in on_site if w["in_danger"]]

    def get_team_summary(self) -> str:
        """生成班组统计摘要字符串"""
        stats = self.get_team_stats()
        lines = [
            f"总工人: {stats['total_workers']} | "
            f"在场: {stats['on_site']} | "
            f"离场: {stats['off_site']}"
        ]
        lines.append("-" * 40)
        for team_name, team_data in stats["teams"].items():
            lines.append(
                f"  {team_name} ({team_data.get('type', '')}): "
                f"{team_data['on_site']}/{team_data['total']} 在场"
            )
        return "\n".join(lines)

    def get_worker_by_phone(self, phone: str) -> Optional[dict]:
        """通过手机号查找工人"""
        return self.worker_by_phone.get(phone)

    def get_worker_by_id(self, worker_id: str) -> Optional[dict]:
        """通过 ID 查找工人"""
        return self.worker_by_id.get(worker_id)

    def get_all_phones(self) -> List[str]:
        """获取所有工人手机号"""
        return list(self.worker_by_phone.keys())

    # ============================================================
    # 工具
    # ============================================================

    @staticmethod
    def _format_duration(seconds: float) -> str:
        if seconds <= 0:
            return "00:00"
        h = int(seconds // 3600)
        m = int((seconds % 3600) // 60)
        return f"{h:02d}:{m:02d}"

    def reset_daily(self):
        """重置每日统计 (每日零点调用)"""
        for status in self.worker_statuses.values():
            status.first_seen_today = 0
            status.checkin_time = ""
            status.checkout_time = ""
            status.is_late = False
            status.is_early_leave = False
            status.on_site_duration = 0
            status.events_today = []
        self._stats_cache = {}
        self._stats_cache_time = 0


# ============================================================
# 便捷函数
# ============================================================

_default_tracker = None


def get_tracker(workers_config="configs/workers.json",
                geofence_config="configs/site_geofence.json") -> WorkerTracker:
    """获取全局追踪器 (单例)"""
    global _default_tracker
    if _default_tracker is None:
        _default_tracker = WorkerTracker(workers_config, geofence_config)
    return _default_tracker


# ============================================================
# 测试
# ============================================================

if __name__ == "__main__":
    print("=== 电子栅栏 & 工人追踪引擎测试 ===\n")

    tracker = WorkerTracker()

    # 测试: 模拟工人位置更新
    test_phones = [
        "13800001001",  # 张三 - A班组
        "13800001005",  # 孙七 - B班组
        "13800001008",  # 郑十 - C班组
    ]

    # 在工地中心附近
    center = tracker.geofence.site_center
    test_positions = [
        (center[0] + 0.0005, center[1] + 0.0005),   # 工地内
        (center[0] + 0.0010, center[1] + 0.0010),   # 工地内
        (center[0] + 0.0100, center[1] + 0.0100),   # 工地外
    ]

    for phone, (lat, lon) in zip(test_phones, test_positions):
        status = tracker.update_location(phone, lat, lon)
        dist = tracker.geofence.distance_to_site(lat, lon)
        print(f"{status.name} ({status.team}): "
              f"在工地={status.on_site}, "
              f"区域={status.current_zone or '未分区'}, "
              f"距中心={dist:.0f}m")

    print(f"\n{tracker.get_team_summary()}")
    print(f"\n在场工人: {len(tracker.get_on_site_workers())}")
    print(f"危险区工人: {len(tracker.get_workers_in_danger_zone())}")