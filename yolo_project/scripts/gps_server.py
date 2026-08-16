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

    def __init__(self, workers_config="configs/workers.json",
                 geofence_config="configs/site_geofence.json",
                 personnel_config="configs/personnel.json",
                 notify_enabled=False):
        self.tracker = WorkerTracker(workers_config, geofence_config)
        self.notifier = LarkNotifier(personnel_config) if notify_enabled else None
        self.notify_enabled = notify_enabled

        # 事件日志
        self.event_log = []  # 最近 200 条

        # 注册通知回调
        if self.notifier:
            self.tracker.on("enter_danger", self._on_enter_danger)
            self.tracker.on("leave_site", self._on_leave_site)

    def _on_enter_danger(self, worker, status, zone_name, **kwargs):
        self._log_event("danger", worker["name"], worker["team"],
                        f"进入危险区: {zone_name}")
        if self.notifier:
            self.notifier.send_alarm("intrusion", zone_name=zone_name)

    def _on_leave_site(self, worker, status, dist_to_site, **kwargs):
        self._log_event("leave", worker["name"], worker["team"],
                        f"离开工地 ({dist_to_site:.0f}m)")

    def _log_event(self, etype, name, team, msg):
        self.event_log.append({
            "time": datetime.now().strftime("%H:%M:%S"),
            "type": etype,
            "name": name,
            "team": team,
            "message": msg,
        })
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

            return jsonify({
                "ok": True,
                "name": worker["name"],
                "team": worker["team"],
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
            """班组统计"""
            return jsonify(self.tracker.get_team_stats())

        # ===== 总览统计 =====
        @app.route("/api/stats/summary")
        def get_summary():
            """总览统计"""
            stats = self.tracker.get_team_stats()
            return jsonify({
                "total_workers": stats["total_workers"],
                "on_site": stats["on_site"],
                "off_site": stats["off_site"],
                "updated_at": stats["updated_at"],
                "on_site_rate": round(stats["on_site"] / stats["total_workers"] * 100, 1)
                    if stats["total_workers"] > 0 else 0,
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
                "workers": len(self.tracker.worker_statuses),
                "notify": self.notify_enabled,
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

  # 指定端口 + 启用通知
  python scripts/gps_server.py --port 8080 --notify

  # 仅内网访问
  python scripts/gps_server.py --host 127.0.0.1 --port 8090

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
                        help="启用飞书通知")
    parser.add_argument("--personnel-config", type=str,
                        default="configs/personnel.json",
                        help="飞书人员配置")
    parser.add_argument("--debug", action="store_true",
                        help="调试模式")

    args = parser.parse_args()

    app = Flask(__name__)
    server = PositioningServer(
        workers_config=args.workers_config,
        geofence_config=args.geofence_config,
        personnel_config=args.personnel_config,
        notify_enabled=args.notify,
    )
    server.register_routes(app)

    print(f"\n{'='*60}")
    print(f"  智慧工地 - 手机定位 API 服务器")
    print(f"{'='*60}")
    print(f"  监听地址: http://{args.host}:{args.port}")
    print(f"  飞书通知: {'开启' if args.notify else '关闭'}")
    print(f"")
    print(f"  API 接口:")
    print(f"    POST /api/location/report      手机GPS上报")
    print(f"    GET  /api/location/status      所有工人状态")
    print(f"    GET  /api/location/worker/:id  单个工人状态")
    print(f"    GET  /api/stats/teams          班组统计")
    print(f"    GET  /api/stats/summary        总览")
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