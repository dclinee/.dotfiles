#!/usr/bin/env python3
"""
智慧工地 - 飞书告警通知模块
通过 Lark IM 将告警消息推送给相关人员:
  当事人 -> 班组长 -> 安全员 -> 项目经理 (逐级通知)
"""

import json
import os
import subprocess
import time
import threading
from pathlib import Path
from datetime import datetime
from collections import defaultdict


class LarkNotifier:
    """飞书消息通知器"""

    def __init__(self, personnel_config_path="configs/personnel.json"):
        self.config = self._load_config(personnel_config_path)
        self.roles = self.config.get("roles", {})
        self.rules = self.config.get("alarm_rules", {})
        self.notify_cfg = self.config.get("notification", {})

        # 冷却与限流
        self.cooldown = self.notify_cfg.get("cooldown_seconds", 300)
        self.max_per_hour = self.notify_cfg.get("max_per_hour", 20)
        self._last_notify = defaultdict(float)  # key -> timestamp
        self._hourly_count = 0
        self._hour_start = time.time()

    def _load_config(self, path):
        path = Path(path)
        if not path.exists():
            raise FileNotFoundError(f"人员配置文件不存在: {path}")
        with open(path, "r") as f:
            return json.load(f)

    def _check_rate_limit(self, key):
        """检查冷却和限流"""
        now = time.time()

        # 冷却检查
        if key in self._last_notify:
            elapsed = now - self._last_notify[key]
            if elapsed < self.cooldown:
                return False, f"冷却中 ({elapsed:.0f}s / {self.cooldown}s)"

        # 小时限流
        if now - self._hour_start > 3600:
            self._hourly_count = 0
            self._hour_start = now

        if self._hourly_count >= self.max_per_hour:
            return False, f"超过每小时限流 ({self.max_per_hour})"

        self._hourly_count += 1
        self._last_notify[key] = now
        return True, "ok"

    def _get_notify_targets(self, alarm_type, camera_id=None):
        """根据告警类型获取通知对象列表"""
        rule = self.rules.get(alarm_type, {})
        notify_roles = rule.get("notify_roles", [])

        targets = []
        for role_name in notify_roles:
            role = self.roles.get(role_name, {})
            members = role.get("members", [])

            if role_name == "worker":
                # 当事人 — 需要通过人脸识别确定，这里留作扩展
                # 可在此处接入人脸识别系统匹配具体人员
                continue

            for member in members:
                if "open_id" in member and member["open_id"].startswith("ou_"):
                    targets.append({
                        "role": role_name,
                        "role_name": role.get("name", role_name),
                        "name": member.get("name", ""),
                        "open_id": member["open_id"],
                        "team": member.get("team", ""),
                    })

        return targets

    def _format_message(self, alarm_type, **kwargs):
        """格式化告警消息"""
        rule = self.rules.get(alarm_type, {})
        template = rule.get("template", "[{alarm_type}] {time}")

        kwargs.setdefault("time", datetime.now().strftime("%Y-%m-%d %H:%M:%S"))
        kwargs.setdefault("camera_id", "N/A")

        try:
            return template.format(**kwargs)
        except KeyError as e:
            return f"{template}\n(缺少参数: {e})"

    def send_alarm(self, alarm_type, camera_id=None, **kwargs):
        """
        发送告警通知

        Args:
            alarm_type: 告警类型 (no_helmet / no_vest / intrusion / helmet_compliance_low / vest_compliance_low)
            camera_id: 摄像头编号
            **kwargs: 消息模板变量 (count, zone_name, rate, time 等)
        """
        rule = self.rules.get(alarm_type)
        if not rule:
            print(f"[Notify] 未知告警类型: {alarm_type}")
            return False

        # 冷却检查
        cooldown_key = f"{alarm_type}:{camera_id or 'default'}"
        ok, reason = self._check_rate_limit(cooldown_key)
        if not ok:
            print(f"[Notify] 跳过 ({reason}): {alarm_type}")
            return False

        alarm_level = rule.get("level", "medium")
        title = rule.get("title", alarm_type)

        # 获取通知对象
        targets = self._get_notify_targets(alarm_type, camera_id)

        if not targets:
            print(f"[Notify] 无有效通知对象: {alarm_type}")
            return False

        # 格式化消息
        message = self._format_message(alarm_type, camera_id=camera_id, **kwargs)

        # 发送通知
        success_count = 0
        for target in targets:
            ok = self._send_lark_message(
                open_id=target["open_id"],
                name=target["name"],
                title=title,
                message=message,
                level=alarm_level,
            )
            if ok:
                success_count += 1
                print(f"  [Notify] 已发送给 {target['role_name']} {target['name']}")

        # 紧急级别 + 启用加急时，发送加急
        if alarm_level == "critical" and self.notify_cfg.get("channels", {}).get("lark_urgent", {}).get("enabled"):
            self._send_urgent(message)

        return success_count > 0

    def _send_lark_message(self, open_id, name, title, message, level="medium"):
        """通过飞书发送消息"""
        level_emoji = {"critical": "🔴", "high": "🟠", "medium": "🟡", "low": "🟢"}
        emoji = level_emoji.get(level, "🟡")

        # 构建消息内容
        full_text = f"{emoji} **{title}**\n\n{message}"

        # 使用 lark-cli 发送消息
        cmd = [
            "lark-cli", "im", "+messages-send",
            "--user-id", open_id,
            "--text", full_text,
            "--as", "bot",
        ]

        try:
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                timeout=15,
                env={**os.environ, "LARK_CLI_NO_COLOR": "1"},
            )
            if result.returncode == 0:
                return True
            else:
                print(f"  [Notify] 发送失败 ({name}): {result.stderr.strip()}")
                return False
        except subprocess.TimeoutExpired:
            print(f"  [Notify] 发送超时 ({name})")
            return False
        except FileNotFoundError:
            # lark-cli 未安装，打印消息到控制台模拟
            print(f"\n  === 飞书消息模拟 ===\n  收件人: {name} ({open_id})\n{full_text}\n  ====================\n")
            return True

    def _send_urgent(self, message):
        """发送紧急加急 (预留)"""
        print(f"  [Notify] 紧急加急已触发: {message[:50]}...")

    def send_batch_alarm(self, alarms):
        """
        批量发送告警

        Args:
            alarms: [(alarm_type, camera_id, kwargs), ...]
        """
        for alarm in alarms:
            self.send_alarm(*alarm)

    def send_daily_report(self, stats, camera_id=None):
        """
        发送每日安全报告

        Args:
            stats: 统计数据 dict
        """
        report = (
            f"📊 **智慧工地安全日报**\n\n"
            f"日期: {datetime.now().strftime('%Y-%m-%d')}\n"
            f"监控区域: 摄像头 {camera_id or 'N/A'}\n\n"
            f"—— 人员统计 ——\n"
            f"检测总人数: {stats.get('total_persons', 0)}\n"
            f"最大同时在场: {stats.get('max_persons', 0)}\n\n"
            f"—— 安全装备 ——\n"
            f"安全帽佩戴率: {stats.get('helmet_compliance', 0):.1f}%\n"
            f"反光衣穿戴率: {stats.get('vest_compliance', 0):.1f}%\n\n"
            f"—— 违规记录 ——\n"
            f"未戴安全帽: {stats.get('total_no_helmets', 0)} 次\n"
            f"未穿反光衣: {stats.get('total_no_vests', 0)} 次"
        )

        # 发送给项目经理和安全员
        for role_name in ["project_manager", "safety_officer"]:
            role = self.roles.get(role_name, {})
            for member in role.get("members", []):
                if member.get("open_id", "").startswith("ou_"):
                    self._send_lark_message(
                        open_id=member["open_id"],
                        name=member.get("name", ""),
                        title="安全日报",
                        message=report,
                        level="low",
                    )


# ============================================================
# 便捷函数 - 供外部脚本直接调用
# ============================================================

_default_notifier = None


def get_notifier(config_path="configs/personnel.json"):
    """获取全局通知器实例 (单例)"""
    global _default_notifier
    if _default_notifier is None:
        _default_notifier = LarkNotifier(config_path)
    return _default_notifier


def alarm_no_helmet(count, camera_id=None):
    """未戴安全帽告警"""
    return get_notifier().send_alarm("no_helmet", camera_id, count=count)


def alarm_no_vest(count, camera_id=None):
    """未穿反光衣告警"""
    return get_notifier().send_alarm("no_vest", camera_id, count=count)


def alarm_intrusion(zone_name, camera_id=None):
    """危险区域入侵告警"""
    return get_notifier().send_alarm("intrusion", camera_id, zone_name=zone_name)


def alarm_helmet_compliance(rate, camera_id=None):
    """安全帽佩戴率过低告警"""
    return get_notifier().send_alarm("helmet_compliance_low", camera_id, rate=rate)


def alarm_vest_compliance(rate, camera_id=None):
    """反光衣穿戴率过低告警"""
    return get_notifier().send_alarm("vest_compliance_low", camera_id, rate=rate)


# ============================================================
# 命令行入口 - 测试通知
# ============================================================

if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="智慧工地 - 飞书告警通知测试")
    parser.add_argument("--config", type=str, default="configs/personnel.json",
                        help="人员配置文件")
    parser.add_argument("--test", action="store_true",
                        help="发送测试通知")
    parser.add_argument("--alarm-type", type=str, default="no_helmet",
                        choices=["no_helmet", "no_vest", "intrusion", "helmet_compliance_low", "vest_compliance_low"],
                        help="测试告警类型")
    parser.add_argument("--camera-id", type=str, default="demo_cam",
                        help="摄像头编号")

    args = parser.parse_args()

    notifier = LarkNotifier(args.config)

    if args.test:
        print(f"发送测试告警: {args.alarm_type}")

        test_kwargs = {"count": 3, "zone_name": "塔吊下方", "rate": 65.0}
        notifier.send_alarm(args.alarm_type, camera_id=args.camera_id, **test_kwargs)

        print("测试完成! 请检查飞书消息。")
    else:
        # 打印当前配置摘要
        print("\n人员配置:")
        for role_name, role in notifier.roles.items():
            members = role.get("members", [])
            print(f"  {role['name']} ({role_name}): {len(members)} 人")
            for m in members:
                print(f"    - {m.get('name', '?')} ({m.get('open_id', 'N/A')[:20]}...)")

        print(f"\n告警规则: {len(notifier.rules)} 条")
        for rule_name, rule in notifier.rules.items():
            print(f"  {rule['title']}: 通知 {rule['notify_roles']}")

        print(f"\n通知设置: 冷却 {notifier.cooldown}s, 限流 {notifier.max_per_hour}/h")