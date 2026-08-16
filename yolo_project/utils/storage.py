"""
智慧工地 - SQLite 持久化存储
存储告警记录、定位历史、检测统计，支持查询和报表

数据库结构:
  - alarms: 告警记录
  - locations: 工人定位历史
  - detections: 检测统计 (按小时聚合)
  - events: 通用事件日志

用法:
  from utils.storage import get_storage

  db = get_storage("runs/data/site.db")
  db.log_alarm(type="no_helmet", camera_id="cam_01", count=3)
  db.log_location(worker_id="W001", lat=39.9, lon=116.4, on_site=True)
  db.query_alarms(limit=50, camera_id="cam_01")
"""

import sqlite3
import json
import threading
from pathlib import Path
from datetime import datetime
from typing import Optional, List, Dict, Any
from contextlib import contextmanager

from utils.common import ensure_dir, format_timestamp, now_str


# ============================================================
# 数据库 Schema
# ============================================================

SCHEMA = """
CREATE TABLE IF NOT EXISTS alarms (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    alarm_type  TEXT NOT NULL,
    level       TEXT DEFAULT 'high',
    camera_id   TEXT,
    message     TEXT,
    details     TEXT,       -- JSON
    created_at  TEXT DEFAULT (datetime('now', 'localtime'))
);

CREATE TABLE IF NOT EXISTS locations (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    worker_id   TEXT NOT NULL,
    worker_name TEXT,
    team        TEXT,
    latitude    REAL,
    longitude   REAL,
    accuracy    REAL DEFAULT 0,
    on_site     INTEGER DEFAULT 0,
    current_zone TEXT,
    in_danger   INTEGER DEFAULT 0,
    battery     INTEGER DEFAULT 100,
    created_at  TEXT DEFAULT (datetime('now', 'localtime'))
);

CREATE TABLE IF NOT EXISTS detections (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    camera_id   TEXT NOT NULL,
    hour        TEXT NOT NULL,       -- '2026-08-16 14'
    total_persons     INTEGER DEFAULT 0,
    total_helmets     INTEGER DEFAULT 0,
    total_no_helmets  INTEGER DEFAULT 0,
    total_vests       INTEGER DEFAULT 0,
    total_no_vests    INTEGER DEFAULT 0,
    total_vehicles    INTEGER DEFAULT 0,
    helmet_compliance  REAL DEFAULT 0,
    vest_compliance    REAL DEFAULT 0,
    intrusion_count    INTEGER DEFAULT 0,
    updated_at  TEXT DEFAULT (datetime('now', 'localtime')),
    UNIQUE(camera_id, hour)
);

CREATE TABLE IF NOT EXISTS events (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    event_type  TEXT NOT NULL,
    source      TEXT,
    message     TEXT,
    details     TEXT,
    created_at  TEXT DEFAULT (datetime('now', 'localtime'))
);

CREATE INDEX IF NOT EXISTS idx_alarms_camera ON alarms(camera_id);
CREATE INDEX IF NOT EXISTS idx_alarms_time ON alarms(created_at);
CREATE INDEX IF NOT EXISTS idx_alarms_type ON alarms(alarm_type);
CREATE INDEX IF NOT EXISTS idx_locations_worker ON locations(worker_id);
CREATE INDEX IF NOT EXISTS idx_locations_time ON locations(created_at);
CREATE INDEX IF NOT EXISTS idx_detections_camera ON detections(camera_id);
CREATE INDEX IF NOT EXISTS idx_detections_hour ON detections(hour);
CREATE INDEX IF NOT EXISTS idx_events_type ON events(event_type);
CREATE INDEX IF NOT EXISTS idx_events_time ON events(created_at);
"""


# ============================================================
# 数据库管理器
# ============================================================

class SiteDatabase:
    """智慧工地数据库"""

    def __init__(self, db_path: str = "runs/data/site.db"):
        self.db_path = Path(db_path)
        ensure_dir(self.db_path.parent)
        self._local = threading.local()
        self._init_db()

    def _init_db(self):
        """初始化数据库"""
        with self._get_conn() as conn:
            conn.executescript(SCHEMA)
            conn.commit()

    @contextmanager
    def _get_conn(self):
        """获取线程安全的数据库连接"""
        if not hasattr(self._local, "conn") or self._local.conn is None:
            self._local.conn = sqlite3.connect(
                str(self.db_path), check_same_thread=False
            )
            self._local.conn.row_factory = sqlite3.Row
            self._local.conn.execute("PRAGMA journal_mode=WAL")
            self._local.conn.execute("PRAGMA synchronous=NORMAL")
        try:
            yield self._local.conn
        except Exception:
            self._local.conn.rollback()
            raise

    # ============================================================
    # 告警记录
    # ============================================================

    def log_alarm(self, alarm_type: str, message: str = "",
                  camera_id: str = "", level: str = "high",
                  details: dict = None) -> int:
        """记录一条告警"""
        with self._get_conn() as conn:
            cur = conn.execute(
                "INSERT INTO alarms (alarm_type, level, camera_id, message, details) "
                "VALUES (?, ?, ?, ?, ?)",
                (alarm_type, level, camera_id, message,
                 json.dumps(details, ensure_ascii=False) if details else None),
            )
            conn.commit()
            return cur.lastrowid

    def query_alarms(self, limit: int = 50, offset: int = 0,
                     camera_id: str = None, alarm_type: str = None,
                     start_time: str = None, end_time: str = None,
                     level: str = None) -> List[Dict]:
        """查询告警记录"""
        conditions = []
        params = []

        if camera_id:
            conditions.append("camera_id = ?")
            params.append(camera_id)
        if alarm_type:
            conditions.append("alarm_type = ?")
            params.append(alarm_type)
        if level:
            conditions.append("level = ?")
            params.append(level)
        if start_time:
            conditions.append("created_at >= ?")
            params.append(start_time)
        if end_time:
            conditions.append("created_at <= ?")
            params.append(end_time)

        where = (" WHERE " + " AND ".join(conditions)) if conditions else ""
        sql = f"SELECT * FROM alarms{where} ORDER BY created_at DESC LIMIT ? OFFSET ?"
        params.extend([limit, offset])

        with self._get_conn() as conn:
            rows = conn.execute(sql, params).fetchall()
            return [dict(r) for r in rows]

    def count_alarms_today(self) -> Dict[str, int]:
        """统计今天各类型告警数量"""
        today = datetime.now().strftime("%Y-%m-%d")
        with self._get_conn() as conn:
            rows = conn.execute(
                "SELECT alarm_type, COUNT(*) as cnt FROM alarms "
                "WHERE created_at >= ? GROUP BY alarm_type",
                (today,),
            ).fetchall()
            return {r["alarm_type"]: r["cnt"] for r in rows}

    def get_daily_alarm_summary(self, date: str = None) -> Dict:
        """获取每日告警摘要"""
        date = date or datetime.now().strftime("%Y-%m-%d")
        with self._get_conn() as conn:
            row = conn.execute(
                "SELECT COUNT(*) as total, "
                "SUM(CASE WHEN level='critical' THEN 1 ELSE 0 END) as critical_count, "
                "SUM(CASE WHEN level='high' THEN 1 ELSE 0 END) as high_count "
                "FROM alarms WHERE created_at >= ? AND created_at < ?",
                (date, f"{date} 23:59:59"),
            ).fetchone()
            return dict(row) if row else {"total": 0, "critical_count": 0, "high_count": 0}

    # ============================================================
    # 定位记录
    # ============================================================

    def log_location(self, worker_id: str, worker_name: str = "",
                     team: str = "", latitude: float = 0, longitude: float = 0,
                     accuracy: float = 0, on_site: bool = False,
                     current_zone: str = "", in_danger: bool = False,
                     battery: int = 100) -> int:
        """记录一条定位"""
        with self._get_conn() as conn:
            cur = conn.execute(
                "INSERT INTO locations (worker_id, worker_name, team, "
                "latitude, longitude, accuracy, on_site, current_zone, "
                "in_danger, battery) "
                "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
                (worker_id, worker_name, team,
                 round(latitude, 6), round(longitude, 6), round(accuracy, 1),
                 1 if on_site else 0, current_zone,
                 1 if in_danger else 0, battery),
            )
            conn.commit()
            return cur.lastrowid

    def query_locations(self, worker_id: str = None,
                        limit: int = 100, offset: int = 0,
                        start_time: str = None) -> List[Dict]:
        """查询定位记录"""
        conditions = []
        params = []

        if worker_id:
            conditions.append("worker_id = ?")
            params.append(worker_id)
        if start_time:
            conditions.append("created_at >= ?")
            params.append(start_time)

        where = (" WHERE " + " AND ".join(conditions)) if conditions else ""
        sql = f"SELECT * FROM locations{where} ORDER BY created_at DESC LIMIT ? OFFSET ?"
        params.extend([limit, offset])

        with self._get_conn() as conn:
            rows = conn.execute(sql, params).fetchall()
            return [dict(r) for r in rows]

    def get_latest_locations(self) -> List[Dict]:
        """获取每个工人最新位置"""
        with self._get_conn() as conn:
            rows = conn.execute(
                "SELECT worker_id, worker_name, team, latitude, longitude, "
                "on_site, current_zone, in_danger, battery, "
                "created_at as last_update "
                "FROM ("
                "  SELECT *, ROW_NUMBER() OVER (PARTITION BY worker_id ORDER BY created_at DESC, id DESC) as rn "
                "  FROM locations"
                ") WHERE rn = 1"
            ).fetchall()
            return [dict(r) for r in rows]

    def get_worker_timeline(self, worker_id: str,
                            date: str = None) -> List[Dict]:
        """获取工人当天轨迹"""
        date = date or datetime.now().strftime("%Y-%m-%d")
        with self._get_conn() as conn:
            rows = conn.execute(
                "SELECT latitude, longitude, on_site, current_zone, created_at "
                "FROM locations WHERE worker_id = ? AND created_at >= ? "
                "ORDER BY created_at",
                (worker_id, date),
            ).fetchall()
            return [dict(r) for r in rows]

    # ============================================================
    # 检测统计
    # ============================================================

    def log_detection(self, camera_id: str,
                      total_persons: int = 0,
                      total_helmets: int = 0,
                      total_no_helmets: int = 0,
                      total_vests: int = 0,
                      total_no_vests: int = 0,
                      total_vehicles: int = 0,
                      intrusion_count: int = 0):
        """记录检测统计 (按小时聚合)"""
        hour = datetime.now().strftime("%Y-%m-%d %H")

        total_gear = total_helmets + total_no_helmets
        total_vest = total_vests + total_no_vests

        helmet_rate = (total_helmets / total_gear * 100) if total_gear > 0 else 0
        vest_rate = (total_vests / total_vest * 100) if total_vest > 0 else 0

        with self._get_conn() as conn:
            conn.execute(
                "INSERT INTO detections (camera_id, hour, total_persons, "
                "total_helmets, total_no_helmets, total_vests, total_no_vests, "
                "total_vehicles, helmet_compliance, vest_compliance, intrusion_count) "
                "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?) "
                "ON CONFLICT(camera_id, hour) DO UPDATE SET "
                "total_persons = total_persons + excluded.total_persons, "
                "total_helmets = total_helmets + excluded.total_helmets, "
                "total_no_helmets = total_no_helmets + excluded.total_no_helmets, "
                "total_vests = total_vests + excluded.total_vests, "
                "total_no_vests = total_no_vests + excluded.total_no_vests, "
                "total_vehicles = total_vehicles + excluded.total_vehicles, "
                "intrusion_count = intrusion_count + excluded.intrusion_count, "
                "helmet_compliance = (total_helmets*100.0)/NULLIF(total_helmets+total_no_helmets,0), "
                "vest_compliance = (total_vests*100.0)/NULLIF(total_vests+total_no_vests,0), "
                "updated_at = datetime('now', 'localtime')",
                (camera_id, hour, total_persons, total_helmets, total_no_helmets,
                 total_vests, total_no_vests, total_vehicles,
                 round(helmet_rate, 1), round(vest_rate, 1), intrusion_count),
            )
            conn.commit()

    def query_detections(self, camera_id: str = None,
                         hours: int = 24) -> List[Dict]:
        """查询检测统计"""
        with self._get_conn() as conn:
            if camera_id:
                rows = conn.execute(
                    "SELECT * FROM detections WHERE camera_id = ? "
                    "ORDER BY hour DESC LIMIT ?",
                    (camera_id, hours),
                ).fetchall()
            else:
                rows = conn.execute(
                    "SELECT hour, SUM(total_persons) as total_persons, "
                    "SUM(total_helmets) as total_helmets, "
                    "SUM(total_no_helmets) as total_no_helmets, "
                    "SUM(total_vests) as total_vests, "
                    "SUM(total_no_vests) as total_no_vests, "
                    "SUM(total_vehicles) as total_vehicles, "
                    "SUM(intrusion_count) as intrusion_count "
                    "FROM detections GROUP BY hour ORDER BY hour DESC LIMIT ?",
                    (hours,),
                ).fetchall()
            return [dict(r) for r in rows]

    def get_daily_summary(self, date: str = None) -> Dict:
        """获取每日摘要"""
        date = date or datetime.now().strftime("%Y-%m-%d")
        with self._get_conn() as conn:
            row = conn.execute(
                "SELECT SUM(total_persons) as total_persons, "
                "SUM(total_helmets) as total_helmets, "
                "SUM(total_no_helmets) as total_no_helmets, "
                "SUM(total_vests) as total_vests, "
                "SUM(total_no_vests) as total_no_vests, "
                "SUM(total_vehicles) as total_vehicles, "
                "SUM(intrusion_count) as total_intrusions "
                "FROM detections WHERE hour >= ?",
                (date,),
            ).fetchone()
            return dict(row) if row else {}

    # ============================================================
    # 事件日志
    # ============================================================

    def log_event(self, event_type: str, source: str = "",
                  message: str = "", details: dict = None):
        """记录通用事件"""
        with self._get_conn() as conn:
            conn.execute(
                "INSERT INTO events (event_type, source, message, details) "
                "VALUES (?, ?, ?, ?)",
                (event_type, source, message,
                 json.dumps(details, ensure_ascii=False) if details else None),
            )
            conn.commit()

    def query_events(self, event_type: str = None,
                     limit: int = 50, hours: int = 24) -> List[Dict]:
        """查询事件"""
        with self._get_conn() as conn:
            conditions = []
            params = []
            if event_type:
                conditions.append("event_type = ?")
                params.append(event_type)
            if hours > 0:
                conditions.append("created_at >= datetime('now', 'localtime', '-{} hours')".format(hours))

            where = (" WHERE " + " AND ".join(conditions)) if conditions else ""
            sql = f"SELECT * FROM events{where} ORDER BY created_at DESC LIMIT ?"
            params.append(limit)

            rows = conn.execute(sql, params).fetchall()
            return [dict(r) for r in rows]

    # ============================================================
    # 维护
    # ============================================================

    def cleanup(self, days: int = 90):
        """清理过期数据"""
        with self._get_conn() as conn:
            conn.execute(
                "DELETE FROM locations WHERE created_at < datetime('now', 'localtime', '-{} days')".format(days)
            )
            conn.execute(
                "DELETE FROM alarms WHERE created_at < datetime('now', 'localtime', '-{} days')".format(days)
            )
            conn.execute("VACUUM")
            conn.commit()

    def get_db_stats(self) -> Dict:
        """获取数据库统计"""
        with self._get_conn() as conn:
            tables = ["alarms", "locations", "detections", "events"]
            stats = {}
            for table in tables:
                row = conn.execute(f"SELECT COUNT(*) as cnt FROM {table}").fetchone()
                stats[table] = row["cnt"] if row else 0
            stats["db_size_mb"] = round(
                self.db_path.stat().st_size / (1024 * 1024), 2
            ) if self.db_path.exists() else 0
            return stats


# ============================================================
# 全局实例
# ============================================================

_db_instances: Dict[str, SiteDatabase] = {}


def get_storage(db_path: str = "runs/data/site.db") -> SiteDatabase:
    """获取数据库实例 (单例模式)"""
    if db_path not in _db_instances:
        _db_instances[db_path] = SiteDatabase(db_path)
    return _db_instances[db_path]


# ============================================================
# 测试
# ============================================================

if __name__ == "__main__":
    db = get_storage("runs/data/test_site.db")

    # 测试告警
    db.log_alarm("no_helmet", "3人未戴安全帽", "cam_01", "high")
    db.log_alarm("intrusion", "人员闯入塔吊下方", "cam_01", "critical",
                 {"zone": "塔吊下方", "person_count": 1})
    alarms = db.query_alarms(limit=5)
    print(f"告警记录: {len(alarms)} 条")

    # 测试定位
    db.log_location("W001", "张三", "A班组", 39.909, 116.397, 5.0, True, "zone_a", False)
    locs = db.get_latest_locations()
    print(f"最新定位: {len(locs)} 人")

    # 测试检测统计
    db.log_detection("cam_01", total_persons=10, total_helmets=8,
                     total_no_helmets=2, total_vests=7, total_no_vests=3)
    detections = db.query_detections("cam_01")
    print(f"检测统计: {len(detections)} 条")

    # 数据库统计
    print(f"数据库统计: {db.get_db_stats()}")

    import os
    os.remove("runs/data/test_site.db")
    print("测试完成")