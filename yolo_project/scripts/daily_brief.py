# -*- coding: utf-8 -*-
"""
scripts/daily_brief.py — 智慧工地每日早会安全简报生成器

统计窗口: 昨日 20:00 → 今日 08:00 (12h 夜班 + 早会前)
内容:
  - 安全装备合规率 (helmet / vest, 来自 detections 小时聚合)
  - 告警总数 + 按类型/级别分布
  - 危险区域入侵次数
  - 班组出勤 (来自 GPS, 可选)
  - 模型自训练新图数 + run 数 + 最佳 mAP50
  - "未处理告警"提醒 (pending/snoozed 状态)

调用方式:
  # 默认 8:00 跑, 发给项目经理+安全员
  python scripts/daily_brief.py --db runs/data/site.db \
      --personnel configs/personnel.json

  # 自定义窗口 (调试)
  python scripts/daily_brief.py --window-start '2026-08-16 20:00' \
      --window-end '2026-08-17 08:00' --dry-run

  # systemd timer 调用 (每天 08:00 自动跑)
  python scripts/daily_brief.py --db runs/data/site.db

systemd 集成: deploy/site-daily-brief.service + .timer
"""

from __future__ import annotations

import argparse
import json
import logging
import sys
from datetime import datetime, timedelta
from pathlib import Path
from typing import Optional

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from utils.storage import SiteDatabase
from utils.notify import LarkNotifier

logger = logging.getLogger("daily_brief")


# =========================================================================
# 1) 数据汇总
# =========================================================================
def collect_brief_data(storage: SiteDatabase,
                       window_start: str,
                       window_end: str,
                       gps_server=None) -> dict:
    """汇总一段时间窗口内的简报数据.

    Args:
        storage: SiteDatabase 实例
        window_start / window_end: '%Y-%m-%d %H:%M:%S' 字符串
        gps_server: 可选, 传入则查询班组考勤
    Returns:
        {
            'helmet_rate': float|None, 'vest_rate': float|None,
            'total_persons': int, 'no_helmets': int, 'no_vests': int,
            'intrusions': int,
            'alarms_total': int, 'alarms_by_type': dict, 'alarms_by_level': dict,
            'attendance': {...}|None,
            'new_photos': int, 'new_trainings': int, 'best_map50': float|None,
            'pending_alarms': int, 'snoozed_alarms': int,
        }
    """
    # ---- 检测统计 (按小时聚合的 detections 表) ----
    # detections.hour 是 'YYYY-MM-DD HH' 格式, 转成 'YYYY-MM-DD HH:00:00' 比对
    ws_hour = window_start[:13]  # 'YYYY-MM-DD HH'
    we_hour = window_end[:13]
    with storage._get_conn() as conn:
        det_row = conn.execute(
            "SELECT "
            "COALESCE(SUM(total_persons),0) as total_persons, "
            "COALESCE(SUM(total_no_helmets),0) as total_no_helmets, "
            "COALESCE(SUM(total_no_vests),0) as total_no_vests, "
            "COALESCE(SUM(intrusion_count),0) as intrusion_count "
            "FROM detections WHERE hour >= ? AND hour <= ?",
            (ws_hour, we_hour),
        ).fetchone()
    persons = int(det_row["total_persons"] or 0)
    no_helmets = int(det_row["total_no_helmets"] or 0)
    no_vests = int(det_row["total_no_vests"] or 0)
    intrusions = int(det_row["intrusion_count"] or 0)
    helmet_rate = (persons - no_helmets) / persons if persons > 0 else None
    vest_rate = (persons - no_vests) / persons if persons > 0 else None

    # ---- 告警 ----
    alarms = storage.query_alarms(limit=5000, offset=0,
                                  start_time=window_start,
                                  end_time=window_end)
    alarms_by_type: dict = {}
    alarms_by_level: dict = {}
    for a in alarms:
        tp = a.get("alarm_type") or "other"
        lv = a.get("level") or "info"
        alarms_by_type[tp] = alarms_by_type.get(tp, 0) + 1
        alarms_by_level[lv] = alarms_by_level.get(lv, 0) + 1

    # ---- 照片 + 训练 (按 created_at 在窗口内) ----
    new_photos = 0
    for p in storage.query_photos(status=None, limit=5000):
        # photos 表的 created_at 即上传时间
        ts = p.get("created_at") or p.get("uploaded_at") or ""
        if window_start <= ts <= window_end:
            new_photos += 1
    new_trainings = 0
    best_map50 = None
    for r in storage.query_training_runs(limit=500):
        # training_runs 表用 started_at (有的版本可能叫 created_at, 兼容)
        ts = r.get("started_at") or r.get("created_at") or ""
        if window_start <= ts <= window_end:
            new_trainings += 1
            m = r.get("map50")
            if m is not None and (best_map50 is None or m > best_map50):
                best_map50 = m

    # ---- 待处理告警 (跨窗口统计) ----
    pending = len(storage.query_pending_alarms(hours=72, ack_status="pending"))
    snoozed = len(storage.query_alarms_due_for_reminder())

    # ---- 班组出勤 (可选) ----
    attendance = None
    if gps_server is not None:
        try:
            attendance = gps_server._build_attendance_summary()
        except Exception as e:
            logger.warning("gps_server._build_attendance_summary 失败: %s", e)
            attendance = None

    return {
        "helmet_rate": helmet_rate,
        "vest_rate": vest_rate,
        "total_persons": persons,
        "no_helmets": no_helmets,
        "no_vests": no_vests,
        "intrusions": intrusions,
        "alarms_total": len(alarms),
        "alarms_by_type": alarms_by_type,
        "alarms_by_level": alarms_by_level,
        "attendance": attendance,
        "new_photos": new_photos,
        "new_trainings": new_trainings,
        "best_map50": best_map50,
        "pending_alarms": pending,
        "snoozed_alarms": snoozed,
    }


# =========================================================================
# 2) 主流程
# =========================================================================
def run_brief(*, db_path: str = "runs/data/site.db",
              personnel_config: str = "configs/personnel.json",
              window_start: Optional[str] = None,
              window_end: Optional[str] = None,
              gps_server=None,
              dry_run: bool = False,
              notify_roles: list = None) -> dict:
    """生成并发送每日简报. 返回简报数据 + 发送结果."""
    storage = SiteDatabase(db_path)

    # 默认窗口: 昨日 20:00 → 今日 08:00
    if window_end is None:
        window_end = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    if window_start is None:
        # 找最近的 20:00 (如果现在是 8:00, 就是昨天 20:00)
        end_dt = datetime.strptime(window_end, "%Y-%m-%d %H:%M:%S")
        start_dt = end_dt.replace(hour=20, minute=0, second=0, microsecond=0)
        if start_dt >= end_dt:
            start_dt -= timedelta(days=1)
        window_start = start_dt.strftime("%Y-%m-%d %H:%M:%S")

    logger.info("每日简报窗口: %s → %s", window_start, window_end)

    data = collect_brief_data(storage, window_start, window_end, gps_server)
    date_str = window_end[:10]

    # 打印一份本地预览 (即使 dry_run=False 也打, 方便日志审计)
    _print_brief(date_str, window_start, window_end, data)

    if dry_run:
        logger.info("--dry-run 模式, 不发送飞书")
        return {"data": data, "sent": None, "dry_run": True}

    notifier = LarkNotifier(personnel_config, storage=storage)
    r = notifier.send_daily_brief_card(
        date_str=date_str, window_start=window_start, window_end=window_end,
        helmet_rate=data["helmet_rate"], vest_rate=data["vest_rate"],
        total_persons=data["total_persons"],
        no_helmets=data["no_helmets"], no_vests=data["no_vests"],
        intrusions=data["intrusions"],
        alarms_total=data["alarms_total"],
        alarms_by_type=data["alarms_by_type"],
        alarms_by_level=data["alarms_by_level"],
        attendance=data["attendance"],
        new_photos=data["new_photos"],
        new_trainings=data["new_trainings"],
        best_map50=data["best_map50"],
        notify_roles=notify_roles,
    )
    logger.info("飞书简报发送结果: ok=%s  sent_to=%d",
                r.get("ok"), len(r.get("sent_to", [])))
    return {"data": data, "sent": r, "dry_run": False}


def _print_brief(date_str: str, window_start: str, window_end: str,
                 data: dict):
    """打印一份 ASCII 预览, 方便日志/journalctl 查看"""
    print("=" * 60)
    print(f"  📊 每日安全简报 · {date_str}")
    print(f"  窗口: {window_start} → {window_end}")
    print("=" * 60)
    hr = data["helmet_rate"]
    vr = data["vest_rate"]
    print(f"  安全装备合规率:")
    print(f"    安全帽: {hr*100:.1f}%" if hr is not None else "    安全帽: -")
    print(f"    反光衣: {vr*100:.1f}%" if vr is not None else "    反光衣: -")
    print(f"    检测总人次: {data['total_persons']}  "
          f"未戴帽 {data['no_helmets']}  未穿衣 {data['no_vests']}")
    print(f"  告警分布:")
    print(f"    总数: {data['alarms_total']}  "
          f"(high={data['alarms_by_level'].get('high',0)} "
          f"med={data['alarms_by_level'].get('medium',0)} "
          f"low={data['alarms_by_level'].get('low',0)} "
          f"critical={data['alarms_by_level'].get('critical',0)})")
    print(f"    危险区入侵: {data['intrusions']} 次")
    for tp, cnt in sorted(data["alarms_by_type"].items(), key=lambda x: -x[1])[:5]:
        print(f"      - {tp}: {cnt}")
    if data["attendance"]:
        a = data["attendance"]
        print(f"  班组出勤: 应到 {a.get('expected_count','-')}  "
              f"实到 {a.get('present_count','-')}  "
              f"出勤率 {a.get('attendance_rate','-')}")
    print(f"  模型自训练: 新图 {data['new_photos']}  "
          f"训练 run {data['new_trainings']}  "
          f"最佳 mAP50 {data['best_map50']}")
    print(f"  待处理告警: pending {data['pending_alarms']}  "
          f"snoozed 到期 {data['snoozed_alarms']}")
    print("=" * 60)


# =========================================================================
# 3) CLI
# =========================================================================
def main():
    ap = argparse.ArgumentParser(description="智慧工地 · 每日早会安全简报")
    ap.add_argument("--db", default="runs/data/site.db", help="SQLite 路径")
    ap.add_argument("--personnel", default="configs/personnel.json",
                    help="人员配置 (含飞书 open_id)")
    ap.add_argument("--window-start", default=None,
                    help="窗口起始 (默认: 昨日 20:00)  例: '2026-08-16 20:00:00'")
    ap.add_argument("--window-end", default=None,
                    help="窗口结束 (默认: 现在)  例: '2026-08-17 08:00:00'")
    ap.add_argument("--dry-run", action="store_true",
                    help="只打印不发送 (调试)")
    ap.add_argument("--verbose", action="store_true")
    args = ap.parse_args()

    logging.basicConfig(
        level=logging.DEBUG if args.verbose else logging.INFO,
        format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    )
    r = run_brief(db_path=args.db, personnel_config=args.personnel,
                  window_start=args.window_start, window_end=args.window_end,
                  dry_run=args.dry_run)
    if args.dry_run:
        print("\n[dry-run] 简报数据 JSON:")
        print(json.dumps(r["data"], ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
