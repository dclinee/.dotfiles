#!/usr/bin/env python3
"""
智慧工地 - 手机定位 API 服务器
接收手机 GPS 上报, 提供实时状态查询, 班组统计接口

API 接口:
  POST /api/location/report      手机上报GPS
  GET  /api/location/status      查询所有工人状态
  GET  /api/location/worker/{id} 查询单个工人
  GET  /api/stats/teams          班组统计
  GET  /api/stats/summary        总览统计
  GET  /api/geofence             电子栅栏配置
  GET  /api/workers              工人列表
  GET  /                         手机端 H5 定位页面

端口: 8090 (默认)
"""

import json
import os
import sys
import time
import argparse
from pathlib import Path
from datetime import datetime

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

try:
    from flask import Flask, request, jsonify, render_template_string
except ImportError:
    print("需要安装 Flask: pip install flask")
    sys.exit(1)

from utils.positioning import WorkerTracker, get_tracker
from utils.notify import LarkNotifier
from utils.storage import SiteDatabase

# ============================================================
# H5 手机端定位页面
# ============================================================

MOBILE_PAGE = """
<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1,user-scalable=no">
<title>智慧工地 - 工人定位</title>
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:"Microsoft YaHei",sans-serif;background:#0f1923;color:#e0e0e0;min-height:100vh;padding:15px}
.header{text-align:center;padding:20px 0;border-bottom:2px solid #2a3a4a;margin-bottom:20px}
.header h1{color:#00d4ff;font-size:22px}
.header .subtitle{color:#667788;font-size:13px;margin-top:5px}
.card{background:#1a2a3a;border-radius:12px;padding:20px;margin-bottom:15px;border:1px solid #2a3a4a}
.card h3{color:#00d4ff;font-size:15px;margin-bottom:12px}
.form-group{margin-bottom:15px}
.form-group label{display:block;color:#8899aa;font-size:13px;margin-bottom:5px}
.form-group input,.form-group select{width:100%;padding:12px;background:#0f1923;border:1px solid #2a3a4a;border-radius:8px;color:#e0e0e0;font-size:15px}
.form-group input:focus{border-color:#00d4ff;outline:none}
.btn{width:100%;padding:14px;border:none;border-radius:8px;font-size:16px;font-weight:bold;cursor:pointer;margin-top:10px;transition:all .2s}
.btn-primary{background:#00d4ff;color:#0f1923}
.btn-primary:active{background:#00aacc}
.btn-danger{background:#ff4444;color:#fff}
.btn-danger:active{background:#cc0000}
.btn-success{background:#00ff88;color:#0f1923}
.btn-success:active{background:#00cc66}
.status-bar{display:flex;justify-content:space-around;padding:15px;background:#1a2a3a;border-radius:12px;margin-bottom:15px}
.status-item{text-align:center}
.status-item .value{font-size:24px;font-weight:bold}
.status-item .label{font-size:12px;color:#8899aa;margin-top:3px}
.status-item.on .value{color:#00ff88}
.status-item.off .value{color:#ff6b6b}
.status-item.gps .value{color:#00d4ff}
.info-row{display:flex;justify-content:space-between;padding:6px 0;color:#8899aa;font-size:13px;border-bottom:1px solid #1a2838}
.info-row .val{color:#e0e0e0;font-weight:bold}
.alert{background:#ff4444;color:#fff;padding:12px;border-radius:8px;margin-bottom:15px;display:none;text-align:center;font-size:14px}
.alert.show{display:block}
.log{max-height:200px;overflow-y:auto;font-size:12px;color:#667788}
.log .entry{padding:3px 0;border-bottom:1px solid #1a2838}
.log .time{color:#00d4ff;font-family:monospace}
</style>
</head>
<body>

<div class="header"><h1>智慧工地 - 工人定位</h1><div class="subtitle" id="pageTime">--</div></div>

<div class="alert" id="alertBox"></div>

<div class="card">
    <h3>人员信息</h3>
    <div class="form-group">
        <label>手机号 (工号)</label>
        <input type="tel" id="phone" placeholder="输入手机号" maxlength="11">
    </div>
    <div class="info-row"><span>姓名</span><span class="val" id="infoName">--</span></div>
    <div class="info-row"><span>班组</span><span class="val" id="infoTeam">--</span></div>
    <div class="info-row"><span>角色</span><span class="val" id="infoRole">--</span></div>
    <button class="btn btn-primary" onclick="identify()">验证身份</button>
</div>

<div class="status-bar" id="statusBar" style="display:none">
    <div class="status-item gps"><div class="value" id="gpsAccuracy">--</div><div class="label">GPS精度</div></div>
    <div class="status-item on"><div class="value" id="onSite">--</div><div class="label">在场状态</div></div>
    <div class="status-item"><div class="value" id="battery">--</div><div class="label">电量</div></div>
</div>

<div class="card" id="gpsCard" style="display:none">
    <h3>GPS 定位</h3>
    <div class="info-row"><span>纬度</span><span class="val" id="infoLat">--</span></div>
    <div class="info-row"><span>经度</span><span class="val" id="infoLon">--</span></div>
    <div class="info-row"><span>所在区域</span><span class="val" id="infoZone">--</span></div>
    <div class="info-row"><span>距工地中心</span><span class="val" id="infoDist">--</span></div>
    <div class="info-row"><span>签到时间</span><span class="val" id="infoCheckin">--</span></div>
    <div class="info-row"><span>在场时长</span><span class="val" id="infoDuration">--</span></div>
    <button class="btn btn-primary" id="startBtn" onclick="startTracking()">开始定位上报</button>
    <button class="btn btn-danger" id="stopBtn" onclick="stopTracking()" style="display:none">停止上报</button>
</div>

<div class="card" id="logCard" style="display:none">
    <h3>上报日志</h3>
    <div class="log" id="logBox"></div>
</div>

<script>
let workerPhone = '';
let tracking = false;
let trackingTimer = null;
let watchId = null;

function showAlert(msg, isGood){
    const box = document.getElementById('alertBox');
    box.textContent = msg;
    box.style.background = isGood ? '#00cc66' : '#ff4444';
    box.className = 'alert show';
    setTimeout(() => box.className = 'alert', 3000);
}

function addLog(msg){
    const now = new Date().toTimeString().slice(0, 8);
    const box = document.getElementById('logBox');
    box.innerHTML = `<div class="entry"><span class="time">${now}</span> ${msg}</div>` + box.innerHTML;
    if(box.children.length > 50) box.lastChild.remove();
}

async function identify(){
    const phone = document.getElementById('phone').value.trim();
    if(!phone || phone.length < 11){ showAlert('请输入正确的手机号'); return; }

    try{
        const resp = await fetch('/api/workers/identify?phone=' + phone);
        const data = await resp.json();
        if(data.error){ showAlert(data.error); return; }

        workerPhone = phone;
        document.getElementById('infoName').textContent = data.name;
        document.getElementById('infoTeam').textContent = data.team;
        document.getElementById('infoRole').textContent = data.role;
        document.getElementById('gpsCard').style.display = 'block';
        document.getElementById('logCard').style.display = 'block';
        showAlert('身份验证成功: ' + data.name + ' (' + data.team + ')', true);
    }catch(e){
        showAlert('网络错误, 请重试');
    }
}

function startTracking(){
    if(!workerPhone){ showAlert('请先验证身份'); return; }
    if(!navigator.geolocation){
        showAlert('您的手机不支持GPS定位');
        return;
    }

    document.getElementById('startBtn').style.display = 'none';
    document.getElementById('stopBtn').style.display = 'block';
    document.getElementById('statusBar').style.display = 'flex';
    tracking = true;
    addLog('开始GPS定位...');

    // 使用 watchPosition 持续获取位置
    watchId = navigator.geolocation.watchPosition(
        pos => {
            if(!tracking) return;
            sendLocation(pos.coords.latitude, pos.coords.longitude, pos.coords.accuracy);
        },
        err => {
            addLog('GPS错误: ' + err.message);
            document.getElementById('gpsAccuracy').textContent = '无信号';
        },
        { enableHighAccuracy: true, maximumAge: 5000, timeout: 15000 }
    );

    // 后备定时器 (10秒)
    trackingTimer = setInterval(() => {
        if(!tracking) return;
        navigator.geolocation.getCurrentPosition(
            pos => sendLocation(pos.coords.latitude, pos.coords.longitude, pos.coords.accuracy),
            err => {},
            { enableHighAccuracy: true, timeout: 10000 }
        );
    }, 10000);
}

function stopTracking(){
    tracking = false;
    if(watchId) navigator.geolocation.clearWatch(watchId);
    if(trackingTimer) clearInterval(trackingTimer);
    document.getElementById('startBtn').style.display = 'block';
    document.getElementById('stopBtn').style.display = 'none';
    addLog('停止定位上报');
}

async function sendLocation(lat, lon, acc){
    try{
        const resp = await fetch('/api/location/report', {
            method: 'POST',
            headers: {'Content-Type': 'application/json'},
            body: JSON.stringify({
                phone: workerPhone,
                lat: lat,
                lon: lon,
                accuracy: acc || 0,
                speed: 0,
                battery: 100,
            }),
        });
        const data = await resp.json();

        document.getElementById('infoLat').textContent = lat.toFixed(6);
        document.getElementById('infoLon').textContent = lon.toFixed(6);
        document.getElementById('gpsAccuracy').textContent = (acc||0).toFixed(0) + 'm';
        document.getElementById('infoZone').textContent = data.zone || '未分区';
        document.getElementById('infoDist').textContent = data.dist_to_site ? data.dist_to_site.toFixed(0) + 'm' : '--';
        document.getElementById('infoCheckin').textContent = data.checkin_time || '--';
        document.getElementById('infoDuration').textContent = data.duration || '--';
        document.getElementById('onSite').textContent = data.on_site ? '●在场' : '○离场';
        document.getElementById('battery').textContent = (data.battery||100) + '%';

        let zoneInfo = data.zone ? '区域:' + data.zone : '';
        addLog(`上报: ${lat.toFixed(5)},${lon.toFixed(5)} ${zoneInfo} ${data.on_site?'在场':'离场'}`);
    }catch(e){
        addLog('上报失败: ' + e.message);
    }
}

// 页面加载时自动更新系统时间
setInterval(() => {
    document.getElementById('pageTime').textContent = new Date().toLocaleString('zh-CN');
}, 1000);
</script>
</body>
</html>
"""

# ============================================================
# Flask 应用
# ============================================================

class PositioningServer:
    """GPS 定位 API 服务器"""

    # 同一 worker 的 GPS 写入 DB 的最小间隔 (秒)，避免 DB 被密集上报打爆
    LOCATION_DB_MIN_INTERVAL = 15
    # 同一 worker 的同一类告警的最小间隔 (秒)
    ALARM_COOLDOWN_SECONDS = {
        "geofence_intrusion": 180,  # 3 分钟
        "geofence_leave": 600,       # 10 分钟
        "geofence_late": 1800,       # 30 分钟
    }

    def __init__(self, workers_config="configs/workers.json",
                 geofence_config="configs/site_geofence.json",
                 personnel_config="configs/personnel.json",
                 notify_enabled=False,
                 storage_enabled=False,
                 db_path="runs/data/site.db"):
        self.tracker = WorkerTracker(workers_config, geofence_config)
        self.notifier = LarkNotifier(personnel_config) if notify_enabled else None
        self.notify_enabled = notify_enabled
        self.storage_enabled = storage_enabled
        self.db_path = db_path
        self.storage = SiteDatabase(db_path) if storage_enabled else None

        # 事件日志 (内存，用于 /api/events; 同时落库 storage)
        self.event_log = []  # 最近 200 条

        # 冷却追踪: { (worker_id, alarm_type): last_alarm_ts }
        self._last_alarm_ts = {}
        # 每个 worker 上次写 locations 表的时间戳: { worker_id: ts }
        self._last_location_db_ts = {}

        # 注册通知回调
        if self.notifier:
            self.tracker.on("enter_danger", self._on_enter_danger)
            self.tracker.on("leave_site", self._on_leave_site)
        else:
            # 即使没 notifier，也要把事件写入 storage / event_log
            self.tracker.on("enter_danger", self._on_enter_danger)
            self.tracker.on("leave_site", self._on_leave_site)

    # ============================================================
    #  内部工具
    # ============================================================
    def _alarm_allowed(self, worker_id: str, alarm_type: str) -> bool:
        key = (worker_id, alarm_type)
        now = time.time()
        cd = self.ALARM_COOLDOWN_SECONDS.get(alarm_type, 300)
        prev = self._last_alarm_ts.get(key, 0)
        if now - prev < cd:
            return False
        self._last_alarm_ts[key] = now
        return True

    def _persist_event(self, etype: str, worker: dict, message: str,
                       details: dict = None):
        """同时写内存事件日志 + storage.events（如果启用）"""
        entry = {
            "time": datetime.now().strftime("%H:%M:%S"),
            "type": etype,
            "name": worker.get("name", ""),
            "team": worker.get("team", ""),
            "worker_id": worker.get("id", ""),
            "message": message,
            "details": details or {},
        }
        self.event_log.append(entry)
        if len(self.event_log) > 200:
            self.event_log = self.event_log[-200:]
        if self.storage:
            self.storage.log_event(
                source=f"gps:{worker.get('id','')}",
                event_type=etype,
                message=f"[{worker.get('team','')}] {worker.get('name','')} {message}",
                details=details or {},
            )

    # ============================================================
    #  电子栅栏回调
    # ============================================================
    def _on_enter_danger(self, worker, status, zone_name, zone_id=None, **kwargs):
        msg = f"进入危险区域: {zone_name}"
        worker_id = worker.get("id", "")
        self._persist_event("geofence_intrusion", worker, msg,
                            details={
                                "worker_id": worker_id,
                                "zone_id": zone_id or "",
                                "zone_name": zone_name,
                                "latitude": getattr(status, "latitude", None),
                                "longitude": getattr(status, "longitude", None),
                            })
        alarm_kwargs = {
            "zone_name": zone_name,
            "zone_id": zone_id or "",
            "worker_name": worker.get("name", ""),
            "team": worker.get("team", ""),
            "time": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        }
        # SQLite 告警
        if self.storage and self._alarm_allowed(worker_id, "geofence_intrusion"):
            self.storage.log_alarm(
                alarm_type="geofence_intrusion",
                level="critical",
                source=f"gps:{worker_id}",
                message=f"[{worker.get('team','')}] {worker.get('name','')} 进入危险区域: {zone_name}",
                details=alarm_kwargs,
                camera_id=None,
                worker_id=worker_id,
            )
        # 飞书通知
        if self.notifier and self._alarm_allowed(worker_id, "_lark_geofence_intrusion"):
            self.notifier.send_alarm(
                alarm_type="geofence_intrusion",
                camera_id=None,
                worker_name=worker.get("name", ""),
                **alarm_kwargs,
            )

    def _on_leave_site(self, worker, status, dist_to_site, **kwargs):
        msg = f"离开工地范围 (距离边界约 {dist_to_site:.0f} m)"
        worker_id = worker.get("id", "")
        self._persist_event("geofence_leave", worker, msg,
                            details={
                                "worker_id": worker_id,
                                "distance_meters": round(float(dist_to_site), 1),
                                "latitude": getattr(status, "latitude", None),
                                "longitude": getattr(status, "longitude", None),
                            })
        alarm_kwargs = {
            "worker_name": worker.get("name", ""),
            "team": worker.get("team", ""),
            "distance": f"{dist_to_site:.0f}m",
            "dist_meters": round(float(dist_to_site), 1),
            "time": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        }
        if self.storage and self._alarm_allowed(worker_id, "geofence_leave"):
            self.storage.log_alarm(
                alarm_type="geofence_leave",
                level="mid",
                source=f"gps:{worker_id}",
                message=f"[{worker.get('team','')}] {worker.get('name','')} 离开工地 ({dist_to_site:.0f}m)",
                details=alarm_kwargs,
                camera_id=None,
                worker_id=worker_id,
            )
        if self.notifier and self._alarm_allowed(worker_id, "_lark_geofence_leave"):
            self.notifier.send_alarm(
                alarm_type="geofence_leave",
                camera_id=None,
                **alarm_kwargs,
            )

    def _log_event(self, etype, name, team, msg):
        """兼容老的简单事件日志接口 (未提供 worker 对象时用)"""
        entry = {
            "time": datetime.now().strftime("%H:%M:%S"),
            "type": etype,
            "name": name,
            "team": team,
            "message": msg,
            "worker_id": "",
            "details": {},
        }
        self.event_log.append(entry)
        if len(self.event_log) > 200:
            self.event_log = self.event_log[-200:]

    def register_routes(self, app):
        """注册所有 API 路由"""

        # ===== 手机端 H5 页面 =====
        @app.route("/")
        def index():
            return render_template_string(MOBILE_PAGE)

        # ===== GPS 上报接口 =====
        @app.route("/api/location/report", methods=["POST"])
        def report_location():
            """手机 GPS 上报"""
            data = request.get_json()
            if not data:
                return jsonify({"ok": False, "error": "请求体为空"}), 400

            phone = data.get("phone", "")
            lat = data.get("lat", 0)
            lon = data.get("lon", 0)
            accuracy = data.get("accuracy", 0)
            speed = data.get("speed", 0)
            battery = data.get("battery", 100)

            if not phone:
                return jsonify({"ok": False, "error": "缺少手机号"}), 400

            worker = self.tracker.get_worker_by_phone(phone)
            if not worker:
                return jsonify({"ok": False, "error": f"未找到手机号: {phone}"}), 404

            try:
                status = self.tracker.update_location(
                    phone, lat, lon, accuracy, speed, battery=battery,
                )
            except Exception as e:
                return jsonify({"ok": False, "error": str(e)}), 500

            # ---------- 实时定位追踪落库 (限频) ----------
            if self.storage:
                wid = worker["id"]
                now_ts = time.time()
                prev = self._last_location_db_ts.get(wid, 0)
                if now_ts - prev >= self.LOCATION_DB_MIN_INTERVAL:
                    self._last_location_db_ts[wid] = now_ts
                    self.storage.log_location(
                        worker_id=wid,
                        worker_name=worker.get("name", ""),
                        team=worker.get("team", ""),
                        latitude=lat,
                        longitude=lon,
                        accuracy=float(accuracy or 0),
                        on_site=bool(getattr(status, "on_site", False)),
                        current_zone=getattr(status, "current_zone", None) or "",
                        in_danger=bool(getattr(status, "in_danger_zone", False)),
                        zone_type=getattr(status, "zone_type", None) or "",
                        speed=float(speed or 0),
                        battery=int(battery or 0),
                    )

            return jsonify({
                "ok": True,
                "worker_id": worker["id"],
                "name": worker["name"],
                "team": worker["team"],
                "role": worker.get("role", ""),
                "on_site": status.on_site,
                "zone": status.current_zone,
                "zone_type": status.zone_type,
                "in_danger": status.in_danger_zone,
                "dist_to_site": self.tracker.geofence.distance_to_site(lat, lon),
                "checkin_time": status.checkin_time or "",
                "duration": WorkerTracker._format_duration(status.on_site_duration),
                "battery": battery,
                "timestamp": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            })

        # ===== 工人识别 =====
        @app.route("/api/workers/identify")
        def identify_worker():
            """通过手机号识别工人身份"""
            phone = request.args.get("phone", "")
            if not phone:
                return jsonify({"error": "缺少手机号"}), 400

            worker = self.tracker.get_worker_by_phone(phone)
            if not worker:
                return jsonify({"error": f"未找到手机号: {phone}"}), 404

            return jsonify({
                "name": worker["name"],
                "team": worker["team"],
                "role": worker["role"],
                "id": worker["id"],
            })

        # ===== 工人列表 =====
        @app.route("/api/workers")
        def list_workers():
            """获取所有工人列表"""
            workers = []
            for w in self.tracker.workers_db["workers"]:
                status = self.tracker.get_worker_status(w["id"])
                workers.append({
                    "id": w["id"],
                    "name": w["name"],
                    "phone": w["phone"],
                    "team": w["team"],
                    "role": w["role"],
                    "on_site": status.on_site if status else False,
                    "zone": status.current_zone if status else "",
                    "last_update": datetime.fromtimestamp(
                        status.last_update
                    ).strftime("%H:%M:%S") if status and status.last_update > 0 else "N/A",
                })
            return jsonify(workers)

        # ===== 单个工人状态 =====
        @app.route("/api/location/worker/<worker_id>")
        def get_worker_status(worker_id):
            """查询单个工人"""
            status = self.tracker.get_worker_status(worker_id)
            if not status:
                return jsonify({"error": "未找到工人"}), 404

            worker = self.tracker.get_worker_by_id(worker_id)
            return jsonify({
                "id": worker_id,
                "name": worker["name"] if worker else "",
                "team": worker["team"] if worker else "",
                "role": worker["role"] if worker else "",
                "on_site": status.on_site,
                "latitude": status.latitude,
                "longitude": status.longitude,
                "accuracy": status.accuracy,
                "zone": status.current_zone,
                "zone_type": status.zone_type,
                "in_danger": status.in_danger_zone,
                "is_moving": status.is_moving,
                "is_late": status.is_late,
                "checkin_time": status.checkin_time,
                "duration": WorkerTracker._format_duration(status.on_site_duration),
                "last_update": datetime.fromtimestamp(status.last_update).strftime("%H:%M:%S"),
            })

        # ===== 全部工人状态 =====
        @app.route("/api/location/status")
        def get_all_status():
            """查询所有工人实时状态"""
            workers = []
            for w in self.tracker.workers_db["workers"]:
                status = self.tracker.get_worker_status(w["id"])
                if not status:
                    continue
                workers.append({
                    "id": w["id"],
                    "name": w["name"],
                    "phone": w["phone"],
                    "team": w["team"],
                    "role": w["role"],
                    "on_site": status.on_site,
                    "latitude": status.latitude,
                    "longitude": status.longitude,
                    "accuracy": status.accuracy,
                    "zone": status.current_zone,
                    "zone_type": status.zone_type,
                    "in_danger": status.in_danger_zone,
                    "is_moving": status.is_moving,
                    "is_late": status.is_late,
                    "checkin_time": status.checkin_time,
                    "duration": WorkerTracker._format_duration(status.on_site_duration),
                    "last_update": datetime.fromtimestamp(status.last_update).strftime("%H:%M:%S")
                        if status.last_update > 0 else "N/A",
                })
            return jsonify(workers)

        # ===== 班组统计 =====
        @app.route("/api/stats/teams")
        def get_team_stats():
            """班组统计：补全出勤率/迟到/危险区等关键字段"""
            raw = self.tracker.get_team_stats()
            # 原始 raw["total_workers"] 只统计有状态的, 这里替换成花名册总人数更准确
            roster_total = len(self.tracker.workers_db.get("workers", []))
            teams_cfg = self.tracker.workers_db.get("teams", {})

            # 每个 team 先按花名册计算 should_attend (应到人数)
            team_roster = {}
            for w in self.tracker.workers_db.get("workers", []):
                tm = w.get("team") or "未分组"
                team_roster.setdefault(tm, 0)
                team_roster[tm] += 1

            total_on_site = 0
            total_off_site = 0
            total_in_danger = 0
            total_late = 0
            for tm_name, tm in raw.get("teams", {}).items():
                should = team_roster.get(tm_name, 0)
                on_s = int(tm.get("on_site", 0))
                off_s = int(tm.get("off_site", 0))
                rate = round(on_s / should * 100, 1) if should > 0 else 0.0
                # 迟到/危险区 细项统计 (该 team 的所有工人遍历)
                late_n = 0
                danger_n = 0
                not_reported = max(0, should - (on_s + off_s))
                for w in self.tracker.workers_db.get("workers", []):
                    if (w.get("team") or "未分组") != tm_name:
                        continue
                    st = self.tracker.get_worker_status(w["id"])
                    if st and getattr(st, "is_late", False):
                        late_n += 1
                    if st and getattr(st, "in_danger_zone", False):
                        danger_n += 1
                total_on_site += on_s
                total_off_site += off_s
                total_late += late_n
                total_in_danger += danger_n
                tm["should_attend"] = should
                tm["attendance_rate"] = rate
                tm["late"] = late_n
                tm["in_danger"] = danger_n
                tm["not_reported_yet"] = not_reported  # 应到但还未上报过定位的人
                # 附加 teams 配置 (工作区/类型/班长)
                if tm_name in teams_cfg:
                    cfg = teams_cfg[tm_name]
                    tm.setdefault("type", cfg.get("type", ""))
                    tm.setdefault("leader", cfg.get("leader_name", ""))
                    tm.setdefault("work_area", cfg.get("work_area", ""))
                    tm["schedule"] = cfg.get("schedule", "")

            raw["total_workers"] = roster_total
            raw["on_site"] = total_on_site
            raw["off_site"] = total_off_site
            raw["in_danger_total"] = total_in_danger
            raw["late_total"] = total_late
            raw["attendance_rate_total"] = (
                round(total_on_site / roster_total * 100, 1) if roster_total > 0 else 0.0
            )
            return jsonify(raw)

        # ===== 总览统计 =====
        @app.route("/api/stats/summary")
        def get_summary():
            """总览统计：出勤/危险区一览"""
            import copy
            teams = get_team_stats().get_json() if False else None
            raw = self.tracker.get_team_stats()  # 不走上面包装，避免双重包装
            # 重算与班组统计一致的字段
            roster_total = len(self.tracker.workers_db.get("workers", []))
            on_s = raw.get("on_site", 0)
            off_s = raw.get("off_site", 0)
            in_danger = 0
            late_n = 0
            for w in self.tracker.workers_db.get("workers", []):
                st = self.tracker.get_worker_status(w["id"])
                if st and getattr(st, "in_danger_zone", False):
                    in_danger += 1
                if st and getattr(st, "is_late", False):
                    late_n += 1
            return jsonify({
                "total_workers": roster_total,
                "on_site": on_s,
                "off_site": off_s,
                "not_reported_yet": max(0, roster_total - on_s - off_s),
                "attendance_rate": round(on_s / roster_total * 100, 1) if roster_total > 0 else 0.0,
                "in_danger": in_danger,
                "late": late_n,
                "updated_at": raw.get("updated_at") or datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
                "db_storage": self.storage_enabled,
                "notify": self.notify_enabled,
                "db_path": self.db_path if self.storage_enabled else None,
            })

        # ===== 电子栅栏配置 =====
        @app.route("/api/geofence")
        def get_geofence():
            """电子栅栏配置"""
            geo = self.tracker.geofence
            return jsonify({
                "site_name": geo.config["site_geofence"]["name"],
                "site_center": geo.config["site_geofence"]["center"],
                "site_boundary": geo.config["site_geofence"]["boundary"],
                "sub_zones": geo.config.get("sub_zones", []),
            })

        # ===== 事件日志 =====
        @app.route("/api/events")
        def get_events():
            """最近事件日志"""
            limit = int(request.args.get("limit", 50))
            return jsonify(self.event_log[-limit:])

        # ===== 健康检查 =====
        @app.route("/api/health")
        def health():
            return jsonify({
                "ok": True,
                "uptime": time.time(),
                "workers_registered": len(self.tracker.workers_db.get("workers", [])),
                "workers_with_status": len(self.tracker.worker_statuses),
                "notify": self.notify_enabled,
                "storage": self.storage_enabled,
                "db_path": self.db_path if self.storage_enabled else None,
                "teams": len(self.tracker.workers_db.get("teams", {})),
            })


# ============================================================
# 主函数
# ============================================================

def main():
    parser = argparse.ArgumentParser(
        description="智慧工地 - 手机定位 API 服务器",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
示例:
  # 启动服务器 (默认端口 8090)
  python scripts/gps_server.py

  # ★ 生产模式: 持久化 + 飞书通知 + 班组考勤API
  python scripts/gps_server.py --storage --notify --port 8090

  # 指定端口 + 启用通知
  python scripts/gps_server.py --port 8080 --notify

  # 仅内网访问
  python scripts/gps_server.py --host 127.0.0.1 --port 8090

  # 自定义数据库路径
  python scripts/gps_server.py --storage --db runs/data/gps_live.db

手机端使用:
  1. 工地 WiFi 下, 手机浏览器打开 http://服务器IP:8090
  2. 输入手机号验证身份
  3. 点击「开始定位上报」授权 GPS
  4. 系统自动 10 秒上报一次位置
        """,
    )

    parser.add_argument("--host", type=str, default="0.0.0.0",
                        help="监听地址")
    parser.add_argument("--port", type=int, default=8090,
                        help="监听端口")
    parser.add_argument("--workers-config", type=str,
                        default="configs/workers.json",
                        help="工人配置文件")
    parser.add_argument("--geofence-config", type=str,
                        default="configs/site_geofence.json",
                        help="电子栅栏配置文件")
    parser.add_argument("--notify", action="store_true",
                        help="启用飞书通知 (电子栅栏告警自动逐级推送)")
    parser.add_argument("--personnel-config", type=str,
                        default="configs/personnel.json",
                        help="飞书人员/告警规则配置")
    parser.add_argument("--storage", action="store_true",
                        help="启用 SQLite 持久化 (定位历史/事件/告警落库)")
    parser.add_argument("--db", type=str, default="runs/data/site.db",
                        help="SQLite 数据库路径 (配合 --storage 使用)")
    parser.add_argument("--debug", action="store_true",
                        help="调试模式")

    args = parser.parse_args()

    app = Flask(__name__)
    server = PositioningServer(
        workers_config=args.workers_config,
        geofence_config=args.geofence_config,
        personnel_config=args.personnel_config,
        notify_enabled=args.notify,
        storage_enabled=args.storage,
        db_path=args.db,
    )
    server.register_routes(app)

    print(f"\n{'='*60}")
    print(f"  智慧工地 - 手机定位 API 服务器")
    print(f"{'='*60}")
    print(f"  监听地址: http://{args.host}:{args.port}")
    print(f"  工人花名册: {args.workers_config}  "
          f"({len(server.tracker.workers_db.get('workers',[]))} 人 / "
          f"{len(server.tracker.workers_db.get('teams',{}))} 个班组)")
    print(f"  电子栅栏:   {args.geofence_config}")
    print(f"  飞书通知:   {'✅ 开启' if args.notify else '关闭'}")
    print(f"  SQLite存储: {'✅ 开启 → ' + args.db if args.storage else '关闭'}")
    print(f"")
    print(f"  API 接口:")
    print(f"    POST /api/location/report      手机GPS上报")
    print(f"    GET  /api/location/status      所有工人状态")
    print(f"    GET  /api/location/worker/:id  单个工人状态")
    print(f"    GET  /api/stats/teams          班组统计 (含出勤率/迟到/危险区)")
    print(f"    GET  /api/stats/summary        项目总览 (含各班组人数与总工人数)")
    print(f"    GET  /api/geofence             电子栅栏")
    print(f"    GET  /api/workers              工人列表")
    print(f"    GET  /api/events               事件日志")
    print(f"    GET  /api/health               健康检查")
    print(f"")
    print(f"  手机端访问: http://服务器IP:{args.port}")
    print(f"  模拟测试: python scripts/worker_tracker.py --mode daily_routine")
    print(f"{'='*60}\n")

    app.run(host=args.host, port=args.port, debug=args.debug)


if __name__ == "__main__":
    main()