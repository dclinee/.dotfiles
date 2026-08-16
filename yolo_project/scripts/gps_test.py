#!/usr/bin/env python3
"""
手机定位端到端测试
模拟手机 GPS 上报, 验证完整流程:
  身份识别 → GPS上报 → 电子栅栏判断 → 班组统计 → 危险区预警

用法:
  # 测试全部场景
  python scripts/gps_test.py

  # 模拟工人日常 (上班→工作→午休→下班)
  python scripts/gps_test.py --daily-routine

  # 测试危险区入侵
  python scripts/gps_test.py --danger-test

  # 测试考勤 (迟到/早退)
  python scripts/gps_test.py --attendance-test
"""

import argparse
import json
import os
import sys
import time
import random
from pathlib import Path
from datetime import datetime

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from utils.positioning import (
    WorkerTracker, GeofenceEngine, haversine_distance, point_in_polygon,
)


# ============================================================
# 测试场景
# ============================================================

def test_identity_recognition(tracker):
    """测试: 手机号 → 身份识别"""
    print(f"\n{'─'*50}")
    print(f"  测试 1: 手机号身份识别")
    print(f"{'─'*50}")

    phones = {
        "13800001001": "张三 (A班组, worker)",
        "13800001004": "赵六 (A班组, team_leader)",
        "13800001007": "吴九 (B班组, team_leader)",
        "13800001010": "陈十二 (C班组, team_leader)",
        "13900000000": "未注册",
    }

    for phone, expected in phones.items():
        worker = tracker.get_worker_by_phone(phone)
        if worker:
            result = f"{worker['name']} ({worker['team']}, {worker['role']})"
            status = "通过" if expected != "未注册" else "失败"
            print(f"  [{status}] {phone} → {result}")
        else:
            status = "通过" if expected == "未注册" else "失败"
            print(f"  [{status}] {phone} → 未找到")


def test_geofence_accuracy(tracker):
    """测试: 电子栅栏精度"""
    print(f"\n{'─'*50}")
    print(f"  测试 2: 电子栅栏判断精度")
    print(f"{'─'*50}")

    geo = tracker.geofence
    center = geo.site_center

    test_points = [
        (center[0], center[1], True, "工地中心"),
        (center[0] + 0.0005, center[1] + 0.0005, True, "工地内"),
        (center[0] + 0.002, center[1] + 0.002, True, "工地边缘"),
        (center[0] + 0.01, center[1] + 0.01, False, "工地外 1km"),
        (center[0] + 0.05, center[1] + 0.05, False, "工地外 5km"),
    ]

    for lat, lon, expected, desc in test_points:
        result = geo.is_on_site(lat, lon)
        dist = geo.distance_to_site(lat, lon)
        status = "通过" if result == expected else "失败"
        print(f"  [{status}] {desc}: 在场={result} (距中心 {dist:.0f}m)")


def test_location_update(tracker):
    """测试: GPS 位置更新 & 状态变更"""
    print(f"\n{'─'*50}")
    print(f"  测试 3: GPS 位置更新 & 状态变更")
    print(f"{'─'*50}")

    center = tracker.geofence.site_center
    test_phone = "13800001001"  # 张三

    # 场景序列
    scenarios = [
        # (lat, lon, 描述, 预期onsite)
        (center[0] + 0.0005, center[1] + 0.0005, "进场 (工地内)", True),
        (center[0] + 0.0008, center[1] + 0.0008, "移动 (仍在工地内)", True),
        (center[0] + 0.015, center[1] + 0.015, "离场 (工地外 1.5km)", False),
        (center[0] + 0.0005, center[1] + 0.0005, "返场 (回到工地内)", True),
    ]

    for lat, lon, desc, expected in scenarios:
        status = tracker.update_location(test_phone, lat, lon)
        zone = status.current_zone or "未分区"
        dist = haversine_distance(lat, lon, center[0], center[1])
        ok = status.on_site == expected
        status_str = "通过" if ok else "失败"
        print(f"  [{status_str}] {desc}: onsite={status.on_site}, "
              f"zone={zone}, dist={dist:.0f}m")

    # 检查签到时间
    status = tracker.get_worker_status("W001")
    print(f"\n  签到: {status.checkin_time or 'N/A'}")
    print(f"  在场时长: {WorkerTracker._format_duration(status.on_site_duration)}")
    print(f"  事件数: {len(status.events_today)}")


def test_danger_zone(tracker):
    """测试: 危险区入侵检测"""
    print(f"\n{'─'*50}")
    print(f"  测试 4: 危险区入侵检测")
    print(f"{'─'*50}")

    geo = tracker.geofence
    test_phone = "13800001005"  # 孙七

    for zone_id, zone in geo.danger_zones.items():
        # 取危险区中心
        pts = zone["boundary"]
        center_lat = sum(p[0] for p in pts) / len(pts)
        center_lon = sum(p[1] for p in pts) / len(pts)

        status = tracker.update_location(test_phone, center_lat, center_lon)
        in_danger, danger_name = geo.is_in_danger_zone(center_lat, center_lon)
        print(f"  {zone['name']}: in_danger={in_danger} "
              f"(检测结果: {status.in_danger_zone})")

    print(f"\n  危险区工人: {len(tracker.get_workers_in_danger_zone())}")


def test_team_stats(tracker):
    """测试: 班组统计"""
    print(f"\n{'─'*50}")
    print(f"  测试 5: 班组统计")
    print(f"{'─'*50}")

    stats = tracker.get_team_stats()
    print(f"  总工人: {stats['total_workers']}")
    print(f"  在场: {stats['on_site']} | 离场: {stats['off_site']}")
    print(f"  更新: {stats['updated_at']}")
    print(f"")
    for team_name, team_data in stats["teams"].items():
        on_site = [w for w in team_data["workers"] if w["on_site"]]
        print(f"  {team_name} ({team_data.get('type', '')}): "
              f"{team_data['on_site']}/{team_data['total']} 在场")
        for w in on_site:
            print(f"    ● {w['name']} ({w['role']}) - "
                  f"{w['zone'] or '未定位'} | {w['on_site_duration']}")


def test_daily_routine(tracker):
    """测试: 模拟全天作息"""
    print(f"\n{'─'*50}")
    print(f"  测试 6: 模拟全天作息 (10倍速)")
    print(f"{'─'*50}")

    center = tracker.geofence.site_center
    all_phones = tracker.get_all_phones()

    hours = range(7, 19)  # 7:00 - 18:00
    for hour in hours:
        for phone in all_phones:
            if hour < 8:
                # 在家
                lat = center[0] + random.uniform(0.01, 0.02)
                lon = center[1] + random.uniform(0.01, 0.02)
            elif hour < 12:
                # 工作
                lat = center[0] + random.uniform(-0.0008, 0.0008)
                lon = center[1] + random.uniform(-0.0008, 0.0008)
            elif hour < 13:
                # 午休
                lat = center[0] + random.uniform(-0.0003, 0.0003)
                lon = center[1] + random.uniform(-0.0003, 0.0003)
            elif hour < 17:
                # 下午工作
                lat = center[0] + random.uniform(-0.0008, 0.0008)
                lon = center[1] + random.uniform(-0.0008, 0.0008)
            else:
                # 下班
                lat = center[0] + random.uniform(0.01, 0.02)
                lon = center[1] + random.uniform(0.01, 0.02)

            tracker.update_location(phone, lat, lon)

        # 每小时打印一次统计
        stats = tracker.get_team_stats()
        print(f"  {hour:02d}:00 | 在场: {stats['on_site']}/{stats['total_workers']} | "
              f"迟到: {sum(1 for s in tracker.worker_statuses.values() if s.is_late)}")

    # 最终统计
    print(f"\n  最终统计:")
    for phone in all_phones:
        worker = tracker.get_worker_by_phone(phone)
        status = tracker.get_worker_status(worker["id"])
        print(f"    {worker['name']}: "
              f"签到={status.checkin_time or 'N/A'} "
              f"迟到={status.is_late} "
              f"时长={WorkerTracker._format_duration(status.on_site_duration)}")


def run_all_tests(tracker):
    """运行全部测试"""
    print(f"\n{'='*60}")
    print(f"  手机定位端到端测试")
    print(f"{'='*60}")
    print(f"  时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"  工人: {len(tracker.worker_statuses)} 人")
    print(f"  班组: {len(tracker.teams)} 个")

    test_identity_recognition(tracker)
    test_geofence_accuracy(tracker)
    test_location_update(tracker)
    test_danger_zone(tracker)

    # 重置以便统计测试
    tracker.reset_daily()
    test_team_stats(tracker)

    print(f"\n{'='*60}")
    print(f"  全部测试完成")
    print(f"{'='*60}")


def main():
    parser = argparse.ArgumentParser(description="手机定位端到端测试")
    parser.add_argument("--workers-config", type=str,
                        default="configs/workers.json")
    parser.add_argument("--geofence-config", type=str,
                        default="configs/site_geofence.json")
    parser.add_argument("--daily-routine", action="store_true",
                        help="模拟全天作息")
    parser.add_argument("--danger-test", action="store_true",
                        help="仅测试危险区")
    parser.add_argument("--attendance-test", action="store_true",
                        help="仅测试考勤")
    parser.add_argument("--all", action="store_true",
                        help="全部测试")

    args = parser.parse_args()

    tracker = WorkerTracker(
        workers_config_path=args.workers_config,
        geofence_config_path=args.geofence_config,
    )

    if args.daily_routine:
        test_daily_routine(tracker)
    elif args.danger_test:
        test_danger_zone(tracker)
    elif args.attendance_test:
        test_location_update(tracker)
    else:
        run_all_tests(tracker)


if __name__ == "__main__":
    main()