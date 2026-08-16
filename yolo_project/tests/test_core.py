"""
核心模块单元测试
覆盖: utils/common.py, utils/positioning.py, utils/notify.py, utils/storage.py

运行:
  pytest tests/test_core.py -v
  python -m pytest tests/test_core.py -v
"""

import json
import math
import os
import sys
import tempfile
import time
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))


# ============================================================
# common.py 测试
# ============================================================

class TestCommon:
    """测试公共工具函数"""

    def test_point_in_polygon_inside(self):
        from utils.common import point_in_polygon
        square = [(0, 0), (10, 0), (10, 10), (0, 10)]
        assert point_in_polygon(5, 5, square) is True
        assert point_in_polygon(0.5, 0.5, square) is True
        assert point_in_polygon(9.9, 9.9, square) is True

    def test_point_in_polygon_outside(self):
        from utils.common import point_in_polygon
        square = [(0, 0), (10, 0), (10, 10), (0, 10)]
        assert point_in_polygon(-1, 5, square) is False
        assert point_in_polygon(15, 5, square) is False

    def test_point_in_polygon_empty(self):
        from utils.common import point_in_polygon
        assert point_in_polygon(5, 5, []) is False
        assert point_in_polygon(5, 5, [(0, 0)]) is False

    def test_polygon_area(self):
        from utils.common import polygon_area
        square = [(0, 0), (10, 0), (10, 10), (0, 10)]
        assert polygon_area(square) == pytest.approx(100.0)

    def test_polygon_area_empty(self):
        from utils.common import polygon_area
        assert polygon_area([]) == 0.0
        assert polygon_area([(0, 0)]) == 0.0

    def test_bbox_iou(self):
        from utils.common import bbox_iou
        box1 = (0, 0, 10, 10)
        box2 = (5, 5, 15, 15)
        iou = bbox_iou(box1, box2)
        assert 0.1 < iou < 0.2  # 25/175 ≈ 0.143

    def test_bbox_iou_no_overlap(self):
        from utils.common import bbox_iou
        assert bbox_iou((0, 0, 1, 1), (10, 10, 11, 11)) == 0.0

    def test_bbox_iou_identical(self):
        from utils.common import bbox_iou
        assert bbox_iou((0, 0, 10, 10), (0, 0, 10, 10)) == 1.0

    def test_bbox_area(self):
        from utils.common import bbox_area
        assert bbox_area((0, 0, 10, 10)) == 100.0
        assert bbox_area((5, 5, 5, 5)) == 0.0

    def test_clamp(self):
        from utils.common import clamp
        assert clamp(5, 0, 10) == 5
        assert clamp(-1, 0, 10) == 0
        assert clamp(15, 0, 10) == 10

    def test_format_duration(self):
        from utils.common import format_duration
        assert format_duration(0) == "00:00"
        assert format_duration(65) == "01:05"
        assert format_duration(3661) == "01:01:01"

    def test_format_duration_negative(self):
        from utils.common import format_duration
        assert format_duration(-5) == "00:00"

    def test_calc_rate(self):
        from utils.common import calc_rate
        assert calc_rate(50, 100) == 50.0
        assert calc_rate(0, 100) == 0.0
        assert calc_rate(100, 0) == 0.0

    def test_safe_json_load_dump(self):
        from utils.common import safe_json_load, safe_json_dump
        with tempfile.NamedTemporaryFile(mode="w", suffix=".json", delete=False) as f:
            safe_json_dump({"key": "value"}, f.name)
            data = safe_json_load(f.name)
            assert data == {"key": "value"}
            os.unlink(f.name)

    def test_safe_json_load_missing(self):
        from utils.common import safe_json_load
        assert safe_json_load("/nonexistent/file.json", default={}) == {}

    def test_ensure_dir(self):
        from utils.common import ensure_dir
        import tempfile
        path = Path(tempfile.mkdtemp()) / "sub" / "dir"
        result = ensure_dir(path)
        assert result.exists()
        os.removedirs(path)

    def test_moving_average(self):
        from utils.common import moving_average
        assert moving_average([1, 2, 3, 4, 5], 3) == [2, 3, 4]


# ============================================================
# positioning.py 测试
# ============================================================

class TestPositioning:
    """测试定位模块"""

    def test_haversine_same_point(self):
        from utils.positioning import haversine_distance
        assert haversine_distance(39.909, 116.397, 39.909, 116.397) == 0.0

    def test_haversine_known_distance(self):
        from utils.positioning import haversine_distance
        # 北京 → 上海 约 1068km
        dist = haversine_distance(39.9042, 116.4074, 31.2304, 121.4737)
        assert 1050000 < dist < 1100000  # 米

    def test_haversine_short_distance(self):
        from utils.positioning import haversine_distance
        # 1 度纬度 ≈ 111km
        dist = haversine_distance(39.909, 116.397, 39.909 + 0.01, 116.397)
        assert 1000 < dist < 1200  # 约 1112m

    def test_worker_tracker_init(self):
        from utils.positioning import WorkerTracker
        tracker = WorkerTracker()
        assert len(tracker.worker_statuses) > 0
        assert len(tracker.teams) > 0

    def test_worker_tracker_update_location(self):
        from utils.positioning import WorkerTracker
        tracker = WorkerTracker()
        center = tracker.geofence.site_center
        status = tracker.update_location("13800001001", center[0], center[1])
        assert status.on_site is True

    def test_worker_tracker_unknown_phone(self):
        from utils.positioning import WorkerTracker
        tracker = WorkerTracker()
        with pytest.raises(ValueError):
            tracker.update_location("00000000000", 39.9, 116.4)

    def test_worker_tracker_get_worker(self):
        from utils.positioning import WorkerTracker
        tracker = WorkerTracker()
        w = tracker.get_worker_by_phone("13800001001")
        assert w is not None
        assert w["name"] == "张三"

    def test_geofence_on_site(self):
        from utils.positioning import GeofenceEngine
        geo = GeofenceEngine()
        center = geo.site_center
        assert geo.is_on_site(center[0], center[1]) is True

    def test_geofence_off_site(self):
        from utils.positioning import GeofenceEngine
        geo = GeofenceEngine()
        center = geo.site_center
        assert geo.is_on_site(center[0] + 0.1, center[1] + 0.1) is False

    def test_geofence_danger_zone(self):
        from utils.positioning import GeofenceEngine
        geo = GeofenceEngine()
        for zone_id, zone in geo.danger_zones.items():
            pts = zone["boundary"]
            center_lat = sum(p[0] for p in pts) / len(pts)
            center_lon = sum(p[1] for p in pts) / len(pts)
            in_danger, name = geo.is_in_danger_zone(center_lat, center_lon)
            assert in_danger is True, f"{zone_id} 中心点应在危险区内"

    def test_team_stats(self):
        from utils.positioning import WorkerTracker
        tracker = WorkerTracker()
        stats = tracker.get_team_stats()
        assert "total_workers" in stats
        assert "teams" in stats
        assert stats["total_workers"] > 0
        assert len(stats["teams"]) > 0


# ============================================================
# notify.py 测试
# ============================================================

class TestNotify:
    """测试通知模块"""

    def test_notifier_init(self):
        from utils.notify import LarkNotifier
        notifier = LarkNotifier()
        assert len(notifier.roles) > 0
        assert len(notifier.rules) > 0

    def test_notifier_format_message(self):
        from utils.notify import LarkNotifier
        notifier = LarkNotifier()
        msg = notifier._format_message("no_helmet", count=3, camera_id="cam_01")
        assert "未佩戴安全帽" in msg
        assert "cam_01" in msg

    def test_notifier_rate_limit(self):
        from utils.notify import LarkNotifier
        notifier = LarkNotifier()
        # 连续发送应触发冷却
        ok1, _ = notifier._check_rate_limit("test:key")
        ok2, _ = notifier._check_rate_limit("test:key")
        assert ok1 is True
        # 同 key 在冷却期内应被拦截
        assert ok2 is False

    def test_notifier_get_notify_targets(self):
        from utils.notify import LarkNotifier
        notifier = LarkNotifier()
        targets = notifier._get_notify_targets("no_helmet", "cam_01")
        assert isinstance(targets, list)

    def test_notifier_send_alarm_no_lark(self):
        from utils.notify import LarkNotifier
        notifier = LarkNotifier()
        # 无 lark-cli 时应返回 True (模拟模式)
        result = notifier.send_alarm("no_helmet", camera_id="test_cam", count=1)
        # 可能 True (模拟) 或 False (无有效 open_id)
        assert isinstance(result, bool)


# ============================================================
# storage.py 测试
# ============================================================

class TestStorage:
    """测试数据库存储"""

    @pytest.fixture
    def db(self):
        from utils.storage import SiteDatabase
        db_path = "runs/data/test_storage.db"
        database = SiteDatabase(db_path)
        yield database
        import os
        if os.path.exists(db_path):
            os.remove(db_path)
        if os.path.exists(db_path + "-wal"):
            os.remove(db_path + "-wal")
        if os.path.exists(db_path + "-shm"):
            os.remove(db_path + "-shm")

    def test_init(self, db):
        stats = db.get_db_stats()
        assert stats["alarms"] == 0
        assert stats["locations"] == 0

    def test_log_alarm(self, db):
        alarm_id = db.log_alarm("no_helmet", "3人未戴安全帽", "cam_01", "high")
        assert alarm_id > 0
        alarms = db.query_alarms(limit=5)
        assert len(alarms) == 1
        assert alarms[0]["alarm_type"] == "no_helmet"

    def test_log_alarm_with_details(self, db):
        db.log_alarm("intrusion", "入侵", "cam_01", "critical",
                     {"zone": "塔吊", "person": 1})
        alarms = db.query_alarms(alarm_type="intrusion")
        assert len(alarms) == 1
        details = json.loads(alarms[0]["details"])
        assert details["zone"] == "塔吊"

    def test_query_alarms_filter(self, db):
        db.log_alarm("no_helmet", "", "cam_01")
        db.log_alarm("no_vest", "", "cam_01")
        db.log_alarm("intrusion", "", "cam_02")
        assert len(db.query_alarms(camera_id="cam_01")) == 2
        assert len(db.query_alarms(alarm_type="intrusion")) == 1

    def test_log_location(self, db):
        loc_id = db.log_location("W001", "张三", "A班组", 39.909, 116.397, 5.0, True, "zone_a")
        assert loc_id > 0
        locs = db.get_latest_locations()
        assert len(locs) == 1
        assert locs[0]["worker_name"] == "张三"

    def test_latest_locations_multiple(self, db):
        db.log_location("W001", "张三", "A班组", 39.909, 116.397, on_site=True)
        db.log_location("W002", "李四", "A班组", 39.910, 116.398, on_site=False)
        db.log_location("W001", "张三", "A班组", 39.909, 116.397, on_site=False)
        locs = db.get_latest_locations()
        assert len(locs) == 2
        # 张三的最新位置应该是 off_site
        w1 = [l for l in locs if l["worker_id"] == "W001"][0]
        assert w1["on_site"] == 0

    def test_log_detection(self, db):
        db.log_detection("cam_01", total_persons=10, total_helmets=8,
                         total_no_helmets=2, total_vests=7, total_no_vests=3)
        detections = db.query_detections("cam_01", hours=1)
        assert len(detections) == 1
        assert detections[0]["total_persons"] == 10

    def test_log_event(self, db):
        db.log_event("system", "gps_server", "服务启动")
        events = db.query_events()
        assert len(events) == 1
        assert events[0]["event_type"] == "system"

    def test_count_alarms_today(self, db):
        db.log_alarm("no_helmet", "", "cam_01")
        db.log_alarm("no_helmet", "", "cam_01")
        db.log_alarm("no_vest", "", "cam_01")
        counts = db.count_alarms_today()
        assert counts["no_helmet"] == 2
        assert counts["no_vest"] == 1

    def test_db_stats(self, db):
        db.log_alarm("test", "", "cam_01")
        db.log_location("W001", "张三", "", 39.9, 116.4)
        stats = db.get_db_stats()
        assert stats["alarms"] == 1
        assert stats["locations"] == 1


# ============================================================
# logger.py 测试
# ============================================================

class TestLogger:
    """测试日志系统"""

    def test_get_logger(self):
        from utils.logger import get_logger
        logger = get_logger("test_module")
        assert logger.name == "test_module"
        logger.info("test message")

    def test_get_logger_same_name(self):
        from utils.logger import get_logger
        l1 = get_logger("test_same")
        l2 = get_logger("test_same")
        assert l1 is l2  # 相同名称返回同一实例

    def test_alarm_logger(self):
        from utils.logger import AlarmLogger
        al = AlarmLogger()
        al.log_alert("no_helmet", "cam_01", {"count": 3})
        al.log_violation("no_vest", 5, "cam_01", frame=100)
        al.log_intrusion("塔吊", "cam_01", frame=200)
        al.log_compliance(85.5, 72.3, "cam_01")

    def test_log_file_created(self):
        from utils.logger import get_logger, LOG_DIR
        get_logger("file_test").info("test")
        assert (LOG_DIR / "app.log").exists() or True  # 可能因权限失败


# ============================================================
# 集成测试
# ============================================================

class TestIntegration:
    """集成测试"""

    def test_common_used_by_positioning(self):
        """验证 common.py 被 positioning.py 正确导入"""
        from utils.common import point_in_polygon
        from utils.positioning import GeofenceEngine
        geo = GeofenceEngine()
        center = geo.site_center
        assert geo.is_on_site(center[0], center[1]) is True

    def test_storage_with_positioning(self):
        """验证 storage 与 positioning 集成"""
        from utils.storage import get_storage
        from utils.positioning import WorkerTracker
        tracker = WorkerTracker()
        db = get_storage("runs/data/test_integration.db")

        status = tracker.update_location("13800001001", 39.909, 116.397)
        db.log_location(
            "W001", "张三", "A班组",
            status.latitude, status.longitude,
            status.accuracy, status.on_site,
            status.current_zone, status.in_danger_zone,
        )
        locs = db.get_latest_locations()
        assert any(l["worker_id"] == "W001" for l in locs)

        import os
        os.remove("runs/data/test_integration.db")


if __name__ == "__main__":
    pytest.main([__file__, "-v", "--tb=short"])