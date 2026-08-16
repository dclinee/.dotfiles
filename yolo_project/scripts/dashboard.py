#!/usr/bin/env python3
"""
智慧工地 - 工人实时追踪看板
展示: 各班在场人数 / 总人数 / 工人位置 / 危险区预警 / 电子栅栏状态

支持:
  - 终端实时刷新看板
  - Web 可视化看板 (Flask)
  - 飞书告警通知
"""

import argparse
import json
import os
import sys
import time
import threading
from pathlib import Path
from datetime import datetime
from collections import defaultdict

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from utils.positioning import WorkerTracker, get_tracker
from utils.notify import LarkNotifier


# ============================================================
# 终端实时看板
# ============================================================

class TerminalDashboard:
    """终端实时看板"""

    def __init__(self, tracker: WorkerTracker, notifier=None,
                 refresh_interval=5):
        self.tracker = tracker
        self.notifier = notifier
        self.refresh_interval = refresh_interval
        self.running = False

        # 注册事件回调
        if notifier:
            self.tracker.on("checkin", self._on_checkin)
            self.tracker.on("checkout", self._on_checkout)
            self.tracker.on("enter_danger", self._on_enter_danger)
            self.tracker.on("leave_site", self._on_leave_site)

    def _on_checkin(self, worker, status, time, is_late, **kwargs):
        late_str = " (迟到)" if is_late else ""
        print(f"\n  [签到] {worker['name']} ({worker['team']}) {time}{late_str}")
        if is_late and self.notifier:
            self.notifier.send_alarm(
                "no_helmet",  # 复用告警通道
                camera_id=worker.get("team", ""),
                count=1,
            )

    def _on_checkout(self, worker, status, **kwargs):
        print(f"\n  [签退] {worker['name']} ({worker['team']})")

    def _on_enter_danger(self, worker, status, zone_name, **kwargs):
        msg = f"\n  [危险] {worker['name']} ({worker['team']}) 进入 {zone_name}!"
        print(msg)
        if self.notifier:
            self.notifier.send_alarm(
                "intrusion",
                camera_id=worker.get("team", ""),
                zone_name=zone_name,
            )

    def _on_leave_site(self, worker, status, dist_to_site, **kwargs):
        print(f"\n  [离线] {worker['name']} ({worker['team']}) "
              f"离开工地 ({dist_to_site:.0f}m)")

    def _clear_screen(self):
        os.system("clear" if os.name != "nt" else "cls")

    def _render(self):
        """渲染看板"""
        self._clear_screen()
        stats = self.tracker.get_team_stats()

        print("=" * 70)
        print("  智慧工地 - 工人实时定位看板")
        print("=" * 70)
        print(f"  更新时间: {stats['updated_at']}")
        print(f"  总工人: {stats['total_workers']}  |  "
              f"●在场: {stats['on_site']}  |  "
              f"○离场: {stats['off_site']}")
        print("=" * 70)

        for team_name, team_data in stats["teams"].items():
            on_pct = (team_data["on_site"] / team_data["total"] * 100
                      if team_data["total"] > 0 else 0)
            bar = "█" * int(on_pct / 10) + "░" * (10 - int(on_pct / 10))
            print(f"\n  [{team_name}] "
                  f"{team_data.get('type', '')}  "
                  f"组长: {team_data.get('leader', 'N/A')}")
            print(f"    在场: {team_data['on_site']}/{team_data['total']} "
                  f"|{bar}| {on_pct:.0f}%")

            for w in team_data["workers"]:
                icon = "●" if w["on_site"] else "○"
                danger = "⚠" if w["in_danger"] else " "
                moving = "→" if w["is_moving"] else "·"
                zone = w["zone"] or "未定位"
                role_tag = "[组长]" if w["role"] == "team_leader" else ""
                duration = w["on_site_duration"] if w["on_site"] else ""

                print(f"    {icon} {danger} {moving} {w['name']:6s} "
                      f"{role_tag:5s} "
                      f"区域: {zone:12s} "
                      f"{duration}")

        # 危险区预警
        danger_workers = self.tracker.get_workers_in_danger_zone()
        if danger_workers:
            print(f"\n  {'='*66}")
            print(f"  ⚠ 危险区域预警: {len(danger_workers)} 人在危险区!")
            for w in danger_workers:
                print(f"     {w['name']} ({w['team']}) - {w['zone']}")

        print(f"\n{'='*70}")
        print("  按 Ctrl+C 退出")

    def run(self):
        """运行终端看板"""
        self.running = True
        print("启动工人追踪看板...")
        try:
            while self.running:
                self._render()
                time.sleep(self.refresh_interval)
        except KeyboardInterrupt:
            self.running = False
            print("\n看板已关闭")


# ============================================================
# Web 看板
# ============================================================

class WebDashboard:
    """Web 可视化看板 (Flask)"""

    def __init__(self, tracker: WorkerTracker, host="0.0.0.0", port=8090):
        self.tracker = tracker
        self.host = host
        self.port = port

    def run(self):
        try:
            from flask import Flask, jsonify, render_template_string
        except ImportError:
            print("需要安装 Flask: pip install flask")
            return

        app = Flask(__name__)
        tracker = self.tracker

        HTML_TEMPLATE = """
<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>智慧工地 - 工人追踪看板</title>
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:"Microsoft YaHei",sans-serif;background:#0f1923;color:#e0e0e0;padding:20px}
.header{text-align:center;margin-bottom:20px}
.header h1{color:#00d4ff;font-size:28px;margin-bottom:5px}
.summary{display:flex;gap:15px;justify-content:center;margin-bottom:20px;flex-wrap:wrap}
.card{background:#1a2a3a;border-radius:10px;padding:15px 25px;min-width:120px;text-align:center;border:1px solid #2a3a4a}
.card .value{font-size:36px;font-weight:bold;color:#00d4ff}
.card .label{font-size:13px;color:#8899aa;margin-top:4px}
.card.online .value{color:#00ff88}
.card.offline .value{color:#ff6b6b}
.card.danger .value{color:#ff4444}
.team-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(350px,1fr));gap:20px}
.team-card{background:#1a2a3a;border-radius:10px;border:1px solid #2a3a4a;overflow:hidden}
.team-header{padding:12px 18px;background:#223344;display:flex;justify-content:space-between;align-items:center}
.team-header h3{color:#00d4ff;font-size:16px}
.team-header .count{font-size:14px;color:#8899aa}
.worker-list{padding:5px 0}
.worker-row{display:flex;align-items:center;padding:8px 18px;border-bottom:1px solid #1a2838;gap:10px}
.worker-row:last-child{border-bottom:none}
.worker-row.onsite{border-left:3px solid #00ff88}
.worker-row.offsite{border-left:3px solid #ff6b6b;opacity:.6}
.worker-row .status-dot{width:10px;height:10px;border-radius:50%;flex-shrink:0}
.worker-row.onsite .status-dot{background:#00ff88;box-shadow:0 0 8px #00ff88}
.worker-row.offsite .status-dot{background:#ff6b6b}
.worker-row .name{font-weight:bold;min-width:60px}
.worker-row .role{font-size:12px;color:#8899aa;min-width:40px}
.worker-row .zone{font-size:12px;color:#667788}
.worker-row .duration{font-size:12px;color:#8899aa;margin-left:auto}
.worker-row .danger-tag{background:#ff4444;color:#fff;padding:1px 6px;border-radius:3px;font-size:10px}
.progress-bar{height:4px;background:#2a3a4a;border-radius:2px;margin-top:4px}
.progress-fill{height:100%;background:#00d4ff;border-radius:2px;transition:width .3s}
.refresh{text-align:center;color:#556677;font-size:12px;margin-top:15px}
.leader-tag{color:#ffaa00;font-size:12px}
</style>
</head>
<body>
<div class="header">
    <h1>智慧工地 - 工人实时定位看板</h1>
    <div class="refresh">更新时间: <span id="updateTime">--</span> | 自动刷新: 5s</div>
</div>
<div class="summary" id="summary"></div>
<div class="team-grid" id="teams"></div>
<script>
async function fetchData(){
    const resp=await fetch('/api/stats');
    const data=await resp.json();
    document.getElementById('updateTime').textContent=data.updated_at;

    const summary=document.getElementById('summary');
    summary.innerHTML=`
        <div class="card"><div class="value">${data.total_workers}</div><div class="label">总工人</div></div>
        <div class="card online"><div class="value">${data.on_site}</div><div class="label">● 在场</div></div>
        <div class="card offline"><div class="value">${data.off_site}</div><div class="label">○ 离场</div></div>
        <div class="card danger"><div class="value" id="dangerCount">--</div><div class="label">⚠ 危险区</div></div>
    `;

    const teams=document.getElementById('teams');
    teams.innerHTML='';
    let dangerTotal=0;
    for(const [name,team] of Object.entries(data.teams)){
        const pct=team.total>0?Math.round(team.on_site/team.total*100):0;
        let workersHTML=team.workers.map(w=>{
            if(w.in_danger)dangerTotal++;
            const cls=w.on_site?'onsite':'offsite';
            const dur=w.on_site_duration||'';
            const dangerTag=w.in_danger?'<span class="danger-tag">⚠危险</span>':'';
            const leaderTag=w.role==='team_leader'?'<span class="leader-tag">[组长]</span>':'';
            return `<div class="worker-row ${cls}">
                <div class="status-dot"></div>
                <span class="name">${w.name}</span>
                <span class="role">${leaderTag}</span>
                <span class="zone">${w.zone||'未定位'}</span>
                <span>${dangerTag}</span>
                <span class="duration">${dur}</span>
            </div>`;
        }).join('');

        teams.innerHTML+=`
            <div class="team-card">
                <div class="team-header">
                    <h3>${name} <span style="color:#8899aa;font-size:13px">${team.type||''}</span></h3>
                    <span class="count">组长: ${team.leader||'N/A'}</span>
                </div>
                <div style="padding:8px 18px">
                    <span style="font-size:12px;color:#8899aa">在场: ${team.on_site}/${team.total}</span>
                    <div class="progress-bar"><div class="progress-fill" style="width:${pct}%"></div></div>
                </div>
                <div class="worker-list">${workersHTML}</div>
            </div>`;
    }
    document.getElementById('dangerCount').textContent=dangerTotal;
}
fetchData();
setInterval(fetchData,5000);
</script>
</body>
</html>
"""

        @app.route("/")
        def index():
            return render_template_string(HTML_TEMPLATE)

        @app.route("/api/stats")
        def api_stats():
            return jsonify(tracker.get_team_stats())

        @app.route("/api/workers")
        def api_workers():
            return jsonify(tracker.get_on_site_workers())

        print(f"\n  Web 看板已启动: http://{self.host}:{self.port}")
        app.run(host=self.host, port=self.port, debug=False)


# ============================================================
# 命令行入口
# ============================================================

def main():
    parser = argparse.ArgumentParser(description="智慧工地 - 工人实时追踪看板")
    parser.add_argument("--workers-config", type=str,
                        default="configs/workers.json",
                        help="工人配置文件")
    parser.add_argument("--geofence-config", type=str,
                        default="configs/site_geofence.json",
                        help="电子栅栏配置文件")
    parser.add_argument("--mode", type=str, default="terminal",
                        choices=["terminal", "web", "simulate", "stats"],
                        help="运行模式: terminal=终端看板, web=Web看板, "
                             "simulate=模拟器, stats=打印统计")
    parser.add_argument("--refresh", type=int, default=5,
                        help="刷新间隔 (秒)")
    parser.add_argument("--port", type=int, default=8090,
                        help="Web 看板端口")
    parser.add_argument("--notify", action="store_true",
                        help="启用飞书告警通知")
    parser.add_argument("--personnel-config", type=str,
                        default="configs/personnel.json",
                        help="人员配置文件")

    args = parser.parse_args()

    tracker = WorkerTracker(
        workers_config_path=args.workers_config,
        geofence_config_path=args.geofence_config,
    )

    notifier = None
    if args.notify:
        notifier = LarkNotifier(args.personnel_config)

    if args.mode == "terminal":
        dashboard = TerminalDashboard(tracker, notifier, args.refresh)
        dashboard.run()

    elif args.mode == "web":
        dashboard = WebDashboard(tracker, port=args.port)
        dashboard.run()

    elif args.mode == "simulate":
        from scripts.worker_tracker import GPSSimulator
        sim = GPSSimulator(
            workers_config=args.workers_config,
            geofence_config=args.geofence_config,
        )
        sim.run(mode="daily_routine", interval=3, sim_speed=120)

    elif args.mode == "stats":
        stats = tracker.get_team_stats()
        print(f"\n总工人: {stats['total_workers']} | "
              f"在场: {stats['on_site']} | 离场: {stats['off_site']}")
        for name, team in stats["teams"].items():
            print(f"  {name}: {team['on_site']}/{team['total']} 在场")
            for w in team["workers"]:
                icon = "●" if w["on_site"] else "○"
                print(f"    {icon} {w['name']} ({w['role']}) - "
                      f"{w['zone'] or '未定位'} | {w['on_site_duration']}")


if __name__ == "__main__":
    main()