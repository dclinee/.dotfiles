# -*- coding: utf-8 -*-
"""
scripts/dashboard_api.py — 智慧工地可视化看板 Dashboard

统一聚合 5 类数据源:
    1) 告警 alarms        (SQLite alarms 表)
    2) 检测统计 detections (SQLite detections 表, 每小时聚合)
    3) 工人定位 workers    (可选 gps_server.PositioningServer 内存状态)
    4) 照片/训练 photos + training_runs (SQLite P2 表)
    5) 通用事件 events

API 列表 (所有均为 GET):
    /
        → 返回单文件自包含 Dashboard HTML (ECharts CDN, 无 npm 依赖)

    /api/summary
        → 顶部 KPI: 今日告警/7天趋势, 在岗人数, 合规率,
                   今日上传, 最新模型 mAP50, 训练次数

    /api/alarms?limit=50&offset=0&level=&type=&days=7
        → 最新告警列表 + 数量分布

    /api/detections?hours=24&camera_id=
        → 小时级检测趋势 (折线图数据)

    /api/workers
        → 班组考勤统计 (可选: 需将 gps_server 注入 create_dashboard_app)

    /api/photos?status=&limit=20&offset=
        → 流水线中各照片状态 (与 P2 auto_retrain 共享 storage)

    /api/trainings?limit=10
        → 训练 run 历史, 画 mAP 趋势

    /api/events?limit=30&event_type=
        → 通用事件 (geofence 入侵、电子栅栏离开工地等)
"""

from __future__ import annotations

import json
import logging
import os
import threading
from datetime import datetime, timedelta
from pathlib import Path
from typing import Dict, List, Optional, Any

from flask import Flask, jsonify, request, render_template_string

from utils.storage import SiteDatabase

logger = logging.getLogger("dashboard")

# =========================================================================
# 1) Dashboard Service: 聚合 SQL 拼数
# =========================================================================
class DashboardService:
    """封装所有"拼数"逻辑, 与 Flask 解耦, 方便单测/CLI 复用."""

    def __init__(self, storage: SiteDatabase, gps_server=None):
        self.storage = storage
        self.gps_server = gps_server  # 可选: gps_server.PositioningServer

    # ----- 今日/7 天告警 ------------------------------------------------
    def alarms_kpi(self, days: int = 7) -> dict:
        db = self.storage
        today = datetime.now().strftime('%Y-%m-%d')
        cutoff = (datetime.now() - timedelta(days=days - 1)).strftime('%Y-%m-%d')
        rows = db.query_alarms(limit=5000)  # days 过滤在这里手工做

        today_cnt = 0
        by_level: Dict[str, int] = {}
        by_type: Dict[str, int] = {}
        # 过去 days 天每日趋势
        day_buckets = {}
        for i in range(days):
            d = (datetime.now() - timedelta(days=days - 1 - i)).strftime('%Y-%m-%d')
            day_buckets[d] = 0
        for r in rows:
            ts = r.get("created_at") or ""
            day = ts[:10] if len(ts) >= 10 else ""
            if day >= cutoff and day in day_buckets:
                day_buckets[day] = day_buckets.get(day, 0) + 1
            if day == today:
                today_cnt += 1
                lv = r.get("level") or "info"
                by_level[lv] = by_level.get(lv, 0) + 1
                tp = r.get("alarm_type") or "other"
                by_type[tp] = by_type.get(tp, 0) + 1
        return {
            "today_count": today_cnt,
            "last_7_days": [{"date": k, "count": v} for k, v in day_buckets.items()],
            "by_level_today": by_level,
            "by_type_today": by_type,
        }

    # ----- 今日检测 + 合规率 --------------------------------------------
    def detection_kpi(self) -> dict:
        db = self.storage
        today_sum = db.get_daily_summary() or {}
        # 合规率公式: 有帽人数/(总人数-无帽) 的替代: helmet_compliance 已在 detections 表里有 AVG
        # 这里直接把今日小时级算全局:
        persons_total = today_sum.get("total_persons") or 0
        no_helmets = today_sum.get("total_no_helmets") or 0
        no_vests = today_sum.get("total_no_vests") or 0
        intrusions = today_sum.get("total_intrusions") or 0
        helmet_rate = (
            max(0.0, (persons_total - no_helmets)) / persons_total
            if persons_total > 0 else None
        )
        vest_rate = (
            max(0.0, (persons_total - no_vests)) / persons_total
            if persons_total > 0 else None
        )
        return {
            "total_persons_today": persons_total,
            "no_helmets_today": no_helmets,
            "no_vests_today": no_vests,
            "intrusions_today": intrusions,
            "helmet_compliance": round(helmet_rate, 4) if helmet_rate is not None else None,
            "vest_compliance": round(vest_rate, 4) if vest_rate is not None else None,
        }

    # ----- 最新模型 & 训练 ----------------------------------------------
    def training_kpi(self) -> dict:
        runs = self.storage.query_training_runs(limit=3)
        if not runs:
            return {"latest_run": None, "total_runs": 0,
                    "best_map50": None, "current_model": None}
        latest = runs[0]
        best = max([r.get("map50") or 0 for r in runs]) or None
        return {
            "latest_run": {
                "id": latest.get("id"),
                "status": latest.get("status"),
                "created_at": latest.get("created_at"),
                "finished_at": latest.get("finished_at"),
                "map50": latest.get("map50"),
                "base_model": latest.get("base_model"),
                "new_images": latest.get("new_images"),
                "total_images": latest.get("total_images"),
                "epochs": latest.get("epochs"),
                "output_model": latest.get("output_model"),
            },
            "total_runs": len(runs),
            "best_map50": best,
            "current_model": latest.get("output_model") if latest.get("status") == "success" else None,
        }

    # ----- 照片 KPI -----------------------------------------------------
    def photos_kpi(self) -> dict:
        by_status = self.storage.count_photos_by_status()
        today = datetime.now().strftime('%Y-%m-%d')
        # 今日上传数 = query_photos(status=None, 手工过滤今天)
        today_cnt = 0
        for p in self.storage.query_photos(status=None, limit=5000):
            if (p.get("uploaded_at") or "")[:10] == today:
                today_cnt += 1
        return {
            "today_uploaded": today_cnt,
            "by_status": by_status,
            "pending_review": by_status.get("need_review", 0) + by_status.get("labeled", 0),
            "pending_train": by_status.get("reviewed", 0),
            "total_trained": by_status.get("trained", 0),
        }

    # ----- 工人 GPS (可选) ---------------------------------------------
    def workers_kpi(self) -> dict:
        if self.gps_server is None:
            return {"gps_enabled": False}
        gps = self.gps_server
        # 班组考勤 (gps_server 已经实现 /api/workers/attendance 数据)
        try:
            attendance = gps._build_attendance_summary()
        except Exception as e:  # 老版本 gps_server 可能无此方法
            logger.warning("gps_server._build_attendance_summary 失败: %s", e)
            attendance = {"attendance_rate": None, "teams": {}}
        # 实时在岗统计
        try:
            live = gps._summarize_workers_live()
        except Exception as e:
            logger.warning("gps_server._summarize_workers_live 失败: %s", e)
            live = {"online_count": 0, "in_danger": [], "leaving": [], "teams_live": {}}
        return {
            "gps_enabled": True,
            "attendance_rate": attendance.get("attendance_rate"),
            "expected_count": attendance.get("expected_count"),
            "present_count": attendance.get("present_count"),
            "teams_attendance": attendance.get("teams") or {},
            "online_count": live.get("online_count", 0),
            "in_danger_count": len(live.get("in_danger") or []),
            "leaving_site_count": len(live.get("leaving") or []),
            "teams_live": live.get("teams_live") or {},
        }

    # ----- 组装 /api/summary --------------------------------------------
    def api_summary(self) -> dict:
        ak = self.alarms_kpi(days=7)
        dk = self.detection_kpi()
        tk = self.training_kpi()
        pk = self.photos_kpi()
        wk = self.workers_kpi()
        return {
            "generated_at": datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
            "alarms": ak,
            "detection": dk,
            "training": tk,
            "photos": pk,
            "workers": wk,
            "db_stats": self.storage.get_db_stats(),
        }

    # ----- 小时级检测趋势 -----------------------------------------------
    def api_detections_hourly(self, hours: int = 24, camera_id: Optional[str] = None) -> list:
        rows = self.storage.query_detections(camera_id=camera_id, hours=hours)
        # 按小时升序返回 (detections 表是 DESC LIMIT, 这里再倒回来)
        return sorted(rows, key=lambda r: r.get("hour") or "")


# =========================================================================
# 2) Flask 路由
# =========================================================================
def create_dashboard_app(storage: SiteDatabase, gps_server=None) -> Flask:
    service = DashboardService(storage, gps_server=gps_server)
    app = Flask(__name__)

    # ---------- 页面 --------------------------------------------------
    @app.get("/")
    def index():
        return render_template_string(_DASHBOARD_HTML_TEMPLATE)

    # ---------- KPI ---------------------------------------------------
    @app.get("/api/summary")
    def api_summary():
        return jsonify({"ok": True, "data": service.api_summary()})

    # ---------- 告警 --------------------------------------------------
    @app.get("/api/alarms")
    def api_alarms():
        limit = int(request.args.get("limit", 50))
        offset = int(request.args.get("offset", 0))
        level = request.args.get("level") or None
        alarm_type = request.args.get("type") or None
        days = int(request.args.get("days", 7))
        rows = storage.query_alarms(limit=limit + 500, offset=0)  # 全拿再手工过滤
        cutoff = (datetime.now() - timedelta(days=days)).strftime('%Y-%m-%d %H:%M:%S')
        out = []
        for r in rows:
            if level and r.get("level") != level:
                continue
            if alarm_type and r.get("alarm_type") != alarm_type:
                continue
            if (r.get("created_at") or "") < cutoff:
                continue
            out.append(r)
            if len(out) >= limit + offset:
                break
        total = len(out)
        out = out[offset: offset + limit]
        # 同时返回分布 (用于饼图)
        by_level: Dict[str, int] = {}
        by_type: Dict[str, int] = {}
        for r in storage.query_alarms(limit=5000):
            if (r.get("created_at") or "") < cutoff:
                continue
            lv = r.get("level") or "info"
            tp = r.get("alarm_type") or "other"
            by_level[lv] = by_level.get(lv, 0) + 1
            by_type[tp] = by_type.get(tp, 0) + 1
        return jsonify({
            "ok": True,
            "total": total,
            "rows": out,
            "distributions": {"by_level": by_level, "by_type": by_type},
        })

    # ---------- 小时检测趋势 -----------------------------------------
    @app.get("/api/detections")
    def api_detections():
        hours = int(request.args.get("hours", 24))
        camera_id = request.args.get("camera_id") or None
        rows = service.api_detections_hourly(hours=hours, camera_id=camera_id)
        return jsonify({"ok": True, "rows": rows})

    # ---------- 工人 --------------------------------------------------
    @app.get("/api/workers")
    def api_workers():
        return jsonify({"ok": True, "data": service.workers_kpi()})

    # ---------- 照片 --------------------------------------------------
    @app.get("/api/photos")
    def api_photos():
        status = request.args.get("status") or None
        limit = int(request.args.get("limit", 20))
        offset = int(request.args.get("offset", 0))
        rows = storage.query_photos(status=status, limit=limit, offset=offset)
        # 查 DB 总数，避免 query_photos 没有 total_count 字段
        by_st = storage.count_photos_by_status()
        total = sum(by_st.values()) if status is None else by_st.get(status, 0)
        return jsonify({
            "ok": True, "total": total, "rows": rows,
            "by_status": by_st,
        })

    # ---------- 训练 --------------------------------------------------
    @app.get("/api/trainings")
    def api_trainings():
        limit = int(request.args.get("limit", 10))
        rows = storage.query_training_runs(limit=limit)
        # 串一下带的 metrics (JSON 字符串 → 解析失败就原样带字符串)
        for r in rows:
            if r.get("metrics"):
                try:
                    r["metrics"] = json.loads(r["metrics"])
                except Exception:
                    pass
        return jsonify({"ok": True, "rows": rows})

    # ---------- 事件 --------------------------------------------------
    @app.get("/api/events")
    def api_events():
        limit = int(request.args.get("limit", 30))
        event_type = request.args.get("event_type") or None
        rows = storage.query_events(event_type=event_type, limit=limit)
        return jsonify({"ok": True, "rows": rows})

    return app


# =========================================================================
# 3) 单文件自包含 Dashboard HTML 模板 (ECharts CDN, 纯 JS, 无需构建)
# =========================================================================
_DASHBOARD_HTML_TEMPLATE = """
<!doctype html>
<html lang="zh-CN">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width,initial-scale=1" />
<title>智慧工地 · 安全监控看板</title>
<script src="https://cdn.jsdelivr.net/npm/echarts@5.5.0/dist/echarts.min.js"></script>
<style>
  :root{
    --bg:#0b1020; --panel:#151a2e; --line:#242b48;
    --pri:#4f8cff; --ok:#23c28a; --warn:#f5a623; --err:#ef4444; --info:#60a5fa;
    --tx:#e6ebff; --tx2:#8a93b7;
  }
  *{box-sizing:border-box}
  body{margin:0;background:linear-gradient(180deg,#080c1b,#0b1020 30%,#0b1020);
       color:var(--tx);font:14px/1.5 -apple-system,"PingFang SC","Segoe UI",sans-serif}
  header{display:flex;align-items:center;justify-content:space-between;
         padding:16px 24px;border-bottom:1px solid var(--line)}
  header .title{font-size:20px;font-weight:600;letter-spacing:1px}
  header .title b{color:var(--pri)}
  header .meta{color:var(--tx2);font-size:12px}
  header .meta span{margin-left:16px}
  main{padding:20px 24px;display:grid;gap:16px;
       grid-template-columns:repeat(12,1fr)}
  .kpis{grid-column:1 / -1;display:grid;gap:12px;
        grid-template-columns:repeat(auto-fit,minmax(180px,1fr))}
  .kpi{background:var(--panel);border:1px solid var(--line);border-radius:12px;
       padding:16px 18px}
  .kpi .label{color:var(--tx2);font-size:12px}
  .kpi .value{font-size:26px;font-weight:600;margin-top:6px}
  .kpi .sub{color:var(--tx2);font-size:12px;margin-top:4px}
  .kpi.ok .value{color:var(--ok)} .kpi.warn .value{color:var(--warn)}
  .kpi.err .value{color:var(--err)} .kpi.info .value{color:var(--info)}
  .card{background:var(--panel);border:1px solid var(--line);border-radius:12px;
        padding:14px 16px;min-height:300px;display:flex;flex-direction:column}
  .card h3{margin:0 0 10px 0;font-size:14px;font-weight:600;
           color:var(--tx);display:flex;align-items:center;justify-content:space-between}
  .card h3 small{color:var(--tx2);font-weight:400}
  .chart{flex:1;min-height:260px}
  .g1{grid-column:span 8} .g2{grid-column:span 4}
  .g3{grid-column:span 6} .g4{grid-column:span 6}
  .g5{grid-column:1 / -1}
  table{width:100%;border-collapse:collapse;font-size:13px}
  th,td{padding:8px 10px;border-bottom:1px solid var(--line);text-align:left}
  th{color:var(--tx2);font-weight:500;background:#10152a}
  tr:hover td{background:#121830}
  .tag{display:inline-block;padding:2px 8px;border-radius:999px;font-size:11px}
  .t-high{background:rgba(239,68,68,.15);color:#fca5a5}
  .t-med {background:rgba(245,166,35,.15);color:#fcd34d}
  .t-low {background:rgba(96,165,250,.15);color:#93c5fd}
  .t-ok  {background:rgba(35,194,138,.15);color:#6ee7b7}
  .pill{padding:2px 8px;border-radius:6px;background:#1c2442;color:#cfd6f5;
        display:inline-block;font-size:12px;margin:2px 2px 0 0}
  .scroll{max-height:380px;overflow:auto}
  .rows{display:flex;gap:12px;flex-wrap:wrap}
  footer{padding:14px 24px;color:var(--tx2);font-size:12px;text-align:center}
</style>
</head>
<body>
<header>
  <div class="title">🏗️ 智慧工地 · <b>安全监控看板</b></div>
  <div class="meta">
    <span id="clock"></span>
    <span>自动刷新 <select id="refresh"><option value="0">关闭</option>
                       <option value="10" selected>10s</option>
                       <option value="30">30s</option>
                       <option value="60">60s</option></select></span>
    <button onclick="loadAll()">🔄 立即刷新</button>
  </div>
</header>
<main>
  <!-- KPI -->
  <section class="kpis" id="kpis"></section>

  <!-- 图表 2+1 -->
  <section class="card g1"><h3>告警趋势 · 近 7 天 <small>条 = 每日告警数</small></h3><div id="cAlarmTrend" class="chart"></div></section>
  <section class="card g2"><h3>告警分布 <small>近 7 天按级别/类型</small></h3><div id="cAlarmDist" class="chart"></div></section>

  <section class="card g3"><h3>24h 检测趋势 <small>每小时 人员 / 无帽 / 入侵</small></h3><div id="cDetect" class="chart"></div></section>
  <section class="card g4"><h3>训练 mAP50 趋势 <small>历次自动训练</small></h3><div id="cTrain" class="chart"></div></section>

  <!-- 班组考勤 -->
  <section class="card g3"><h3>班组在岗 <small>实到 / 应到 + 出勤率</small></h3><div id="cTeam" class="chart"></div></section>
  <section class="card g4"><h3>照片状态分布 <small>自动训练流水线</small></h3><div id="cPhotos" class="chart"></div></section>

  <!-- 列表 -->
  <section class="card g5">
    <h3>最新告警 <small>最多 30 条, 近 7 天</small>
      <span class="rows" id="alarmStats"></span></h3>
    <div class="scroll"><table id="tblAlarms"></table></div>
  </section>

  <section class="card g5">
    <h3>通用事件日志 <small>电子栅栏 / 离开工地 / 训练触发等, 最多 30 条</small></h3>
    <div class="scroll"><table id="tblEvents"></table></div>
  </section>

  <section class="card g5">
    <h3>训练记录 <small>最多 10 条</small></h3>
    <div class="scroll"><table id="tblTrain"></table></div>
  </section>
</main>
<footer>智慧工地 YOLO Demo · Dashboard · 单文件 (ECharts CDN) · 数据来自 SQLite + 可选 GPS 服务</footer>

<script>
const byId = id => document.getElementById(id);
let charts = {};
function initCharts(){
  ['cAlarmTrend','cAlarmDist','cDetect','cTrain','cTeam','cPhotos'].forEach(id=>{
    charts[id] = echarts.init(byId(id), null, {renderer:'canvas'});
  });
  window.addEventListener('resize', ()=>Object.values(charts).forEach(c=>c.resize()));
}

function clockTick(){
  const d = new Date();
  byId('clock').textContent = d.toLocaleString('zh-CN',{hour12:false});
}

// ---------- KPI 渲染 ----------
function kpiCard(label,value,sub,cls='info'){
  return `<div class="kpi ${cls}"><div class="label">${label}</div>
     <div class="value">${value}</div><div class="sub">${sub||'　'}</div></div>`;
}
function fmtPct(v){ return v==null?'-':(Math.round(v*1000)/10)+'%'; }
function renderKpis(s){
  const a=s.alarms,d=s.detection,t=s.training,p=s.photos,w=s.workers,db=s.db_stats||{};
  const gps = w.gps_enabled;
  let html = '';
  html += kpiCard('今日告警', a.today_count,
    `${a.by_level_today.high||0} 高 · ${a.by_level_today.medium||0} 中 · ${a.by_level_today.low||0} 低`,
    a.today_count>10?'err':(a.today_count>3?'warn':'ok'));
  html += kpiCard('安全帽合规率', fmtPct(d.helmet_compliance),
    `人员 ${d.total_persons_today} · 未戴 ${d.no_helmets_today}`,
    (d.helmet_compliance??0)>=0.95?'ok':((d.helmet_compliance??0)>=0.8?'warn':'err'));
  html += kpiCard('反光衣合规率', fmtPct(d.vest_compliance),
    `未穿 ${d.no_vests_today} · 入侵 ${d.intrusions_today}`,
    (d.vest_compliance??0)>=0.95?'ok':((d.vest_compliance??0)>=0.8?'warn':'err'));
  html += kpiCard(gps?'在线工人':'在线工人 (GPS 未接)',
    gps?w.online_count:'-',
    gps?`危险区 ${w.in_danger_count} · 离工地 ${w.leaving_site_count}`:'将 gps_server 注入即可联动',
    'info');
  html += kpiCard('今日照片上传', p.today_uploaded,
    `待审核 ${p.pending_review} · 待训练 ${p.pending_train} · 已训练 ${p.total_trained}`,
    p.today_uploaded>0?'info':'ok');
  html += kpiCard('当前模型 mAP50',
    t.latest_run?(t.latest_run.map50!=null?Math.round(t.latest_run.map50*1000)/1000:'运行中'):'-',
    t.latest_run
      ? `Base: ${(t.latest_run.base_model||'').split('/').pop()||'-'} · 新图 ${t.latest_run.new_images||0}`
      : '暂无训练记录 · 请先跑 P2c 自动训练',
    'ok');
  html += kpiCard('累计训练 run', t.total_runs,
    `历史最佳 mAP50: ${t.best_map50!=null?Math.round(t.best_map50*1000)/1000:'-'}`,
    'info');
  html += kpiCard('DB 规模', `${db.db_size_mb||0} MB`,
    `alarms ${db.alarms||0} · detections ${db.detections||0} · photos ${db.photos||0}`,
    'info');
  byId('kpis').innerHTML = html;
}

// ---------- 图表 ----------
function renderAlarmTrend(data){
  const xs = data.map(d=>d.date.slice(5));
  const ys = data.map(d=>d.count);
  charts.cAlarmTrend.setOption({
    tooltip:{trigger:'axis'},
    grid:{left:40,right:20,top:20,bottom:30},
    xAxis:{type:'category',data:xs,axisLine:{lineStyle:{color:'#39416a'}}},
    yAxis:{type:'value',splitLine:{lineStyle:{color:'#1c2442'}}},
    series:[{type:'bar',data:ys,itemStyle:{color:'#ef4444',borderRadius:[4,4,0,0]},
             markLine:{data:[{type:'average',name:'avg'}],lineStyle:{color:'#f5a623'}}}]
  });
}
function renderAlarmDist(dist){
  const lv = Object.entries(dist.by_level||{}).map(([k,v])=>({name:k,value:v}));
  charts.cAlarmDist.setOption({
    tooltip:{trigger:'item'},
    legend:{bottom:0,textStyle:{color:'#cfd6f5'}},
    series:[{type:'pie',radius:['45%','70%'],center:['50%','45%'],
      label:{color:'#cfd6f5',formatter:'{b}\n{d}%'},
      data:lv.length?lv:[{name:'无数据',value:1,itemStyle:{color:'#2a3259'}}]
    }]
  });
}
function renderDetections(rows){
  const xs = rows.map(r=>r.hour?.slice(5)||'');
  charts.cDetect.setOption({
    tooltip:{trigger:'axis'},
    legend:{textStyle:{color:'#cfd6f5'}},
    grid:{left:40,right:20,top:40,bottom:30},
    xAxis:{type:'category',data:xs,axisLine:{lineStyle:{color:'#39416a'}}},
    yAxis:[{type:'value',splitLine:{lineStyle:{color:'#1c2442'}}},
           {type:'value',splitLine:{show:false},axisLabel:{formatter:'{value}%'}}],
    series:[
      {name:'总人数',type:'line',smooth:true,data:rows.map(r=>r.total_persons||0),itemStyle:{color:'#60a5fa'}},
      {name:'未戴帽',type:'line',smooth:true,data:rows.map(r=>r.total_no_helmets||0),itemStyle:{color:'#ef4444'}},
      {name:'入侵次数',type:'bar',data:rows.map(r=>r.intrusion_count||0),itemStyle:{color:'#f5a623'},yAxisIndex:1},
    ]
  });
}
function renderTraining(rows){
  const xs = rows.map(r=>r.created_at?.slice(5,16)||'');
  charts.cTrain.setOption({
    tooltip:{trigger:'axis'},
    legend:{textStyle:{color:'#cfd6f5'}},
    grid:{left:40,right:20,top:40,bottom:30},
    xAxis:{type:'category',data:xs,axisLine:{lineStyle:{color:'#39416a'}}},
    yAxis:{type:'value',min:0,max:1,splitLine:{lineStyle:{color:'#1c2442'}},axisLabel:{formatter:'{value}'}},
    series:[
      {name:'mAP50',type:'line',smooth:true,
       data:rows.map(r=>r.map50),itemStyle:{color:'#23c28a'},
       areaStyle:{color:'rgba(35,194,138,.15)'}},
      {name:'新图量',type:'bar',
       data:rows.map(r=>r.new_images||0),itemStyle:{color:'#60a5fa',opacity:.6}},
    ]
  });
}
function renderTeams(teams, teamsLive){
  // teams: {teamName: {expected, present}}  teamsLive: {teamName: count}
  const names = Array.from(new Set([...Object.keys(teams||{}), ...Object.keys(teamsLive||{})]));
  charts.cTeam.setOption({
    tooltip:{trigger:'axis',axisPointer:{type:'shadow'}},
    legend:{textStyle:{color:'#cfd6f5'}},
    grid:{left:80,right:20,top:40,bottom:30},
    xAxis:{type:'value',splitLine:{lineStyle:{color:'#1c2442'}}},
    yAxis:{type:'category',data:names,axisLine:{lineStyle:{color:'#39416a'}}},
    series:[
      {name:'应到',type:'bar',stack:'a',data:names.map(n=>(teams[n]?.expected||0)),itemStyle:{color:'#2a3259'}},
      {name:'实到',type:'bar',data:names.map(n=>(teams[n]?.present||teamsLive[n]||0)),itemStyle:{color:'#23c28a'}},
    ]
  });
}
function renderPhotos(byStatus){
  const order=['uploaded','labeling','labeled','need_review','reviewed','training','trained','rejected'];
  const entries = order.filter(k=>k in byStatus).map(k=>({name:k,value:byStatus[k]}));
  const colors = {uploaded:'#60a5fa',labeling:'#a78bfa',labeled:'#23c28a',
                  need_review:'#f5a623',reviewed:'#4f8cff',training:'#8b5cf6',
                  trained:'#10b981',rejected:'#6b7280'};
  charts.cPhotos.setOption({
    tooltip:{trigger:'item'},
    grid:{left:100,right:20,top:10,bottom:10},
    xAxis:{type:'value'},
    yAxis:{type:'category',data:entries.map(e=>e.name),inverse:true,axisLine:{lineStyle:{color:'#39416a'}}},
    series:[{type:'bar',data:entries.map(e=>({value:e.value,itemStyle:{color:colors[e.name]||'#4f8cff'},
      label:{show:true,position:'right',color:'#cfd6f5',formatter:'{c}'}}))}]
  });
}

// ---------- 列表 ----------
function levelTag(lv){
  if (lv==='high') return '<span class="tag t-high">高</span>';
  if (lv==='medium') return '<span class="tag t-med">中</span>';
  if (lv==='low') return '<span class="tag t-low">低</span>';
  return '<span class="tag t-ok">'+(lv||'-')+'</span>';
}
function statusPill(s){
  const map={
    uploaded:'info',labeling:'info',labeled:'ok',need_review:'warn',
    reviewed:'info',training:'med',trained:'ok',rejected:'err',failed:'err',
    success:'ok',running:'info'
  };
  return `<span class="pill" style="background:${
    s==='trained'||s==='labeled'||s==='success'?'rgba(35,194,138,.15)':
    s==='running'||s==='training'||s==='uploaded'||s==='reviewed'||s==='labeling'?'rgba(96,165,250,.15)':
    s==='need_review'||s==='running'?'rgba(245,166,35,.15)':'rgba(107,114,128,.15)'
  }">${s||'-'}</span>`;
}
function renderAlarmTable(rows, dist){
  byId('alarmStats').innerHTML =
    Object.entries(dist.by_level||{}).map(([k,v])=>levelTag(k)+` ${k}: ${v}`).join(' ');
  const head = '<thead><tr><th>时间</th><th>级别</th><th>类型</th><th>摄像机/来源</th><th>消息</th></tr></thead>';
  const body = rows.length? rows.map(r=>`<tr>
    <td>${r.created_at||''}</td>
    <td>${levelTag(r.level)}</td>
    <td>${r.alarm_type||''}</td>
    <td>${r.camera_id||r.source||''}</td>
    <td>${r.message||''}<br/><small style="color:#8a93b7">${r.details_json||''}</small></td>
  </tr>`).join('') : `<tr><td colspan="5" style="text-align:center;color:#8a93b7;padding:24px">暂无告警 · 全绿色 ✅</td></tr>`;
  byId('tblAlarms').innerHTML = head+'<tbody>'+body+'</tbody>';
}
function renderEventTable(rows){
  const head='<thead><tr><th>时间</th><th>事件</th><th>worker_id / camera</th><th>详情</th></tr></thead>';
  const body = rows.length? rows.map(r=>`<tr>
    <td>${r.created_at||''}</td>
    <td>${r.event_type||''}</td>
    <td>${r.worker_id||r.camera_id||''}</td>
    <td>${r.message||''} <small style="color:#8a93b7">${r.details_json||''}</small></td>
  </tr>`).join('') : `<tr><td colspan="4" style="text-align:center;color:#8a93b7;padding:16px">暂无事件</td></tr>`;
  byId('tblEvents').innerHTML = head+'<tbody>'+body+'</tbody>';
}
function renderTrainTable(rows){
  const head='<thead><tr><th>id</th><th>触发时间</th><th>状态</th><th>epochs</th>'
           +'<th>新图/总量</th><th>mAP50</th><th>基础模型</th><th>输出模型</th></tr></thead>';
  const body = rows.length? rows.map(r=>`<tr>
    <td>#${r.id}</td>
    <td>${r.created_at||''}${r.finished_at?'<br/><span style="color:#8a93b7">→'+r.finished_at+'</span>':''}</td>
    <td>${statusPill(r.status)}</td>
    <td>${r.epochs||'-'}</td>
    <td>${r.new_images||0} / ${r.total_images||0}</td>
    <td>${r.map50!=null?Math.round(r.map50*1000)/1000:'-'}</td>
    <td style="max-width:160px;overflow:hidden;text-overflow:ellipsis" title="${r.base_model||''}">${(r.base_model||'').split('/').pop()||'-'}</td>
    <td style="max-width:220px;overflow:hidden;text-overflow:ellipsis" title="${r.output_model||''}">${(r.output_model||'-').split('/').pop()||'-'}</td>
  </tr>`).join('') : `<tr><td colspan="8" style="text-align:center;color:#8a93b7;padding:16px">暂无训练记录 · P2c 完成后自动出现</td></tr>`;
  byId('tblTrain').innerHTML = head+'<tbody>'+body+'</tbody>';
}

// ---------- 总加载 ----------
async function loadAll(){
  try {
    const [s,al,de,tr,ev,ph] = await Promise.all([
      fetch('/api/summary').then(r=>r.json()),
      fetch('/api/alarms?limit=30').then(r=>r.json()),
      fetch('/api/detections?hours=24').then(r=>r.json()),
      fetch('/api/trainings?limit=10').then(r=>r.json()),
      fetch('/api/events?limit=30').then(r=>r.json()),
      fetch('/api/photos?status=&limit=1').then(r=>r.json()),
    ]);
    if (s.ok) renderKpis(s.data);
    if (al.ok){ renderAlarmTable(al.rows, al.distributions); renderAlarmDist(al.distributions); }
    if (al.ok && s.ok) renderAlarmTrend(s.data.alarms.last_7_days);
    if (de.ok) renderDetections(de.rows);
    if (tr.ok){ renderTraining(tr.rows); renderTrainTable(tr.rows); }
    if (ev.ok) renderEventTable(ev.rows);
    if (ph.ok) renderPhotos(ph.by_status);
    // 工人
    if (s.ok){
      const w = s.data.workers||{};
      renderTeams(w.teams_attendance, w.teams_live);
    }
  } catch (e) {
    console.error(e);
  }
}

// 刷新周期
let _t;
function setupRefresh(){
  byId('refresh').addEventListener('change', ()=>{
    if (_t) clearInterval(_t);
    const s = parseInt(byId('refresh').value,10);
    if (s>0) _t = setInterval(loadAll, s*1000);
  });
  _t = setInterval(loadAll, 10*1000);
}

document.addEventListener('DOMContentLoaded', ()=>{
  initCharts();
  clockTick(); setInterval(clockTick, 1000);
  loadAll();
  setupRefresh();
});
</script>
</body>
</html>
"""  # noqa: E501


# =========================================================================
# 4) CLI: 独立运行 dashboard 服务
# =========================================================================
def _main():
    import argparse
    parser = argparse.ArgumentParser(description="智慧工地 Dashboard (Flask, 单页 ECharts)")
    parser.add_argument("--db", default="runs/data/site.db", help="SQLite 数据库路径")
    parser.add_argument("--host", default="0.0.0.0")
    parser.add_argument("--port", type=int, default=5001)
    parser.add_argument("--debug", action="store_true")
    args = parser.parse_args()

    logging.basicConfig(level=logging.INFO if not args.debug else logging.DEBUG,
                        format="%(asctime)s [%(levelname)s] %(name)s: %(message)s")

    db_path = Path(args.db)
    db_path.parent.mkdir(parents=True, exist_ok=True)
    storage = SiteDatabase(str(db_path))

    app = create_dashboard_app(storage, gps_server=None)
    logger.info("🚀 Dashboard 启动: http://%s:%d  (DB=%s)",
                args.host, args.port, db_path)
    app.run(host=args.host, port=args.port, debug=args.debug,
            threaded=True, use_reloader=False)


if __name__ == "__main__":
    _main()
