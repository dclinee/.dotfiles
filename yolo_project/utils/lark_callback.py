# -*- coding: utf-8 -*-
"""
utils/lark_callback.py — 飞书交互卡片回调 webhook

飞书 card.action.trigger 事件结构 (V2 简化版):
{
  "ts": "...",
  "uuid": "...",
  "token": "...",  // 验证 token (可选, 与开放平台配置的一致)
  "type": "card.action.trigger",
  "action": {
    "value": {"action": "ack", "alarm_id": 12, "status": "acknowledged"},
    "tag": "button",
  },
  "open_id": "ou_xxx",     // 点击人
  "user_id": "...",
  "open_message_id": "om_xxx",  // 卡片消息 ID
  "open_chat_id": "oc_xxx",
  "token": "..."
}

需要返回: 飞书期望 HTTP 200 + body 可选地包含一个新的 card,
用于实时替换卡片内容 (例如把按钮换成"已处理 ✅").

用法 (作为 Flask 蓝图挂到任何 app):
    from utils.lark_callback import create_lark_callback_app
    app = create_lark_callback_app(storage=..., notifier=...)
    app.run(port=5004)

挂到 dashboard_api:
    from utils.lark_callback import bp as lark_bp
    app.register_blueprint(lark_bp, url_prefix='/api/lark')
    # 再把 storage / notifier 注入:
    from utils.lark_callback import configure
    configure(storage=..., notifier=...)
"""

from __future__ import annotations

import json
import logging
import os
import threading
from typing import Optional

from flask import Blueprint, Flask, jsonify, request, g

logger = logging.getLogger(__name__)

# 模块级单例 (在没注入时给个默认空对象, 避免构造时崩)
_storage = None
_notifier = None
_lock = threading.Lock()


def configure(storage=None, notifier=None,
              verify_token: str = None):
    """注入依赖. 在 Flask 启动前调用一次.
    verify_token: 飞书开放平台配置的 Verification Token (用于校验请求来源).
                  不传则从环境变量 LARK_VERIFICATION_TOKEN 读.
    """
    global _storage, _notifier
    with _lock:
        if storage is not None:
            _storage = storage
        if notifier is not None:
            _notifier = notifier
        if verify_token is not None:
            os.environ["LARK_VERIFICATION_TOKEN"] = verify_token


bp = Blueprint("lark_callback", __name__)


# ============================================================
# Flask 路由
# ============================================================
@bp.route("/card-action", methods=["POST"])
def card_action():
    """飞书卡片按钮点击回调.
    飞书期望 200 返回. body 可以包含 "card": {...} 来实时替换卡片内容.
    """
    payload = request.get_json(silent=True) or {}
    # 飞书 v1/v2 兼容: 有些版本是 {action: {...}} 直接, 有些包在 event/action 里
    action = payload.get("action") or {}
    if not action and "event" in payload:
        action = (payload.get("event") or {}).get("action") or {}
    value = action.get("value") or {}
    open_id = payload.get("open_id") or payload.get("user", {}).get("open_id", "")
    open_message_id = payload.get("open_message_id") or ""
    action_name = value.get("action", "")

    # 验证 token (如果环境变量配了)
    expected_token = os.environ.get("LARK_VERIFICATION_TOKEN", "")
    if expected_token:
        req_token = payload.get("token") or payload.get("header", {}).get("token", "")
        if req_token and req_token != expected_token:
            logger.warning("Lark token 校验失败: expected=%s got=%s",
                           expected_token[:6], (req_token or "")[:6])
            return jsonify({"code": 401, "msg": "token mismatch"}), 401

    # 分发
    try:
        if action_name == "ack":
            return _handle_ack(value, open_id, open_message_id)
        if action_name == "snooze":
            return _handle_snooze(value, open_id, open_message_id)
        if action_name == "forward":
            return _handle_forward(value, open_id, open_message_id)
        if action_name == "bulk_approve":
            return _handle_bulk_approve(value, open_id)
        if action_name == "open_review":
            # 这种是跳转链接按钮, 飞书端会自己打开 URL, 服务端只回个 toast
            return jsonify({"code": 0, "toast": {"type": "info",
                "content": "请在浏览器打开审核页面"}})
        logger.info("未知 action: %s (value=%s)", action_name, value)
        return jsonify({"code": 0})
    except Exception as e:
        logger.exception("card-action 处理异常: %s", e)
        return jsonify({"code": 500, "msg": str(e)}), 500


@bp.route("/health", methods=["GET"])
def health():
    """健康检查"""
    return jsonify({
        "ok": True,
        "storage_ready": _storage is not None,
        "notifier_ready": _notifier is not None,
        "verify_token_configured": bool(os.environ.get("LARK_VERIFICATION_TOKEN")),
    })


# ============================================================
# 处理函数
# ============================================================
def _handle_ack(value: dict, open_id: str, open_message_id: str = ""):
    """按钮: 已处理 / 忽略 — value: {action:ack, alarm_id:N, status:acknowledged/dismissed}"""
    alarm_id = int(value.get("alarm_id") or 0)
    status = value.get("status", "acknowledged")
    if status not in ("acknowledged", "dismissed"):
        status = "acknowledged"
    if not alarm_id or _storage is None:
        return jsonify({"code": 400, "msg": "missing alarm_id or storage"}), 400

    # 取一下原始 alarm, 用于构造更新后的卡片
    alarm = _storage.get_alarm(alarm_id)
    if not alarm:
        return jsonify({"code": 404, "msg": f"alarm {alarm_id} not found"}), 404

    ack_by_name = _lookup_operator_name(open_id)
    ok = _storage.ack_alarm(alarm_id, status=status,
                            ack_by=open_id,
                            note=f"按钮:{status} by {ack_by_name}")
    logger.info("[ack] alarm #%d → %s by %s (%s) ok=%s",
                alarm_id, status, open_id, ack_by_name, ok)

    # 构造更新后的卡片 (按钮替换为状态徽章)
    if _notifier is not None:
        new_card = _notifier._build_alarm_card(
            alarm_id=alarm_id, alarm_type=alarm["alarm_type"],
            level=alarm["level"], camera_id=alarm.get("camera_id") or "",
            message=alarm.get("message") or "",
            created_at=alarm.get("created_at"),
            snapshot_path=alarm.get("snapshot_path"),
            ack_status=status,
        )
        toast = {"type": "success" if status == "acknowledged" else "info",
                 "content": f"已标记为: {status}  ({ack_by_name})"}
        return jsonify({"code": 0, "toast": toast, "card": new_card})
    return jsonify({"code": 0})


def _handle_snooze(value: dict, open_id: str, open_message_id: str = ""):
    """按钮: 15min 后再提醒 — value: {action:snooze, alarm_id:N, minutes:15}"""
    alarm_id = int(value.get("alarm_id") or 0)
    minutes = int(value.get("minutes", 15))
    if not alarm_id or _storage is None:
        return jsonify({"code": 400, "msg": "missing alarm_id or storage"}), 400
    alarm = _storage.get_alarm(alarm_id)
    if not alarm:
        return jsonify({"code": 404, "msg": f"alarm {alarm_id} not found"}), 404

    ack_by_name = _lookup_operator_name(open_id)
    # 用 note 传分钟数, storage.ack_alarm 会解析并算 snooze_until
    ok = _storage.ack_alarm(alarm_id, status="snoozed",
                            ack_by=open_id,
                            note=str(minutes))
    logger.info("[snooze] alarm #%d → snoozed %d min by %s (%s) ok=%s",
                alarm_id, minutes, open_id, ack_by_name, ok)
    if _notifier is not None:
        new_card = _notifier._build_alarm_card(
            alarm_id=alarm_id, alarm_type=alarm["alarm_type"],
            level=alarm["level"], camera_id=alarm.get("camera_id") or "",
            message=alarm.get("message") or "",
            created_at=alarm.get("created_at"),
            snapshot_path=alarm.get("snapshot_path"),
            ack_status="snoozed",
        )
        return jsonify({"code": 0,
                        "toast": {"type": "success",
                                  "content": f"已设置 {minutes} 分钟后再次提醒"},
                        "card": new_card})
    return jsonify({"code": 0})


def _handle_forward(value: dict, open_id: str, open_message_id: str = ""):
    """按钮: 转派班组长 — value: {action:forward, alarm_id:N, to_role:team_leader}
    逻辑: 取所有该角色成员, 把告警卡片再发一份给他们.
    """
    alarm_id = int(value.get("alarm_id") or 0)
    to_role = value.get("to_role", "team_leader")
    if not alarm_id or _notifier is None or _storage is None:
        return jsonify({"code": 400, "msg": "missing deps"}), 400
    alarm = _storage.get_alarm(alarm_id)
    if not alarm:
        return jsonify({"code": 404, "msg": f"alarm {alarm_id} not found"}), 404

    ack_by_name = _lookup_operator_name(open_id)
    r = _notifier.send_alarm_card(
        alarm_id=alarm_id, alarm_type=alarm["alarm_type"],
        level=alarm["level"], camera_id=alarm.get("camera_id") or "",
        message=(alarm.get("message") or "") +
                f"\n\n📢 _由 {ack_by_name} 转派给 {to_role}_",
        snapshot_path=alarm.get("snapshot_path"),
        notify_roles=[to_role],
    )
    # 同时在原卡片上记一笔: 已转派
    _storage.ack_alarm(alarm_id, status="pending",
                       ack_by=open_id,
                       note=f"forwarded to {to_role} by {ack_by_name}")
    logger.info("[forward] alarm #%d → %s (sent_to=%d) by %s",
                alarm_id, to_role, len(r.get("sent_to", [])), ack_by_name)
    toast_msg = (f"已转派给 {to_role} ({len(r.get('sent_to', []))} 人)"
                 if r.get("ok") else "转派失败, 请联系管理员")
    return jsonify({
        "code": 0,
        "toast": {"type": "success" if r.get("ok") else "error",
                  "content": toast_msg},
        # 不替换原卡片 (转派操作不改变本卡片状态)
    })


def _handle_bulk_approve(value: dict, open_id: str):
    """按钮: 一键全部通过 (高质量 labeled 图) — value: {action:bulk_approve, filter:labeled}"""
    if _storage is None:
        return jsonify({"code": 400, "msg": "storage not ready"}), 400
    flt = value.get("filter", "labeled")
    rows = _storage.query_photos(status=flt, limit=500)
    approved = 0
    for p in rows:
        # 调用 auto_retrain 的 approve 路由? 这里直接改 status
        try:
            _storage.update_photo_status(p["id"], "reviewed")
            approved += 1
        except Exception as e:
            logger.warning("bulk_approve photo %s 失败: %s", p.get("id"), e)
    logger.info("[bulk_approve] filter=%s approved=%d by %s",
                flt, approved, open_id)
    return jsonify({
        "code": 0,
        "toast": {"type": "success",
                  "content": f"已批量通过 {approved} 张 {flt} 照片"},
    })


def _lookup_operator_name(open_id: str) -> str:
    """根据 open_id 反查姓名 (从 notifier.roles 配置里找).
    没找到就返回 open_id 前 10 位.
    """
    if _notifier is None:
        return open_id[:10]
    for role in _notifier.roles.values():
        for m in role.get("members", []):
            if m.get("open_id") == open_id:
                return m.get("name", open_id[:10])
    return open_id[:10]


# ============================================================
# 单独跑 (调试用)
# ============================================================
def create_lark_callback_app(storage=None, notifier=None,
                             verify_token: str = None) -> Flask:
    """单独跑时构造一个完整 Flask app; 也可作为蓝图挂到其他 app."""
    configure(storage=storage, notifier=notifier, verify_token=verify_token)
    app = Flask(__name__)
    app.register_blueprint(bp, url_prefix="/api/lark")
    return app


if __name__ == "__main__":
    import argparse
    import sys
    from pathlib import Path
    sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
    from utils.storage import SiteDatabase
    from utils.notify import LarkNotifier

    ap = argparse.ArgumentParser(description="飞书卡片回调 webhook (独立调试)")
    ap.add_argument("--db", default="runs/data/site.db")
    ap.add_argument("--personnel", default="configs/personnel.json")
    ap.add_argument("--host", default="0.0.0.0")
    ap.add_argument("--port", type=int, default=5004)
    ap.add_argument("--token", default=None, help="飞书 Verification Token")
    args = ap.parse_args()

    logging.basicConfig(level=logging.INFO,
                        format="%(asctime)s [%(levelname)s] %(name)s: %(message)s")
    storage = SiteDatabase(args.db)
    notifier = LarkNotifier(args.personnel, storage=storage)
    app = create_lark_callback_app(storage=storage, notifier=notifier,
                                   verify_token=args.token)
    logger.info("🚀 Lark callback webhook on http://%s:%d/api/lark/card-action",
                args.host, args.port)
    app.run(host=args.host, port=args.port, threaded=True, use_reloader=False)
