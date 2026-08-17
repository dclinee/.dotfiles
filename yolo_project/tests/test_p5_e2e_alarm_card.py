#!/usr/bin/env python3
"""
tests/test_p5_e2e_alarm_card.py — P5 端到端测试

场景: 一次告警 → 发飞书卡片 → 工人点"已处理" → 服务端回写状态 → 返回更新后的卡片

覆盖:
  P5-1: storage.log_alarm / ack_alarm / get_alarm / query_pending_alarms
  P5-2: LarkNotifier.send_alarm_card (含 LARK_CLI_MOCK 模式 + card_message_id 回写)
  P5-3: utils/lark_callback 的 /api/lark/card-action 路由
         - ack   → status=acknowledged + 返回新卡片
         - snooze → status=snoozed + snooze_until 设置
         - forward → 转派给 team_leader

环境: LARK_CLI_MOCK=1 (无飞书也能跑), 内存 SQLite, Flask test_client
"""

import json
import os
import sys
import tempfile
import unittest
from pathlib import Path

# 让 tests/ 能 import 项目根
PROJECT_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(PROJECT_ROOT))

# 必须在 import LarkNotifier 之前设置, 这样 _send_card_raw 走 mock 路径
os.environ["LARK_CLI_MOCK"] = "1"

from utils.storage import SiteDatabase
from utils.notify import LarkNotifier
from utils.lark_callback import create_lark_callback_app, configure


PERSONNEL_PATH = PROJECT_ROOT / "configs" / "personnel.json"


class P5E2EAlarmCardTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        # 用项目自带的 personnel.json (里面有 ou_xxx 开头的 open_id)
        assert PERSONNEL_PATH.exists(), f"personnel.json 不存在: {PERSONNEL_PATH}"

    def setUp(self):
        self.tmpdir = tempfile.mkdtemp()
        self.db_path = os.path.join(self.tmpdir, "site.db")
        self.storage = SiteDatabase(self.db_path)
        self.notifier = LarkNotifier(str(PERSONNEL_PATH), storage=self.storage)
        # 构造 Flask app 并注入依赖
        self.app = create_lark_callback_app(
            storage=self.storage, notifier=self.notifier, verify_token=None,
        )
        self.client = self.app.test_client()

    # ------------------------------------------------------------------
    # 完整端到端: 告警 → 发卡 → 点已处理 → 状态回写
    # ------------------------------------------------------------------
    def test_e2e_alarm_to_ack(self):
        # 1) 模拟检测引擎落一条告警
        alarm_id = self.storage.log_alarm(
            alarm_type="no_helmet",
            message="检测到 2 人未佩戴安全帽 (cam_entrance @ 14:32)",
            camera_id="cam_entrance",
            level="high",
            source="cam_entrance",
            details={"count": 2, "zone_name": "A区施工区"},
            snapshot_path=None,
        )
        self.assertGreater(alarm_id, 0)

        # 2) 调 LarkNotifier.send_alarm_card (走 LARK_CLI_MOCK 模式)
        r = self.notifier.send_alarm_card(
            alarm_id=alarm_id, alarm_type="no_helmet",
            level="high", camera_id="cam_entrance",
            message="检测到 2 人未佩戴安全帽 (cam_entrance @ 14:32)",
            zone_name="A区施工区",
        )
        self.assertTrue(r["ok"], f"发卡失败: {r}")
        # no_helmet 默认 notify_roles = [worker, team_leader, safety_officer]
        # worker 0 人 + team_leader 2 人 + safety_officer 1 人 = 3 人
        self.assertEqual(len(r["sent_to"]), 3,
                         f"应发给 2 team_leader + 1 safety_officer, 实际: {r['sent_to']}")
        # card_message_id 应该回写到了 alarms 表
        alarm = self.storage.get_alarm(alarm_id)
        self.assertTrue(alarm["card_message_id"], "card_message_id 未回写")
        # 初始 ack_status 应为 pending
        self.assertEqual(alarm["ack_status"], "pending")
        self.assertIsNone(alarm["ack_at"])

        # 3) 模拟工人点击"已处理"按钮 — POST /api/lark/card-action
        ack_open_id = "ou_xxxxxxxxxxxxx_002"  # 李安全 (safety_officer)
        payload = {
            "type": "card.action.trigger",
            "open_id": ack_open_id,
            "open_message_id": alarm["card_message_id"],
            "action": {
                "tag": "button",
                "value": {
                    "action": "ack",
                    "alarm_id": alarm_id,
                    "status": "acknowledged",
                },
            },
        }
        resp = self.client.post("/api/lark/card-action",
                                data=json.dumps(payload),
                                content_type="application/json")
        self.assertEqual(resp.status_code, 200, resp.get_data(as_text=True))
        body = resp.get_json()
        self.assertEqual(body["code"], 0, body)
        self.assertIn("card", body, "ack 后应返回更新后的卡片")
        self.assertIn("toast", body, "应返回 toast")
        self.assertIn("李安全", body["toast"]["content"],
                      "toast 中应含操作人姓名")

        # 4) 验证状态回写
        alarm2 = self.storage.get_alarm(alarm_id)
        self.assertEqual(alarm2["ack_status"], "acknowledged",
                         f"ack_status 未回写: {alarm2}")
        self.assertEqual(alarm2["ack_by"], ack_open_id)
        self.assertIsNotNone(alarm2["ack_at"], "ack_at 未设置")

        # 5) 验证 query_pending_alarms 不再返回这条
        pending = self.storage.query_pending_alarms(hours=24,
                                                    ack_status="pending")
        self.assertFalse(any(p["id"] == alarm_id for p in pending),
                         "已 acknowledge 的告警不应出现在 pending 列表")

        # 6) 验证更新后的卡片不再含按钮 (ack_status != pending 时按钮被替换)
        new_card = body["card"]
        elements_json = json.dumps(new_card, ensure_ascii=False)
        # 已处理卡片中不应有 action=ack 的按钮
        self.assertNotIn('"action": "ack"', elements_json,
                         "已处理卡片不应再含 ack 按钮")

    # ------------------------------------------------------------------
    # snooze 流程: 点 "15分钟后再提醒" → 状态 snoozed + snooze_until 设置
    # ------------------------------------------------------------------
    def test_e2e_alarm_to_snooze(self):
        alarm_id = self.storage.log_alarm(
            alarm_type="intrusion", level="critical",
            camera_id="cam_zone_a",
            message="人员闯入 A 区危险区域",
        )
        # 先发卡 (拿到 card_message_id)
        self.notifier.send_alarm_card(
            alarm_id=alarm_id, alarm_type="intrusion",
            level="critical", camera_id="cam_zone_a",
            message="人员闯入 A 区危险区域",
        )

        payload = {
            "open_id": "ou_xxxxxxxxxxxxx_003",  # 王组长 (team_leader)
            "open_message_id": self.storage.get_alarm(alarm_id)["card_message_id"],
            "action": {"value": {"action": "snooze", "alarm_id": alarm_id,
                                 "minutes": 15}},
        }
        resp = self.client.post("/api/lark/card-action",
                                data=json.dumps(payload),
                                content_type="application/json")
        self.assertEqual(resp.status_code, 200)
        body = resp.get_json()
        self.assertEqual(body["code"], 0, body)
        self.assertIn("card", body)

        # 验证 snoozed + snooze_until
        alarm = self.storage.get_alarm(alarm_id)
        self.assertEqual(alarm["ack_status"], "snoozed", alarm)
        self.assertIsNotNone(alarm["snooze_until"], "snooze_until 未设置")

        # snoozed 告警不应出现在 pending 列表, 但应出现在 due_for_reminder (如果时间到)
        # 这里 snooze_until 是未来 15min, 所以 due_for_reminder 应为空
        due = self.storage.query_alarms_due_for_reminder()
        self.assertFalse(any(d["id"] == alarm_id for d in due),
                         "snooze_until 未到点, 不应在 due_for_reminder")

    # ------------------------------------------------------------------
    # forward 流程: 点 "转派班组长" → 转发一卡 + 原卡 note 记录
    # ------------------------------------------------------------------
    def test_e2e_alarm_to_forward(self):
        alarm_id = self.storage.log_alarm(
            alarm_type="no_vest", level="high",
            camera_id="cam_entrance",
            message="检测到 1 人未穿反光衣",
        )
        # 先发给 safety_officer + team_leader (no_vest 的 notify_roles)
        self.notifier.send_alarm_card(
            alarm_id=alarm_id, alarm_type="no_vest",
            level="high", camera_id="cam_entrance",
            message="检测到 1 人未穿反光衣",
        )

        # safety_officer 点"转派班组长"
        payload = {
            "open_id": "ou_xxxxxxxxxxxxx_002",  # 李安全
            "open_message_id": self.storage.get_alarm(alarm_id)["card_message_id"],
            "action": {"value": {"action": "forward", "alarm_id": alarm_id,
                                 "to_role": "team_leader"}},
        }
        resp = self.client.post("/api/lark/card-action",
                                data=json.dumps(payload),
                                content_type="application/json")
        self.assertEqual(resp.status_code, 200)
        body = resp.get_json()
        self.assertEqual(body["code"], 0, body)
        self.assertIn("已转派", body["toast"]["content"])

        # 验证 details 里记了 forwarded 标记
        alarm = self.storage.get_alarm(alarm_id)
        details = json.loads(alarm["details"]) if alarm["details"] else {}
        ack_history = details.get("ack_history", [])
        self.assertTrue(any("forwarded" in (h.get("note") or "")
                            for h in ack_history),
                        f"ack_history 应含 forward 记录: {ack_history}")

    # ------------------------------------------------------------------
    # 错误路径: ack 不存在的 alarm_id
    # ------------------------------------------------------------------
    def test_ack_nonexistent_alarm(self):
        payload = {
            "open_id": "ou_xxx",
            "action": {"value": {"action": "ack", "alarm_id": 99999,
                                 "status": "acknowledged"}},
        }
        resp = self.client.post("/api/lark/card-action",
                                data=json.dumps(payload),
                                content_type="application/json")
        self.assertEqual(resp.status_code, 404)

    # ------------------------------------------------------------------
    # token 校验: 配置了 token 但请求不带或带错 → 401
    # ------------------------------------------------------------------
    def test_token_mismatch(self):
        # 重新构造一个带 token 的 app
        from utils.lark_callback import bp
        import utils.lark_callback as lc
        old_token = os.environ.get("LARK_VERIFICATION_TOKEN")
        os.environ["LARK_VERIFICATION_TOKEN"] = "secret_token_xyz"
        try:
            payload = {
                "token": "wrong_token",
                "open_id": "ou_xxx",
                "action": {"value": {"action": "ack", "alarm_id": 1,
                                     "status": "acknowledged"}},
            }
            resp = self.client.post("/api/lark/card-action",
                                    data=json.dumps(payload),
                                    content_type="application/json")
            self.assertEqual(resp.status_code, 401)
        finally:
            if old_token is None:
                del os.environ["LARK_VERIFICATION_TOKEN"]
            else:
                os.environ["LARK_VERIFICATION_TOKEN"] = old_token

    # ------------------------------------------------------------------
    # 健康检查
    # ------------------------------------------------------------------
    def test_health(self):
        resp = self.client.get("/api/lark/health")
        self.assertEqual(resp.status_code, 200)
        body = resp.get_json()
        self.assertTrue(body["ok"])
        self.assertTrue(body["storage_ready"])
        self.assertTrue(body["notifier_ready"])


if __name__ == "__main__":
    unittest.main(verbosity=2)
