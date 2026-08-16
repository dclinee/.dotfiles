#!/usr/bin/env python3
"""
飞书通知端到端验证脚本
模拟所有告警类型, 逐一验证通知通道是否正常

用法:
  # 验证全部告警类型
  python scripts/notify_test.py

  # 验证特定类型
  python scripts/notify_test.py --type intrusion

  # 发送每日安全报告
  python scripts/notify_test.py --daily-report

  # 验证限流机制
  python scripts/notify_test.py --rate-limit-test
"""

import argparse
import json
import os
import sys
import time
from pathlib import Path
from datetime import datetime

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from utils.notify import LarkNotifier, get_notifier


# ============================================================
# 测试场景
# ============================================================

TEST_SCENARIOS = {
    "no_helmet": {
        "type": "no_helmet",
        "kwargs": {"count": 3},
        "description": "3人未佩戴安全帽",
        "expected": "飞书消息: 安全违规 - 未佩戴安全帽",
    },
    "no_vest": {
        "type": "no_vest",
        "kwargs": {"count": 5},
        "description": "5人未穿反光衣",
        "expected": "飞书消息: 安全违规 - 未穿反光衣",
    },
    "intrusion": {
        "type": "intrusion",
        "kwargs": {"zone_name": "塔吊下方危险区"},
        "description": "人员闯入塔吊下方危险区",
        "expected": "飞书消息: 紧急 - 危险区域入侵",
    },
    "helmet_compliance_low": {
        "type": "helmet_compliance_low",
        "kwargs": {"rate": 65.5},
        "description": "安全帽佩戴率仅65.5%",
        "expected": "飞书消息: 统计预警 - 安全帽佩戴率过低",
    },
    "vest_compliance_low": {
        "type": "vest_compliance_low",
        "kwargs": {"rate": 58.3},
        "description": "反光衣穿戴率仅58.3%",
        "expected": "飞书消息: 统计预警 - 反光衣穿戴率过低",
    },
}


def test_single(notifier, scenario_name, camera_id="test_cam"):
    """测试单个告警类型"""
    scenario = TEST_SCENARIOS.get(scenario_name)
    if not scenario:
        print(f"  未知场景: {scenario_name}")
        return False

    print(f"\n  场景: {scenario['description']}")
    print(f"  预期: {scenario['expected']}")

    result = notifier.send_alarm(
        scenario["type"],
        camera_id=camera_id,
        **scenario["kwargs"],
    )

    status = "通过" if result else "失败 (可能无有效通知对象)"
    print(f"  结果: {status}")
    return result


def test_all(notifier, camera_id="test_cam", interval=3):
    """测试全部告警类型"""
    print(f"\n{'='*60}")
    print(f"  飞书通知端到端验证")
    print(f"{'='*60}")
    print(f"  时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"  摄像头: {camera_id}")
    print(f"  测试场景: {len(TEST_SCENARIOS)} 个")

    results = {}
    for name in TEST_SCENARIOS:
        results[name] = test_single(notifier, name, camera_id)
        if interval > 0:
            time.sleep(interval)

    # 汇总
    print(f"\n{'='*60}")
    print(f"  验证结果汇总")
    print(f"{'='*60}")
    passed = sum(1 for v in results.values() if v)
    total = len(results)
    for name, ok in results.items():
        status = "通过" if ok else "失败"
        print(f"  [{status}] {TEST_SCENARIOS[name]['description']}")
    print(f"\n  通过: {passed}/{total}")
    print(f"{'='*60}")


def test_rate_limit(notifier):
    """测试限流机制"""
    print(f"\n{'='*60}")
    print(f"  限流机制测试")
    print(f"{'='*60}")
    print(f"  连续发送 10 条相同告警, 验证冷却和限流")

    count = 0
    for i in range(10):
        result = notifier.send_alarm("no_helmet", camera_id="rate_test", count=1)
        if result:
            count += 1
            print(f"    [{i+1}] 已发送")
        else:
            print(f"    [{i+1}] 被限制 (冷却中)")
        time.sleep(0.5)

    print(f"\n  实际发送: {count}/10 (预期: 出现冷却拦截)")
    print(f"{'='*60}")


def test_daily_report(notifier):
    """测试每日安全报告"""
    print(f"\n{'='*60}")
    print(f"  每日安全报告测试")
    print(f"{'='*60}")

    # 模拟统计数据
    stats = {
        "total_persons": 156,
        "max_persons": 45,
        "total_helmets": 132,
        "total_no_helmets": 24,
        "total_vests": 128,
        "total_no_vests": 28,
        "helmet_compliance": 84.6,
        "vest_compliance": 82.1,
        "total_intrusions": 3,
        "total_violations": 52,
    }

    notifier.send_daily_report(stats, camera_id="daily_report")
    print(f"  日报已发送 (如无有效通知对象则跳过)")

    # 生成文本报告
    print(f"\n  报告内容:")
    print(f"  {'─'*50}")
    print(f"  日期: {datetime.now().strftime('%Y-%m-%d')}")
    print(f"  检测总人数: {stats['total_persons']}")
    print(f"  最大同时在场: {stats['max_persons']}")
    print(f"  安全帽佩戴率: {stats['helmet_compliance']}%")
    print(f"  反光衣穿戴率: {stats['vest_compliance']}%")
    print(f"  违规次数: {stats['total_violations']}")
    print(f"  入侵事件: {stats['total_intrusions']}")
    print(f"  {'─'*50}")


def test_integration_with_video(notifier):
    """
    模拟 video_verify.py 集成测试
    模拟视频检测过程中触发的各种告警
    """
    print(f"\n{'='*60}")
    print(f"  video_verify 集成测试")
    print(f"{'='*60}")

    # 模拟视频检测过程中的事件序列
    events = [
        # (时间, 事件类型, 参数)
        (0, "no_helmet", {"count": 1}),
        (2, "no_vest", {"count": 2}),
        (5, "intrusion", {"zone_name": "塔吊下方"}),
        (10, "no_helmet", {"count": 3}),     # 应被冷却拦截
        (30, "no_helmet", {"count": 1}),
        (45, "intrusion", {"zone_name": "基坑边缘"}),
        (60, "helmet_compliance_low", {"rate": 72.0}),
    ]

    print(f"  模拟 {len(events)} 个事件序列...")
    sent = 0
    skipped = 0

    for t, etype, kwargs in events:
        result = notifier.send_alarm(etype, camera_id="integration_test", **kwargs)
        if result:
            sent += 1
            print(f"    [{t:3d}s] {etype}: 已发送")
        else:
            skipped += 1
            print(f"    [{t:3d}s] {etype}: 跳过 (冷却/限流)")

    print(f"\n  发送: {sent} | 拦截: {skipped}")
    print(f"  预期: 存在冷却拦截 (5s内重复告警被拦截)")
    print(f"{'='*60}")


def main():
    parser = argparse.ArgumentParser(
        description="飞书通知端到端验证",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
示例:
  # 验证全部告警
  python scripts/notify_test.py

  # 验证特定类型
  python scripts/notify_test.py --type intrusion

  # 每日报告
  python scripts/notify_test.py --daily-report

  # 限流测试
  python scripts/notify_test.py --rate-limit-test

  # 集成测试
  python scripts/notify_test.py --integration-test
        """,
    )

    parser.add_argument("--config", type=str, default="configs/personnel.json",
                        help="人员配置文件")
    parser.add_argument("--type", type=str, default=None,
                        choices=list(TEST_SCENARIOS.keys()),
                        help="测试特定告警类型")
    parser.add_argument("--camera-id", type=str, default="test_cam",
                        help="摄像头标识")
    parser.add_argument("--all", action="store_true",
                        help="测试全部告警类型")
    parser.add_argument("--daily-report", action="store_true",
                        help="测试每日安全报告")
    parser.add_argument("--rate-limit-test", action="store_true",
                        help="测试限流机制")
    parser.add_argument("--integration-test", action="store_true",
                        help="模拟 video_verify 集成测试")
    parser.add_argument("--interval", type=int, default=3,
                        help="测试间隔 (秒)")

    args = parser.parse_args()

    notifier = LarkNotifier(args.config)

    # 打印当前配置
    print(f"通知配置摘要:")
    for role_name, role in notifier.roles.items():
        members = role.get("members", [])
        valid = [m for m in members if m.get("open_id", "").startswith("ou_")]
        print(f"  {role['name']}: {len(valid)}/{len(members)} 已配置 open_id")

    if args.type:
        test_single(notifier, args.type, args.camera_id)
    elif args.daily_report:
        test_daily_report(notifier)
    elif args.rate_limit_test:
        test_rate_limit(notifier)
    elif args.integration_test:
        test_integration_with_video(notifier)
    elif args.all:
        test_all(notifier, args.camera_id, args.interval)
    else:
        # 默认: 全部测试
        test_all(notifier, args.camera_id, args.interval)


if __name__ == "__main__":
    main()