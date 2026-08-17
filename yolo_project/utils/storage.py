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
import hashlib
from pathlib import Path
from datetime import datetime, timedelta
from typing import Optional, List, Dict, Any, Tuple
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

-- ========== P2: 照片上传 / 自动标注 / 自动重训练 ==========

CREATE TABLE IF NOT EXISTS photos (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    photo_uuid      TEXT UNIQUE NOT NULL,        -- 业务侧唯一ID (hash或uuid)
    content_hash    TEXT,                        -- 图片内容SHA256 (用于去重)
    filename        TEXT NOT NULL,
    file_path       TEXT NOT NULL,
    file_size       INTEGER DEFAULT 0,
    image_w         INTEGER,
    image_h         INTEGER,
    uploader_phone  TEXT,
    uploader_name   TEXT,
    uploader_team   TEXT,
    location_tag    TEXT,                        -- 上传时选的地点标签 (zone_a/...)
    user_tags       TEXT,                        -- JSON: 工人选的类别标签
    remark          TEXT,
    -- 状态机: uploaded → labeling → labeled → need_review → reviewed
    --                  ↘ rejected           ↓
    --                                     training → trained
    status          TEXT DEFAULT 'uploaded',
    labels_count    INTEGER DEFAULT 0,           -- 伪标签框数
    avg_confidence  REAL DEFAULT 0,              -- 伪标签平均置信度
    low_conf_ratio  REAL DEFAULT 0,              -- 低置信度(<0.5)框占比
    review_by       TEXT,
    review_at       TEXT,
    training_run_id INTEGER,                     -- 参与过的训练ID
    model_version   TEXT,                        -- 用于标注的模型版本
    details         TEXT,                        -- JSON
    created_at      TEXT DEFAULT (datetime('now', 'localtime')),
    updated_at      TEXT DEFAULT (datetime('now', 'localtime'))
);

CREATE TABLE IF NOT EXISTS photo_labels (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    photo_id        INTEGER NOT NULL,
    cls_id          INTEGER NOT NULL,
    cls_name        TEXT,
    confidence      REAL DEFAULT 0,
    -- 归一化 YOLO 格式 (cx, cy, w, h) 0~1
    cx              REAL,
    cy              REAL,
    bw              REAL,
    bh              REAL,
    -- 绝对像素坐标 (可选)
    x1              INTEGER,
    y1              INTEGER,
    x2              INTEGER,
    y2              INTEGER,
    reviewed        INTEGER DEFAULT 0,           -- 1=人工已复核/修正
    created_at      TEXT DEFAULT (datetime('now', 'localtime'))
);

CREATE TABLE IF NOT EXISTS training_runs (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    run_uuid        TEXT UNIQUE,
    trigger_type    TEXT DEFAULT 'auto',         -- auto / manual
    base_model      TEXT,                        -- 训练起点模型路径
    output_model    TEXT,                        -- 产物模型 (best.pt)
    epochs          INTEGER DEFAULT 0,
    new_images      INTEGER DEFAULT 0,           -- 本批次新增图片数
    total_images    INTEGER DEFAULT 0,
    map50           REAL,                        -- 评估指标
    status          TEXT DEFAULT 'running',      -- running / success / failed / timeout
    error_msg       TEXT,
    metrics         TEXT,                        -- JSON 完整指标
    started_at      TEXT DEFAULT (datetime('now', 'localtime')),
    finished_at     TEXT
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

CREATE INDEX IF NOT EXISTS idx_photos_status ON photos(status);
CREATE INDEX IF NOT EXISTS idx_photos_hash ON photos(content_hash);
CREATE INDEX IF NOT EXISTS idx_photos_uploader ON photos(uploader_phone);
CREATE INDEX IF NOT EXISTS idx_photo_labels_photo ON photo_labels(photo_id);
CREATE INDEX IF NOT EXISTS idx_training_runs_status ON training_runs(status);
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
        """初始化数据库 + 列迁移 (向后兼容：老库增加新列)"""
        with self._get_conn() as conn:
            conn.executescript(SCHEMA)
            self._migrate_columns(conn)
            conn.commit()

    @staticmethod
    def _columns_of(conn, table: str) -> set:
        rows = conn.execute(f"PRAGMA table_info({table})").fetchall()
        return {r[1] for r in rows}

    def _migrate_columns(self, conn):
        """对已存在的老表，安全地追加新列 (ALTER TABLE ADD COLUMN)"""
        # ---- alarms 表新列 ----
        cols = self._columns_of(conn, "alarms")
        for col, decl in [
            ("source",            "TEXT"),
            ("worker_id",         "TEXT"),
            ("resolved",          "INTEGER DEFAULT 0"),
            ("ack_at",            "TEXT"),
            ("ack_by",            "TEXT"),
            # P5: 飞书交互卡片相关
            ("ack_status",        "TEXT DEFAULT 'pending'"),  # pending/acknowledged/dismissed/snoozed
            ("snapshot_path",     "TEXT"),                    # 告警时帧截图 (jpg, 可选)
            ("snooze_until",      "TEXT"),                    # 再提醒到期时间 ISO
            ("card_message_id",   "TEXT"),                    # 飞书卡片消息 id (回调时定位)
        ]:
            if col not in cols:
                conn.execute(f"ALTER TABLE alarms ADD COLUMN {col} {decl}")
        # 建索引 (CREATE INDEX IF NOT EXISTS 天然幂等)
        conn.execute("CREATE INDEX IF NOT EXISTS idx_alarms_source ON alarms(source)")
        conn.execute("CREATE INDEX IF NOT EXISTS idx_alarms_worker ON alarms(worker_id)")
        conn.execute("CREATE INDEX IF NOT EXISTS idx_alarms_resolved ON alarms(resolved)")
        conn.execute("CREATE INDEX IF NOT EXISTS idx_alarms_ack_status ON alarms(ack_status)")
        conn.execute("CREATE INDEX IF NOT EXISTS idx_alarms_snooze ON alarms(snooze_until)")

        # ---- locations 表新列 ----
        cols = self._columns_of(conn, "locations")
        for col, decl in [
            ("zone_type", "TEXT"),
            ("speed",     "REAL DEFAULT 0"),
        ]:
            if col not in cols:
                conn.execute(f"ALTER TABLE locations ADD COLUMN {col} {decl}")
        conn.execute("CREATE INDEX IF NOT EXISTS idx_locations_team ON locations(team)")
        conn.execute("CREATE INDEX IF NOT EXISTS idx_locations_onsite ON locations(on_site)")

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
                  details: dict = None, source: str = "",
                  worker_id: str = "",
                  snapshot_path: str = None) -> int:
        """记录一条告警
        - source: 来源标识 (如 cam_entrance / gps:W005)
        - worker_id: 关联工人 (视频场景可空)
        - snapshot_path: P5 新增 — 告警时帧截图路径, 会随飞书卡片一起推送
        返回: alarm_id (主键)
        """
        if details is None:
            details = {}
        # 把 source/worker_id 也兜底写进 details，保证老代码也能查到
        details.setdefault("source", source)
        if worker_id:
            details.setdefault("worker_id", worker_id)
        with self._get_conn() as conn:
            cur = conn.execute(
                "INSERT INTO alarms (alarm_type, level, camera_id, message, "
                "details, source, worker_id, snapshot_path) "
                "VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
                (alarm_type, level, camera_id or None, message,
                 json.dumps(details, ensure_ascii=False) if details else None,
                 source or None, worker_id or None, snapshot_path or None),
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

    # ============================================================
    # P5: 飞书交互卡片 — 告警 ack / snooze / 查询未处理
    # ============================================================
    def ack_alarm(self, alarm_id: int, status: str,
                  ack_by: str = "", note: str = "") -> bool:
        """更新告警 ack 状态.
        status: acknowledged / dismissed / snoozed / pending
        ack_by:  操作人 (飞书 open_id 或姓名)
        note:    可选备注, 写入 details.ack_note
        返回: 是否成功 (alarm_id 不存在返回 False)
        """
        valid = {"acknowledged", "dismissed", "snoozed", "pending"}
        if status not in valid:
            raise ValueError(f"ack_status 非法: {status} (合法: {valid})")
        now_iso = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        with self._get_conn() as conn:
            # 同时把 ack_note 追加到 details JSON
            row = conn.execute(
                "SELECT details FROM alarms WHERE id=?", (alarm_id,)
            ).fetchone()
            details = {}
            if row and row["details"]:
                try: details = json.loads(row["details"])
                except Exception: details = {}
            if note:
                details.setdefault("ack_history", []).append({
                    "at": now_iso, "by": ack_by, "status": status, "note": note,
                })
            if status == "snoozed":
                # 默认 15 分钟后再提醒 (具体分钟由调用方在 note 里写或单独 API)
                snooze_minutes = 15
                try:
                    if isinstance(note, str) and note.isdigit():
                        snooze_minutes = int(note)
                except Exception:
                    pass
                snooze_until = (datetime.now() + timedelta(minutes=snooze_minutes)).strftime("%Y-%m-%d %H:%M:%S")
            else:
                snooze_until = None
            cur = conn.execute(
                "UPDATE alarms SET ack_status=?, ack_by=?, ack_at=?, "
                "snooze_until=?, resolved=1, details=? WHERE id=?",
                (status, ack_by or None, now_iso if status != "snoozed" else None,
                 snooze_until,
                 json.dumps(details, ensure_ascii=False) if details else None,
                 alarm_id),
            )
            conn.commit()
            return cur.rowcount > 0

    def update_alarm_card_message_id(self, alarm_id: int, card_message_id: str) -> bool:
        """记录飞书卡片消息 id, 用于回调时定位"""
        with self._get_conn() as conn:
            cur = conn.execute(
                "UPDATE alarms SET card_message_id=? WHERE id=?",
                (card_message_id, alarm_id),
            )
            conn.commit()
            return cur.rowcount > 0

    def get_alarm(self, alarm_id: int) -> Optional[Dict]:
        """按主键取一条告警"""
        with self._get_conn() as conn:
            row = conn.execute(
                "SELECT * FROM alarms WHERE id=?", (alarm_id,)
            ).fetchone()
            return dict(row) if row else None

    def query_pending_alarms(self, hours: int = 24,
                             ack_status: str = "pending") -> List[Dict]:
        """查未处理 (或指定状态) 的告警, 默认最近 24h"""
        cutoff = (datetime.now() - timedelta(hours=hours)).strftime("%Y-%m-%d %H:%M:%S")
        with self._get_conn() as conn:
            rows = conn.execute(
                "SELECT * FROM alarms WHERE created_at >= ? AND ack_status=? "
                "ORDER BY created_at DESC LIMIT 500",
                (cutoff, ack_status),
            ).fetchall()
            return [dict(r) for r in rows]

    def query_alarms_due_for_reminder(self) -> List[Dict]:
        """查 snoozed 且 snooze_until <= now 的告警 — 该再次提醒了"""
        now_iso = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        with self._get_conn() as conn:
            rows = conn.execute(
                "SELECT * FROM alarms WHERE ack_status='snoozed' "
                "AND snooze_until IS NOT NULL AND snooze_until <= ? "
                "ORDER BY snooze_until ASC LIMIT 100",
                (now_iso,),
            ).fetchall()
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
                     battery: int = 100, zone_type: str = "",
                     speed: float = 0) -> int:
        """记录一条定位
        - zone_type: work/safe/danger/restricted 等 (对应 StandardZone.type)
        - speed: 移动速度 m/s (GPS 提供)
        """
        with self._get_conn() as conn:
            cur = conn.execute(
                "INSERT INTO locations (worker_id, worker_name, team, "
                "latitude, longitude, accuracy, on_site, current_zone, "
                "in_danger, battery, zone_type, speed) "
                "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
                (worker_id, worker_name, team,
                 round(latitude, 6), round(longitude, 6), round(accuracy, 1),
                 1 if on_site else 0, current_zone,
                 1 if in_danger else 0, battery,
                 zone_type or None, round(float(speed), 2)),
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
            tables = ["alarms", "locations", "detections", "events",
                      "photos", "photo_labels", "training_runs"]
            stats = {}
            for table in tables:
                try:
                    row = conn.execute(f"SELECT COUNT(*) as cnt FROM {table}").fetchone()
                    stats[table] = row["cnt"] if row else 0
                except sqlite3.OperationalError:
                    stats[table] = 0  # 老库表可能不存在
            stats["db_size_mb"] = round(
                self.db_path.stat().st_size / (1024 * 1024), 2
            ) if self.db_path.exists() else 0
            return stats

    # ============================================================
    # 工具: 内容 hash 去重
    # ============================================================

    @staticmethod
    def compute_content_hash(data: bytes) -> str:
        """计算图片内容的 SHA256 (用于去重)"""
        return hashlib.sha256(data).hexdigest()

    def find_photo_by_hash(self, content_hash: str) -> Optional[Dict]:
        """根据内容 hash 查找已存在的照片 (去重命中)"""
        if not content_hash:
            return None
        with self._get_conn() as conn:
            row = conn.execute(
                "SELECT * FROM photos WHERE content_hash = ? ORDER BY id DESC LIMIT 1",
                (content_hash,),
            ).fetchone()
            return dict(row) if row else None

    # ============================================================
    # 照片 (photos) 管理
    # ============================================================

    def add_photo(self, photo_uuid: str, *,
                  filename: str, file_path: str,
                  content_hash: str = "",
                  file_size: int = 0,
                  image_w: int = None, image_h: int = None,
                  uploader_phone: str = "", uploader_name: str = "",
                  uploader_team: str = "",
                  location_tag: str = "", user_tags: list = None,
                  remark: str = "", model_version: str = "",
                  status: str = "uploaded", details: dict = None) -> int:
        """登记一条新上传照片，返回 photo_id。
        若 content_hash 命中已存在的照片，则返回已有 id (负重复制文件行为由调用方决定)。
        """
        existing = self.find_photo_by_hash(content_hash) if content_hash else None
        if existing:
            return existing["id"]

        with self._get_conn() as conn:
            cur = conn.execute(
                "INSERT INTO photos (photo_uuid, content_hash, filename, file_path,"
                " file_size, image_w, image_h, uploader_phone, uploader_name,"
                " uploader_team, location_tag, user_tags, remark, model_version,"
                " status, details, updated_at) "
                "VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?, datetime('now','localtime'))",
                (
                    photo_uuid, content_hash or None, filename, file_path,
                    int(file_size), image_w, image_h,
                    uploader_phone or None, uploader_name or None,
                    uploader_team or None, location_tag or None,
                    json.dumps(user_tags, ensure_ascii=False) if user_tags else None,
                    remark or None, model_version or None,
                    status,
                    json.dumps(details, ensure_ascii=False) if details else None,
                ),
            )
            conn.commit()
            return cur.lastrowid

    def update_photo_status(self, photo_id: int, status: str, *,
                            labels_count: int = None,
                            avg_confidence: float = None,
                            low_conf_ratio: float = None,
                            review_by: str = "", review_at: str = "",
                            training_run_id: int = None,
                            details: dict = None) -> bool:
        """更新照片状态 & 可附带元数据"""
        fields = ["status = ?", "updated_at = datetime('now','localtime')"]
        params: list = [status]
        if labels_count is not None:
            fields.append("labels_count = ?")
            params.append(int(labels_count))
        if avg_confidence is not None:
            fields.append("avg_confidence = ?")
            params.append(float(avg_confidence))
        if low_conf_ratio is not None:
            fields.append("low_conf_ratio = ?")
            params.append(float(low_conf_ratio))
        if review_by:
            fields.append("review_by = ?")
            params.append(review_by)
        if review_at:
            fields.append("review_at = ?")
            params.append(review_at)
        elif review_by:
            fields.append("review_at = datetime('now','localtime')")
        if training_run_id is not None:
            fields.append("training_run_id = ?")
            params.append(int(training_run_id))
        if details:
            fields.append("details = COALESCE(details,'{}') || ?")
            params.append(json.dumps(details, ensure_ascii=False))

        params.append(int(photo_id))
        with self._get_conn() as conn:
            cur = conn.execute(f"UPDATE photos SET {', '.join(fields)} WHERE id = ?", params)
            conn.commit()
            return cur.rowcount > 0

    def get_photo(self, photo_id: int) -> Optional[Dict]:
        with self._get_conn() as conn:
            row = conn.execute("SELECT * FROM photos WHERE id = ?", (int(photo_id),)).fetchone()
            return dict(row) if row else None

    def query_photos(self, status: str = None,
                     location_tag: str = None,
                     uploader_phone: str = None,
                     need_review: bool = None,
                     limit: int = 100, offset: int = 0) -> List[Dict]:
        """查询照片列表
        - need_review=True → status in ('labeled','need_review') 未review过
        - need_review=False → status in ('reviewed','rejected','training','trained')
        """
        sql = "SELECT * FROM photos WHERE 1=1"
        params: list = []
        if status:
            sql += " AND status = ?"
            params.append(status)
        if location_tag:
            sql += " AND location_tag = ?"
            params.append(location_tag)
        if uploader_phone:
            sql += " AND uploader_phone = ?"
            params.append(uploader_phone)
        if need_review is True:
            sql += " AND status IN ('uploaded','labeling','labeled','need_review')"
        elif need_review is False:
            sql += " AND status IN ('reviewed','rejected','training','trained')"
        sql += " ORDER BY id DESC LIMIT ? OFFSET ?"
        params.extend([int(limit), int(offset)])
        with self._get_conn() as conn:
            rows = conn.execute(sql, params).fetchall()
            return [dict(r) for r in rows]

    def count_photos_by_status(self) -> Dict[str, int]:
        with self._get_conn() as conn:
            rows = conn.execute(
                "SELECT status, COUNT(*) AS cnt FROM photos GROUP BY status"
            ).fetchall()
            return {r["status"]: r["cnt"] for r in rows}

    # ============================================================
    # 照片标注 (photo_labels)
    # ============================================================

    def add_photo_label(self, photo_id: int, *,
                        cls_id: int, cls_name: str = "",
                        confidence: float = 0,
                        cx: float = None, cy: float = None,
                        bw: float = None, bh: float = None,
                        x1: int = None, y1: int = None,
                        x2: int = None, y2: int = None,
                        reviewed: bool = False) -> int:
        """写入一条伪标签框"""
        with self._get_conn() as conn:
            cur = conn.execute(
                "INSERT INTO photo_labels (photo_id, cls_id, cls_name, confidence,"
                " cx, cy, bw, bh, x1, y1, x2, y2, reviewed) "
                "VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)",
                (int(photo_id), int(cls_id), cls_name or None, float(confidence),
                 cx, cy, bw, bh, x1, y1, x2, y2, 1 if reviewed else 0),
            )
            conn.commit()
            return cur.lastrowid

    def add_photo_labels_batch(self, photo_id: int, detections: List[Dict]) -> int:
        """批量写入伪标签 (detections 格式来自 AutoLabeler.predict)"""
        if not detections:
            return 0
        rows = []
        for d in detections:
            bbox_abs = d.get("bbox_abs") or (None, None, None, None)
            bbox_yolo = d.get("bbox_yolo") or (None, None, None, None)
            rows.append((
                int(photo_id), int(d.get("cls_id", -1)), d.get("cls_name", ""),
                float(d.get("conf", 0)),
                bbox_yolo[0], bbox_yolo[1], bbox_yolo[2], bbox_yolo[3],
                bbox_abs[0], bbox_abs[1], bbox_abs[2], bbox_abs[3],
                1 if d.get("reviewed") else 0,
            ))
        with self._get_conn() as conn:
            conn.executemany(
                "INSERT INTO photo_labels (photo_id, cls_id, cls_name, confidence,"
                " cx, cy, bw, bh, x1, y1, x2, y2, reviewed) "
                "VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)", rows,
            )
            conn.commit()
        return len(rows)

    def query_photo_labels(self, photo_id: int) -> List[Dict]:
        with self._get_conn() as conn:
            rows = conn.execute(
                "SELECT * FROM photo_labels WHERE photo_id = ? ORDER BY id",
                (int(photo_id),),
            ).fetchall()
            return [dict(r) for r in rows]

    def delete_photo_labels(self, photo_id: int) -> int:
        """清除某张图的所有旧标注 (重标时用)"""
        with self._get_conn() as conn:
            cur = conn.execute("DELETE FROM photo_labels WHERE photo_id = ?", (int(photo_id),))
            conn.commit()
            return cur.rowcount or 0

    # ============================================================
    # 训练运行 (training_runs)
    # ============================================================

    def start_training_run(self, *, trigger_type: str = "auto",
                           base_model: str = "", new_images: int = 0,
                           total_images: int = 0, epochs: int = 0,
                           run_uuid: str = "") -> int:
        """登记一次训练开始，返回 run_id"""
        with self._get_conn() as conn:
            cur = conn.execute(
                "INSERT INTO training_runs (run_uuid, trigger_type, base_model,"
                " epochs, new_images, total_images, status) VALUES (?,?,?,?,?,?, 'running')",
                (run_uuid or None, trigger_type, base_model or None,
                 int(epochs or 0), int(new_images or 0), int(total_images or 0)),
            )
            conn.commit()
            return cur.lastrowid

    def finish_training_run(self, run_id: int, *,
                            status: str = "success",
                            output_model: str = "", map50: float = None,
                            error_msg: str = "", metrics: dict = None):
        with self._get_conn() as conn:
            conn.execute(
                "UPDATE training_runs SET status=?, output_model=?, map50=?,"
                " error_msg=?, metrics=?, finished_at=datetime('now','localtime') "
                "WHERE id=?",
                (status, output_model or None,
                 float(map50) if map50 is not None else None,
                 error_msg or None,
                 json.dumps(metrics, ensure_ascii=False) if metrics else None,
                 int(run_id)),
            )
            conn.commit()

    def query_training_runs(self, limit: int = 20) -> List[Dict]:
        with self._get_conn() as conn:
            rows = conn.execute(
                "SELECT * FROM training_runs ORDER BY id DESC LIMIT ?", (int(limit),)
            ).fetchall()
            return [dict(r) for r in rows]

    def get_latest_training_run(self) -> Optional[Dict]:
        with self._get_conn() as conn:
            row = conn.execute(
                "SELECT * FROM training_runs ORDER BY id DESC LIMIT 1"
            ).fetchone()
            return dict(row) if row else None


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