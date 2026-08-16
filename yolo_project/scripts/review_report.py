#!/usr/bin/env python3
"""
验证结果可视化复盘工具
从 video_verify.py 的输出生成可视化复盘报告

功能:
  1. 加载 report.json 生成复盘图表
  2. 违规时间线展示
  3. 合规率趋势图
  4. 违规截图拼贴
  5. HTML 交互式报告
"""

import argparse
import json
import os
import sys
from pathlib import Path
from datetime import datetime
from collections import defaultdict
import math

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))


class ReviewReport:
    """复盘报告生成器"""

    def __init__(self, report_dir):
        self.report_dir = Path(report_dir)
        self.report_json = self.report_dir / "report.json"
        self.events_jsonl = self.report_dir / "events.jsonl"
        self.violations_dir = self.report_dir / "violations"

        if not self.report_json.exists():
            raise FileNotFoundError(f"未找到报告文件: {self.report_json}")

        with open(self.report_json, "r") as f:
            self.data = json.load(f)

    def print_summary(self):
        """打印摘要"""
        s = self.data["stats"]
        print(f"\n{'='*60}")
        print(f"  验证复盘报告")
        print(f"{'='*60}")
        print(f"  视频源: {self.data['source']}")
        print(f"  检测模式: {self.data['mode']}")
        print(f"  生成时间: {self.data['generated_at']}")
        print(f"")
        print(f"  处理帧数: {s['processed_frames']}/{s['total_frames']}")
        print(f"  耗时: {s['elapsed_s']}s (FPS: {s['actual_fps']})")
        print(f"")
        print(f"  检测统计:")
        print(f"    人员: {s['total_persons']}")
        print(f"    安全帽: {s['total_helmets']}")
        print(f"    未戴安全帽: {s['total_no_helmets']}")
        print(f"    反光衣: {s['total_vests']}")
        print(f"    未穿反光衣: {s['total_no_vests']}")
        print(f"")
        print(f"  合规率:")
        print(f"    安全帽: {s['helmet_compliance_rate']}%")
        print(f"    反光衣: {s['vest_compliance_rate']}%")
        print(f"")
        print(f"  违规事件: {sum(s['violations'].values())}")
        print(f"  入侵事件: {s['intrusions']}")
        print(f"")

        # 违规时间线
        violations = self.data.get("violations", [])
        if violations:
            print(f"  违规时间线:")
            for v in violations[:20]:
                t = v["timestamp"]
                mins = int(t // 60)
                secs = int(t % 60)
                print(f"    [{mins:02d}:{secs:02d}] {v['type']} "
                      f"(conf={v['conf']:.2f})")

        print(f"{'='*60}")

    def generate_html(self, output_path=None):
        """生成 HTML 交互式报告"""
        s = self.data["stats"]
        violations = self.data.get("violations", [])
        intrusions = self.data.get("intrusions", [])

        # 违规截图
        captures_html = ""
        if self.violations_dir.exists():
            imgs = sorted(self.violations_dir.glob("*.jpg"))[:20]
            for img in imgs:
                captures_html += f'<div class="capture"><img src="{img}" loading="lazy"><span>{img.name}</span></div>'

        # 事件时间线
        timeline_html = ""
        for v in violations[:50]:
            t = v["timestamp"]
            mins = int(t // 60)
            secs = int(t % 60)
            vtype = {"no_helmet": "安全帽", "no_vest": "反光衣"}.get(v["type"], v["type"])
            timeline_html += (
                f'<div class="timeline-event violation">'
                f'<span class="time">{mins:02d}:{secs:02d}</span>'
                f'<span class="type">{vtype}违规</span>'
                f'<span class="conf">置信度: {v["conf"]:.2f}</span>'
                f'</div>'
            )

        for intr in intrusions[:50]:
            t = intr["timestamp"]
            mins = int(t // 60)
            secs = int(t % 60)
            timeline_html += (
                f'<div class="timeline-event intrusion">'
                f'<span class="time">{mins:02d}:{secs:02d}</span>'
                f'<span class="type">入侵: {intr["zone"]}</span>'
                f'</div>'
            )

        # 合规率
        helmet_rate = s["helmet_compliance_rate"]
        vest_rate = s["vest_compliance_rate"]

        html = f"""<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>智慧工地 - 验证复盘报告</title>
<style>
*{{margin:0;padding:0;box-sizing:border-box}}
body{{font-family:"Microsoft YaHei",sans-serif;background:#0f1923;color:#e0e0e0;padding:20px;max-width:1200px;margin:0 auto}}
.header{{text-align:center;margin-bottom:30px}}
.header h1{{color:#00d4ff;font-size:28px;margin-bottom:5px}}
.header .subtitle{{color:#8899aa;font-size:14px}}
.summary{{display:flex;gap:15px;justify-content:center;margin-bottom:30px;flex-wrap:wrap}}
.card{{background:#1a2a3a;border-radius:10px;padding:20px;min-width:140px;text-align:center;border:1px solid #2a3a4a}}
.card .value{{font-size:32px;font-weight:bold;color:#00d4ff}}
.card .label{{font-size:13px;color:#8899aa;margin-top:5px}}
.card.good .value{{color:#00ff88}}
.card.warn .value{{color:#ffaa00}}
.card.bad .value{{color:#ff4444}}
.rate-container{{display:flex;gap:20px;margin-bottom:30px;flex-wrap:wrap}}
.rate-card{{flex:1;min-width:300px;background:#1a2a3a;border-radius:10px;padding:20px;border:1px solid #2a3a4a}}
.rate-card h3{{color:#00d4ff;margin-bottom:15px}}
.rate-bar{{height:30px;background:#2a3a4a;border-radius:5px;overflow:hidden;position:relative}}
.rate-fill{{height:100%;border-radius:5px;display:flex;align-items:center;justify-content:center;font-weight:bold;font-size:14px;color:#fff}}
.rate-fill.good{{background:linear-gradient(90deg,#00ff88,#00cc66)}}
.rate-fill.warn{{background:linear-gradient(90deg,#ffaa00,#ff8800)}}
.rate-fill.bad{{background:linear-gradient(90deg,#ff4444,#cc0000)}}
.section{{margin-bottom:30px}}
.section h2{{color:#00d4ff;border-bottom:2px solid #2a3a4a;padding-bottom:10px;margin-bottom:15px}}
.timeline{{max-height:500px;overflow-y:auto}}
.timeline-event{{display:flex;align-items:center;padding:8px 15px;border-left:3px solid #2a3a4a;margin-bottom:5px;background:#1a2a3a;border-radius:0 5px 5px 0}}
.timeline-event.violation{{border-left-color:#ff4444}}
.timeline-event.intrusion{{border-left-color:#ff6600}}
.timeline-event .time{{font-family:monospace;color:#8899aa;min-width:60px}}
.timeline-event .type{{margin-left:15px;font-weight:bold}}
.timeline-event .conf{{margin-left:auto;font-size:12px;color:#667788}}
.captures{{display:grid;grid-template-columns:repeat(auto-fill,minmax(250px,1fr));gap:10px}}
.capture{{position:relative;border-radius:5px;overflow:hidden;border:1px solid #2a3a4a}}
.capture img{{width:100%;display:block}}
.capture span{{display:block;padding:5px;font-size:11px;color:#8899aa;background:#1a2a3a}}
table{{width:100%;border-collapse:collapse}}
th,td{{padding:10px 15px;text-align:left;border-bottom:1px solid #2a3a4a}}
th{{color:#00d4ff;font-size:13px}}
td{{font-size:14px}}
tr:hover{{background:#1a2a3a}}
</style>
</head>
<body>
<div class="header">
    <h1>智慧工地 - 验证复盘报告</h1>
    <div class="subtitle">视频: {self.data['source']} | 模式: {self.data['mode']} | {self.data['generated_at']}</div>
</div>

<div class="summary">
    <div class="card"><div class="value">{s['processed_frames']}</div><div class="label">处理帧数</div></div>
    <div class="card"><div class="value">{s['total_persons']}</div><div class="label">检测人员</div></div>
    <div class="card"><div class="value">{s['actual_fps']}</div><div class="label">实际 FPS</div></div>
    <div class="card"><div class="value">{s['elapsed_s']}s</div><div class="label">耗时</div></div>
</div>

<div class="rate-container">
    <div class="rate-card">
        <h3>安全帽佩戴率</h3>
        <div class="rate-bar">
            <div class="rate-fill {'good' if helmet_rate >= 80 else 'warn' if helmet_rate >= 50 else 'bad'}" style="width:{helmet_rate}%">
                {helmet_rate}%
            </div>
        </div>
        <div style="margin-top:10px;color:#8899aa;font-size:13px">
            佩戴: {s['total_helmets']} / 未佩戴: {s['total_no_helmets']}
        </div>
    </div>
    <div class="rate-card">
        <h3>反光衣穿戴率</h3>
        <div class="rate-bar">
            <div class="rate-fill {'good' if vest_rate >= 80 else 'warn' if vest_rate >= 50 else 'bad'}" style="width:{vest_rate}%">
                {vest_rate}%
            </div>
        </div>
        <div style="margin-top:10px;color:#8899aa;font-size:13px">
            穿着: {s['total_vests']} / 未穿: {s['total_no_vests']}
        </div>
    </div>
</div>

<div class="section">
    <h2>检测统计</h2>
    <table>
        <tr><th>类别</th><th>数量</th><th>占比</th></tr>
        <tr><td>人员 (person)</td><td>{s['total_persons']}</td><td>-</td></tr>
        <tr><td>安全帽 (helmet)</td><td>{s['total_helmets']}</td><td>{calc_pct(s['total_helmets'], s['total_persons'])}%</td></tr>
        <tr><td>未戴安全帽 (no_helmet)</td><td style="color:#ff4444">{s['total_no_helmets']}</td><td>{calc_pct(s['total_no_helmets'], s['total_persons'])}%</td></tr>
        <tr><td>反光衣 (vest)</td><td>{s['total_vests']}</td><td>{calc_pct(s['total_vests'], s['total_persons'])}%</td></tr>
        <tr><td>未穿反光衣 (no_vest)</td><td style="color:#ff4444">{s['total_no_vests']}</td><td>{calc_pct(s['total_no_vests'], s['total_persons'])}%</td></tr>
        <tr><td>车辆 (vehicle)</td><td>{s['total_vehicles']}</td><td>-</td></tr>
    </table>
</div>

<div class="section">
    <h2>事件时间线</h2>
    <div class="timeline">
        {timeline_html or '<div style="padding:20px;text-align:center;color:#667788">无事件记录</div>'}
    </div>
</div>

<div class="section">
    <h2>违规截图</h2>
    <div class="captures">
        {captures_html or '<div style="padding:20px;text-align:center;color:#667788">无违规截图</div>'}
    </div>
</div>

</body>
</html>"""

        output_path = output_path or str(self.report_dir / "review_report.html")
        with open(output_path, "w") as f:
            f.write(html)
        print(f"HTML 报告已生成: {output_path}")


def calc_pct(part, total):
    return round(part / total * 100, 1) if total > 0 else 0


def main():
    parser = argparse.ArgumentParser(description="验证结果复盘工具")
    parser.add_argument("--report-dir", type=str, default="runs/video_verify",
                        help="video_verify.py 输出目录")
    parser.add_argument("--html", action="store_true",
                        help="生成 HTML 交互式报告")
    parser.add_argument("--html-output", type=str, default=None,
                        help="HTML 输出路径")

    args = parser.parse_args()

    try:
        review = ReviewReport(args.report_dir)
        review.print_summary()

        if args.html:
            review.generate_html(args.html_output)

    except FileNotFoundError as e:
        print(f"错误: {e}")
        print("请先运行 video_verify.py 生成报告")


if __name__ == "__main__":
    main()