#!/usr/bin/env python3
"""
智慧工地 - 飞书告警通知模块
通过 Lark IM 将告警消息推送给相关人员:
  当事人 -> 班组长 -> 安全员 -> 项目经理 (逐级通知)

P5 升级:
  - send_alarm_card(): 富交互卡片 (图片缩略图 + 3 个按钮: 已处理 / 转派班组长 / 15min后再提醒)
  - send_daily_brief_card(): 每日早会简报卡片
  - send_review_summary_card(): 自动训练流水线审核汇总卡片
  - upload_image(): 上传 jpg 到飞书 IM, 拿 image_key (失败时优雅降级)
"""

import json
import os
import subprocess
import time
import threading
import logging
from pathlib import Path
from datetime import datetime
from collections import defaultdict


logger = logging.getLogger(__name__)


# 飞书卡片模板颜色
_LEVEL_COLOR = {"critical": "red", "high": "orange", "medium": "yellow",
                "low": "blue", "info": "blue"}
_LEVEL_EMOJI = {"critical": "🔴", "high": "🟠", "medium": "🟡",
                "low": "🟢", "info": "ℹ️"}
_ALARM_TYPE_LABEL = {
    "no_helmet": "未戴安全帽",
    "no_vest": "未穿反光衣",
    "intrusion": "危险区域入侵",
    "zone_intrusion": "危险区域入侵",
    "helmet_compliance_low": "安全帽合规率过低",
    "vest_compliance_low": "反光衣合规率过低",
    "geofence_intrusion": "电子栅栏-进入危险区",
    "geofence_leave": "电子栅栏-人员离场",
    "geofence_late": "电子栅栏-迟到",
    "worker_abnormal": "工人异常",
    "vehicle": "车辆异常",
    "leaving_site": "人员离场",
}


class LarkNotifier:
    """飞书消息通知器"""

    def __init__(self, personnel_config_path="configs/personnel.json",
                 storage=None):
        self.config = self._load_config(personnel_config_path)
        self.roles = self.config.get("roles", {})
        self.rules = self.config.get("alarm_rules", {})
        self.notify_cfg = self.config.get("notification", {})
        # P5: 可选注入 storage, 让 send_alarm_card 自动落库 card_message_id
        self.storage = storage

        # 冷却与限流
        self.cooldown = self.notify_cfg.get("cooldown_seconds", 300)
        self.max_per_hour = self.notify_cfg.get("max_per_hour", 20)
        self._last_notify = defaultdict(float)  # key -> timestamp
        self._hourly_count = 0
        self._hour_start = time.time()
        # P5: 卡片回调地址 (写在卡片按钮的 value 里, 给 lark_callback 用)
        self.callback_base_url = self.notify_cfg.get(
            "callback_base_url", "")  # 例: http://1.2.3.4:5001

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

    def _send_lark_message(self, open_id, name, title, message, level="medium",
                           use_card=False):
        """通过飞书发送消息"""
        level_emoji = {"critical": "🔴", "high": "🟠", "medium": "🟡", "low": "🟢"}
        emoji = level_emoji.get(level, "🟡")

        if use_card and self.notify_cfg.get("channels", {}).get("lark_im", {}).get("message_type") == "interactive":
            return self._send_card_message(open_id, name, title, message, level, emoji)

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
            print(f"\n  === 飞书消息模拟 ===\n  "
                  f"收件人: {name} ({open_id})\n{full_text}\n  "
                  f"====================\n")
            return True

    def _send_card_message(self, open_id, name, title, message, level, emoji):
        """发送飞书卡片消息 (交互式)"""
        level_colors = {
            "critical": "red",
            "high": "orange",
            "medium": "yellow",
            "low": "blue",
        }
        color = level_colors.get(level, "blue")

        # 构建卡片 JSON
        card = {
            "config": {"wide_screen_mode": True},
            "header": {
                "title": {"tag": "plain_text", "content": f"{emoji} {title}"},
                "template": color,
            },
            "elements": [
                {
                    "tag": "markdown",
                    "content": message.replace("\n", "\\n"),
                },
                {
                    "tag": "hr",
                },
                {
                    "tag": "note",
                    "elements": [
                        {
                            "tag": "plain_text",
                            "content": f"智慧工地安全监控系统 | {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}",
                        }
                    ],
                },
            ],
        }

        card_json = json.dumps(card, ensure_ascii=False)

        cmd = [
            "lark-cli", "im", "+messages-send",
            "--user-id", open_id,
            "--card", card_json,
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
                # 卡片发送失败, 降级为文本消息
                print(f"  [Notify] 卡片发送失败, 降级为文本: {result.stderr.strip()[:50]}")
                return self._send_lark_message(open_id, name, title, message, level, use_card=False)
        except subprocess.TimeoutExpired:
            return False
        except FileNotFoundError:
            print(f"\n  === 飞书卡片消息模拟 ===\n  "
                  f"收件人: {name} ({open_id})\n"
                  f"标题: {emoji} {title}\n{message}\n  "
                  f"====================\n")
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
    # P5: 飞书交互卡片 — 告警卡片 / 每日简报 / 审核汇总
    # ============================================================
    def upload_image(self, image_path: str) -> str:
        """上传图片到飞书 IM, 返回 image_key.
        失败时返回空字符串 (调用方应当优雅降级, 不带图).
        依赖: lark-cli im +images-upload (如该子命令不存在, 自动返回空).
        """
        if not image_path or not Path(image_path).exists():
            return ""
        cmd = ["lark-cli", "im", "+images-upload",
               "--image-type", "message",
               "--path", str(image_path)]
        try:
            r = subprocess.run(cmd, capture_output=True, text=True,
                               timeout=20,
                               env={**os.environ, "LARK_CLI_NO_COLOR": "1"})
            if r.returncode != 0:
                logger.debug("upload_image 失败: %s", r.stderr.strip()[:200])
                return ""
            # lark-cli 一般会打印 JSON 或 image_key 字符串; 兼容两种
            out = r.stdout.strip()
            try:
                obj = json.loads(out)
                # 常见字段: image_key
                return obj.get("image_key") or obj.get("ImageKey") or ""
            except Exception:
                # 纯字符串形式
                if out.startswith("img_"):
                    return out
                # 兜底: 最后一行非空内容
                lines = [l for l in out.splitlines() if l.strip()]
                return lines[-1] if lines else ""
        except (subprocess.TimeoutExpired, FileNotFoundError) as e:
            logger.debug("upload_image 异常: %s", e)
            return ""

    def _build_alarm_card(self, *, alarm_id: int, alarm_type: str,
                          level: str, camera_id: str, message: str,
                          created_at: str = None, snapshot_path: str = None,
                          image_key: str = None,
                          ack_status: str = "pending",
                          zone_name: str = None) -> dict:
        """构造告警交互卡片 JSON (飞书 IM interactive card v1)

        - 3 个按钮:
            已处理           → value={action:ack, alarm_id, status:acknowledged}
            转派班组长       → value={action:forward, alarm_id, to_role:team_leader}
            15 分钟后再提醒  → value={action:snooze, alarm_id, minutes:15}
        - ack_status != 'pending' 时, 不再显示按钮, 显示已处理状态
        """
        emoji = _LEVEL_EMOJI.get(level, "🟡")
        color = _LEVEL_COLOR.get(level, "blue")
        type_label = _ALARM_TYPE_LABEL.get(alarm_type, alarm_type)
        created_at = created_at or datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        # Markdown 主体
        md_lines = [
            f"**{emoji} {type_label}**",
            "",
            f"- **告警ID**: `#{alarm_id}`",
            f"- **级别**: {level}",
            f"- **位置**: 摄像头 `{camera_id or 'N/A'}`"
            + (f" / 区域 `{zone_name}`" if zone_name else ""),
            f"- **时间**: {created_at}",
            "",
            "**详情**:",
            f"```\n{message}\n```",
        ]
        elements = [{"tag": "markdown",
                     "content": "\n".join(md_lines)}]
        # 图片 (如果有 image_key)
        if image_key:
            elements.append({
                "tag": "img",
                "img_key": image_key,
                "alt": {"tag": "plain_text",
                        "content": f"告警截图 #{alarm_id}"},
            })
        elif snapshot_path:
            # 没传 image_key 但有路径 → 在 markdown 里给个本地路径提示
            elements.append({"tag": "markdown",
                             "content": f"_📷 截图: `{snapshot_path}`_"})
        elements.append({"tag": "hr"})

        # 按钮区 (已处理则替换为状态徽章)
        if ack_status == "pending":
            actions_block = {
                "tag": "action",
                "actions": [
                    {"tag": "button",
                     "text": {"tag": "plain_text", "content": "✅ 已处理"},
                     "type": "primary",
                     "value": {"action": "ack", "alarm_id": alarm_id,
                               "status": "acknowledged"}},
                    {"tag": "button",
                     "text": {"tag": "plain_text", "content": "📢 转派班组长"},
                     "type": "default",
                     "value": {"action": "forward", "alarm_id": alarm_id,
                               "to_role": "team_leader"}},
                    {"tag": "button",
                     "text": {"tag": "plain_text", "content": "⏰ 15min后再提醒"},
                     "type": "default",
                     "value": {"action": "snooze", "alarm_id": alarm_id,
                               "minutes": 15}},
                ],
            }
        elif ack_status == "snoozed":
            actions_block = {"tag": "markdown",
                             "content": f"⏰ **已设置 15 分钟后再次提醒** (操作人请见卡片回调日志)"}
        elif ack_status == "acknowledged":
            actions_block = {"tag": "markdown",
                             "content": "✅ **本告警已被标记为已处理**"}
        elif ack_status == "dismissed":
            actions_block = {"tag": "markdown",
                             "content": "🙅 **本告警已被忽略**"}
        else:
            actions_block = {"tag": "markdown",
                             "content": f"状态: `{ack_status}`"}
        elements.append(actions_block)
        elements.append({
            "tag": "note",
            "elements": [{"tag": "plain_text",
                          "content": f"智慧工地安全监控系统 | 卡片ID #{alarm_id}"}],
        })

        return {
            "config": {"wide_screen_mode": True},
            "header": {
                "title": {"tag": "plain_text",
                          "content": f"{emoji} 安全告警 · {type_label}"},
                "template": color,
            },
            "elements": elements,
        }

    def send_alarm_card(self, *, alarm_id: int, alarm_type: str,
                        level: str = "high", camera_id: str = "",
                        message: str = "", created_at: str = None,
                        snapshot_path: str = None,
                        zone_name: str = None,
                        notify_roles: list = None) -> dict:
        """发告警交互卡片给指定角色 (默认按 alarm_rules 里的 notify_roles).

        返回: {
            "ok": bool,
            "image_key": str,        # 上传后的图片 key, 没有就空
            "sent_to": [...],        # 已发送给谁
            "errors": [...],
        }
        """
        # 1) 上传图片 (失败优雅降级)
        image_key = ""
        if snapshot_path:
            image_key = self.upload_image(snapshot_path) or ""

        # 2) 构造卡片
        card = self._build_alarm_card(
            alarm_id=alarm_id, alarm_type=alarm_type, level=level,
            camera_id=camera_id, message=message, created_at=created_at,
            snapshot_path=snapshot_path, image_key=image_key,
            ack_status="pending", zone_name=zone_name,
        )
        card_json = json.dumps(card, ensure_ascii=False)

        # 3) 决定收件人
        if notify_roles is None:
            rule = self.rules.get(alarm_type, {})
            notify_roles = rule.get("notify_roles", ["safety_officer",
                                                     "team_leader"])
        targets = self._collect_targets(notify_roles)

        sent, errors = [], []
        for t in targets:
            ok, msg_id = self._send_card_raw(t["open_id"], card_json)
            if ok:
                sent.append({"role": t["role"], "name": t["name"],
                             "open_id": t["open_id"],
                             "card_message_id": msg_id})
            else:
                errors.append({"target": t, "error": "send_failed"})

        # 4) 把第一条 card_message_id 写回 storage.alarm.card_message_id
        if self.storage and sent and sent[0].get("card_message_id"):
            try:
                self.storage.update_alarm_card_message_id(
                    alarm_id, sent[0]["card_message_id"])
            except Exception as e:
                logger.debug("update_alarm_card_message_id 失败: %s", e)

        return {"ok": bool(sent), "image_key": image_key,
                "sent_to": sent, "errors": errors}

    def _collect_targets(self, role_names: list) -> list:
        """从 roles 配置中按 role 名收集 {role,name,open_id}"""
        out = []
        for r in role_names:
            role = self.roles.get(r, {})
            for m in role.get("members", []):
                oid = m.get("open_id", "")
                if oid.startswith("ou_"):
                    out.append({"role": r, "name": m.get("name", ""),
                                "open_id": oid})
        return out

    def _send_card_raw(self, open_id: str, card_json: str) -> tuple:
        """通过 lark-cli 发卡片, 返回 (ok, card_message_id).
        环境变量 LARK_CLI_MOCK=1 时强制返回模拟 message_id (用于测试/无飞书环境).
        """
        if os.environ.get("LARK_CLI_MOCK") == "1":
            return True, f"mock_msg_{int(time.time()*1000)}_{open_id[-4:]}"
        cmd = ["lark-cli", "im", "+messages-send",
               "--user-id", open_id,
               "--card", card_json,
               "--as", "bot"]
        try:
            r = subprocess.run(cmd, capture_output=True, text=True,
                               timeout=20,
                               env={**os.environ, "LARK_CLI_NO_COLOR": "1"})
            if r.returncode == 0:
                # 尝试从输出里抽 message_id
                msg_id = ""
                try:
                    obj = json.loads(r.stdout.strip())
                    msg_id = (obj.get("message_id") or obj.get("data", {})
                              .get("message_id") or "")
                except Exception:
                    pass
                return True, msg_id
            logger.debug("send_card 失败: %s", r.stderr.strip()[:200])
            return False, ""
        except (subprocess.TimeoutExpired, FileNotFoundError) as e:
            # lark-cli 没装 → 模拟 (返回假 message_id)
            logger.info("lark-cli 不可用, 模拟发送: %s", e)
            return True, f"mock_msg_{int(time.time()*1000)}"

    # ---------- 每日早会简报卡片 ----------
    def _build_daily_brief_card(self, *, date_str: str,
                                window_start: str, window_end: str,
                                helmet_rate: float, vest_rate: float,
                                total_persons: int, no_helmets: int,
                                no_vests: int, intrusions: int,
                                alarms_total: int, alarms_by_type: dict,
                                alarms_by_level: dict,
                                attendance: dict = None,
                                new_photos: int = 0, new_trainings: int = 0,
                                best_map50: float = None) -> dict:
        """构造每日早会简报卡片"""
        # 主体 markdown
        md = [
            f"**📊 {date_str} 早会安全简报**",
            f"_统计窗口: {window_start} → {window_end}_",
            "",
            "## 🦺 安全装备合规率",
            f"- 安全帽: **{self._fmt_pct(helmet_rate)}**"
            + (self._rate_emoji(helmet_rate, 0.95, 0.80)),
            f"- 反光衣: **{self._fmt_pct(vest_rate)}**"
            + (self._rate_emoji(vest_rate, 0.95, 0.80)),
            f"- 检测总人次: {total_persons} · 未戴帽 {no_helmets} · 未穿衣 {no_vests}",
            "",
            "## 🚨 告警分布",
            f"- 告警总数: **{alarms_total}** "
            f"(🔴 {alarms_by_level.get('critical',0)} / "
            f"🟠 {alarms_by_level.get('high',0)} / "
            f"🟡 {alarms_by_level.get('medium',0)} / "
            f"🟢 {alarms_by_level.get('low',0)})",
            f"- 危险区域入侵: **{intrusions}** 次",
        ]
        # Top 3 告警类型
        top3 = sorted(alarms_by_type.items(), key=lambda x: -x[1])[:3]
        if top3:
            md.append("- 告警 Top3:")
            for tp, cnt in top3:
                md.append(f"  - {_ALARM_TYPE_LABEL.get(tp, tp)}: {cnt}")

        # 班组考勤
        if attendance:
            md.append("")
            md.append("## 👷 班组出勤")
            md.append(f"- 应到: **{attendance.get('expected_count','-')}**  "
                      f"实到: **{attendance.get('present_count','-')}**  "
                      f"出勤率: **{self._fmt_pct(attendance.get('attendance_rate'))}**")
            teams = attendance.get("teams") or {}
            if teams:
                md.append("- 各班组:")
                for name, info in teams.items():
                    md.append(f"  - {name}: {info.get('present',0)}/{info.get('expected',0)} "
                              f"({self._fmt_pct(info.get('rate'))})")

        # 训练流水线
        if new_photos or new_trainings:
            md.append("")
            md.append("## 🤖 模型自训练")
            md.append(f"- 新增训练照片: {new_photos}")
            md.append(f"- 训练 run 数: {new_trainings}"
                      + (f"  最佳 mAP50: **{best_map50}**" if best_map50 else ""))

        # 看板链接
        if self.callback_base_url:
            md.append("")
            md.append(f"[→ 打开 Dashboard 看板]({self.callback_base_url}/)")

        elements = [{"tag": "markdown", "content": "\n".join(md)}]
        elements.append({
            "tag": "note",
            "elements": [{"tag": "plain_text",
                          "content": "智慧工地安全监控系统 · 自动生成 · 每日 08:00"}],
        })
        return {
            "config": {"wide_screen_mode": True},
            "header": {
                "title": {"tag": "plain_text",
                          "content": f"📊 每日安全简报 · {date_str}"},
                "template": "blue",
            },
            "elements": elements,
        }

    def send_daily_brief_card(self, *, date_str: str, window_start: str,
                              window_end: str, helmet_rate: float,
                              vest_rate: float, total_persons: int,
                              no_helmets: int, no_vests: int, intrusions: int,
                              alarms_total: int, alarms_by_type: dict,
                              alarms_by_level: dict,
                              attendance: dict = None,
                              new_photos: int = 0, new_trainings: int = 0,
                              best_map50: float = None,
                              notify_roles: list = None) -> dict:
        """发每日早会简报卡片给项目经理 + 安全员 (默认)"""
        card = self._build_daily_brief_card(
            date_str=date_str, window_start=window_start, window_end=window_end,
            helmet_rate=helmet_rate, vest_rate=vest_rate,
            total_persons=total_persons, no_helmets=no_helmets,
            no_vests=no_vests, intrusions=intrusions,
            alarms_total=alarms_total, alarms_by_type=alarms_by_type,
            alarms_by_level=alarms_by_level, attendance=attendance,
            new_photos=new_photos, new_trainings=new_trainings,
            best_map50=best_map50,
        )
        card_json = json.dumps(card, ensure_ascii=False)
        if notify_roles is None:
            notify_roles = ["project_manager", "safety_officer"]
        targets = self._collect_targets(notify_roles)
        sent, errors = [], []
        for t in targets:
            ok, msg_id = self._send_card_raw(t["open_id"], card_json)
            if ok:
                sent.append({"role": t["role"], "name": t["name"],
                             "card_message_id": msg_id})
            else:
                errors.append({"target": t, "error": "send_failed"})
        return {"ok": bool(sent), "sent_to": sent, "errors": errors}

    # ---------- 审核汇总卡片 ----------
    def _build_review_summary_card(self, *, pending_count: int,
                                   sample_photos: list,
                                   threshold: int = 20,
                                   dashboard_url: str = None) -> dict:
        """构造审核汇总卡片.
        sample_photos: [{id, filename, avg_confidence, low_conf_ratio,
                         labels_count, cls_distribution:{...}}]
        """
        md = [
            f"**🟡 待人工审核照片已达 {pending_count} 张** (阈值 {threshold})",
            "",
            "AI 伪标签置信度不够高, 需要人工确认后才能进入下一轮自动训练.",
            "",
        ]
        if sample_photos:
            md.append("## 📷 待审样例 (前 5 张)")
            for i, p in enumerate(sample_photos[:5], 1):
                cls_dist = p.get("cls_distribution") or {}
                cls_str = " ".join(f"`{k}`×{v}" for k, v in cls_dist.items())
                md.append(
                    f"{i}. **#{p.get('id')}** `{p.get('filename','')[:30]}`  "
                    f"框数 {p.get('labels_count',0)} · 平均置信度 "
                    f"{p.get('avg_confidence',0):.2f} · "
                    f"低质框 {int((p.get('low_conf_ratio') or 0)*100)}%  "
                    f"{cls_str}"
                )
        if dashboard_url:
            md.append("")
            md.append(f"[→ 一键审核所有照片]({dashboard_url}/?tab=photos&status=need_review)")
        elements = [{"tag": "markdown", "content": "\n".join(md)}]
        elements.append({
            "tag": "action",
            "actions": [
                {"tag": "button",
                 "text": {"tag": "plain_text",
                          "content": "✅ 一键全部通过 (高质量)"},
                 "type": "primary",
                 "value": {"action": "bulk_approve",
                           "filter": "labeled"}},
                {"tag": "button",
                 "text": {"tag": "plain_text",
                          "content": "📂 打开审核页"},
                 "type": "default",
                 "value": {"action": "open_review"}},
            ],
        })
        elements.append({
            "tag": "note",
            "elements": [{"tag": "plain_text",
                          "content": "智慧工地 · 自动训练流水线 · 待审提醒"}],
        })
        return {
            "config": {"wide_screen_mode": True},
            "header": {
                "title": {"tag": "plain_text",
                          "content": f"🟡 待审核照片 {pending_count} 张"},
                "template": "yellow",
            },
            "elements": elements,
        }

    def send_review_summary_card(self, *, pending_count: int,
                                 sample_photos: list = None,
                                 threshold: int = 20,
                                 notify_roles: list = None) -> dict:
        """发审核汇总卡片给质检/安全员 (默认)"""
        dashboard_url = self.callback_base_url or ""
        card = self._build_review_summary_card(
            pending_count=pending_count, sample_photos=sample_photos or [],
            threshold=threshold, dashboard_url=dashboard_url,
        )
        card_json = json.dumps(card, ensure_ascii=False)
        if notify_roles is None:
            notify_roles = ["safety_officer", "project_manager"]
        targets = self._collect_targets(notify_roles)
        sent, errors = [], []
        for t in targets:
            ok, msg_id = self._send_card_raw(t["open_id"], card_json)
            if ok:
                sent.append({"role": t["role"], "name": t["name"],
                             "card_message_id": msg_id})
            else:
                errors.append({"target": t, "error": "send_failed"})
        return {"ok": bool(sent), "sent_to": sent, "errors": errors}

    # ---------- 工具 ----------
    @staticmethod
    def _fmt_pct(v):
        if v is None: return "-"
        if 0 <= v <= 1: return f"{v*100:.1f}%"
        return f"{v:.1f}%"

    @staticmethod
    def _rate_emoji(rate, ok_threshold, warn_threshold):
        if rate is None: return ""
        if rate >= ok_threshold: return " ✅"
        if rate >= warn_threshold: return " ⚠️"
        return " 🔴"


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