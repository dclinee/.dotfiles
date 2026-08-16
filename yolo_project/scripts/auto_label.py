#!/usr/bin/env python3
"""
智慧工地 - 自动标注引擎
用已有模型对新照片预标注，人工审核后可加入训练集

工作流程:
  1. 工人拍照上传 → 自动标注 → 生成标注文件
  2. 人工审核页面 → 修正/确认/删除
  3. 确认后自动加入训练集 → 触发重训练

用法:
  # 对单张图片预标注
  python scripts/auto_label.py --model best.pt --image photo.jpg

  # 批量预标注
  python scripts/auto_label.py --model best.pt --dir ./new_photos

  # 启动审核服务
  python scripts/auto_label.py --model best.pt --serve --port 8095
"""

import argparse
import json
import os
import sys
import time
import shutil
from pathlib import Path
from datetime import datetime
from typing import List, Dict, Tuple, Optional

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from utils.common import (
    CLASS_NAMES, CLASS_COLORS, ensure_dir, safe_json_load, safe_json_dump,
    now_str, bbox_area,
)
from utils.logger import get_logger

logger = get_logger("auto_label")


# ============================================================
# 自动标注器
# ============================================================

class AutoLabeler:
    """自动标注引擎"""

    def __init__(self, model_path: str, conf_threshold: float = 0.3,
                 device: str = "cpu"):
        from ultralytics import YOLO
        self.model = YOLO(model_path)
        self.conf_threshold = conf_threshold
        self.device = device
        self.model_path = model_path

    def predict(self, image_path: str) -> List[Dict]:
        """
        对单张图片推理

        Returns:
            [{cls_id, cls_name, conf, bbox: (x1,y1,x2,y2),
              yolo_bbox: (cx,cy,w,h)}, ...]
        """
        results = self.model(image_path, conf=self.conf_threshold,
                             device=self.device, verbose=False)

        detections = []
        if len(results) == 0 or results[0].boxes is None:
            return detections

        boxes = results[0].boxes
        if boxes.xyxy is None or len(boxes.xyxy) == 0:
            return detections

        # 获取原始图片尺寸
        orig_shape = results[0].orig_shape
        img_h, img_w = orig_shape[:2]

        for i in range(len(boxes.xyxy)):
            cls_id = int(boxes.cls[i])
            conf = float(boxes.conf[i])
            x1, y1, x2, y2 = boxes.xyxy[i].tolist()

            # 归一化 YOLO 格式
            cx = (x1 + x2) / 2 / img_w
            cy = (y1 + y2) / 2 / img_h
            bw = (x2 - x1) / img_w
            bh = (y2 - y1) / img_h

            detections.append({
                "cls_id": cls_id,
                "cls_name": CLASS_NAMES.get(cls_id, f"cls_{cls_id}"),
                "conf": round(conf, 4),
                "bbox_abs": (round(x1), round(y1), round(x2), round(y2)),
                "bbox_yolo": (round(cx, 6), round(cy, 6), round(bw, 6), round(bh, 6)),
            })

        return detections

    def auto_label(self, image_path: str, output_dir: str = None,
                   overwrite: bool = False) -> Tuple[bool, str, List[Dict]]:
        """
        自动标注一张图片，生成 YOLO 标注文件

        Args:
            image_path: 图片路径
            output_dir: 标注输出目录（默认与图片同目录）
            overwrite: 是否覆盖已有标注

        Returns:
            (success, label_path, detections)
        """
        image_path = Path(image_path)
        if not image_path.exists():
            return False, "", []

        # 检查是否已有标注
        if output_dir:
            label_dir = Path(output_dir)
        else:
            label_dir = image_path.parent

        label_path = label_dir / f"{image_path.stem}.txt"
        if label_path.exists() and not overwrite:
            logger.info(f"标注已存在: {label_path}")
            return True, str(label_path), []

        # 推理
        detections = self.predict(str(image_path))

        if not detections:
            logger.warning(f"未检测到目标: {image_path.name}")
            # 创建空的标注文件
            ensure_dir(label_dir)
            label_path.write_text("")
            return True, str(label_path), []

        # 写入 YOLO 格式标注
        ensure_dir(label_dir)
        lines = []
        for d in detections:
            cx, cy, bw, bh = d["bbox_yolo"]
            lines.append(f"{d['cls_id']} {cx:.6f} {cy:.6f} {bw:.6f} {bh:.6f}")

        label_path.write_text("\n".join(lines) + "\n")

        logger.info(f"自动标注: {image_path.name} → {len(detections)} 个目标")
        return True, str(label_path), detections

    def batch_label(self, image_dir: str, output_dir: str = None,
                    overwrite: bool = False) -> Dict:
        """
        批量自动标注

        Returns:
            {total, success, failed, detections_per_image, ...}
        """
        image_dir = Path(image_dir)
        image_exts = {".jpg", ".jpeg", ".png", ".bmp", ".webp"}

        images = [f for f in image_dir.iterdir()
                  if f.suffix.lower() in image_exts]

        stats = {
            "total": len(images),
            "success": 0,
            "failed": 0,
            "total_detections": 0,
            "detections_per_class": {},
            "start_time": now_str(),
        }

        for img in images:
            ok, label_path, dets = self.auto_label(
                str(img), output_dir, overwrite
            )
            if ok and dets:
                stats["success"] += 1
                stats["total_detections"] += len(dets)
                for d in dets:
                    cls = d["cls_name"]
                    stats["detections_per_class"][cls] = \
                        stats["detections_per_class"].get(cls, 0) + 1
            elif ok:
                stats["success"] += 1
            else:
                stats["failed"] += 1

        stats["end_time"] = now_str()
        return stats


# ============================================================
# 审核服务
# ============================================================

def create_review_page(labeled_dir: str) -> str:
    """生成审核页面 HTML"""
    labeled_dir = Path(labeled_dir)
    images = sorted([f for f in labeled_dir.glob("*.jpg")] +
                    [f for f in labeled_dir.glob("*.png")])[:50]

    image_list = []
    for img in images:
        label_path = labeled_dir / f"{img.stem}.txt"
        has_label = label_path.exists() and label_path.stat().st_size > 0
        image_list.append({
            "name": img.name,
            "path": str(img),
            "labeled": has_label,
        })

    return f"""<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1,user-scalable=no">
<title>标注审核</title>
<style>
*{{margin:0;padding:0;box-sizing:border-box}}
body{{font-family:"Microsoft YaHei",sans-serif;background:#0f1923;color:#e0e0e0;padding:15px}}
.header{{text-align:center;padding:15px;margin-bottom:15px}}
.header h1{{color:#00d4ff;font-size:20px}}
.stats{{display:flex;gap:10px;margin-bottom:15px;flex-wrap:wrap}}
.stat{{background:#1a2a3a;border-radius:8px;padding:12px;text-align:center;flex:1;min-width:80px}}
.stat .v{{font-size:20px;font-weight:bold;color:#00d4ff}}
.stat .l{{font-size:11px;color:#8899aa}}
.grid{{display:grid;grid-template-columns:repeat(auto-fill,minmax(200px,1fr));gap:10px}}
.card{{background:#1a2a3a;border-radius:8px;overflow:hidden;border:2px solid #2a3a4a;position:relative}}
.card.labelled{{border-color:#00ff88}}
.card.unlabelled{{border-color:#ff4444}}
.card img{{width:100%;display:block;aspect-ratio:4/3;object-fit:cover}}
.card .info{{padding:8px;font-size:12px}}
.card .info .name{{color:#e0e0e0;word-break:break-all}}
.card .info .status{{font-size:11px;margin-top:3px}}
.card .status.labelled{{color:#00ff88}}
.card .status.unlabelled{{color:#ff4444}}
.card .actions{{display:flex;gap:5px;padding:0 8px 8px}}
.card .actions button{{flex:1;padding:6px;border:none;border-radius:4px;font-size:12px;cursor:pointer}}
.btn-approve{{background:#00ff88;color:#0f1923}}
.btn-relabel{{background:#ffaa00;color:#0f1923}}
.btn-delete{{background:#ff4444;color:#fff}}
.btn-upload{{background:#00d4ff;color:#0f1923;padding:14px;font-size:16px;width:100%;border:none;border-radius:8px;margin-top:15px;cursor:pointer}}
</style>
</head>
<body>
<div class="header"><h1>标注审核</h1></div>
<div class="stats">
    <div class="stat"><div class="v" id="totalCount">{len(image_list)}</div><div class="l">总数</div></div>
    <div class="stat"><div class="v" id="labelledCount">{sum(1 for i in image_list if i['labeled'])}</div><div class="l">已标注</div></div>
    <div class="stat"><div class="v" id="unlabelledCount">{sum(1 for i in image_list if not i['labeled'])}</div><div class="l">待标注</div></div>
</div>
<div class="grid" id="grid">
    {''.join(f'''<div class="card {'labelled' if i['labeled'] else 'unlabelled'}" data-name="{i['name']}">
    <img src="/photos/{i['name']}" loading="lazy" onerror="this.src='data:image/svg+xml,<svg xmlns=%22http://www.w3.org/2000/svg%22 width=%22200%22 height=%22150%22><rect fill=%22%23333%22 width=%22200%22 height=%22150%22/><text fill=%22%23888%22 x=%22100%22 y=%2275%22 text-anchor=%22middle%22>无图片</text></svg>'">
    <div class="info"><div class="name">{i['name'][:30]}</div><div class="status {'labelled' if i['labeled'] else 'unlabelled'}">{'已标注' if i['labeled'] else '待标注'}</div></div>
    <div class="actions">
        <button class="btn-relabel" onclick="relabel('{i['name']}')">重标</button>
        <button class="btn-approve" onclick="approve('{i['name']}')">确认</button>
        <button class="btn-delete" onclick="deleteImg('{i['name']}')">删</button>
    </div>
    </div>''' for i in image_list)}
</div>
<button class="btn-upload" onclick="triggerRetrain()">确认全部 → 加入训练集</button>

<script>
async function relabel(name){{
    const resp = await fetch('/api/relabel/' + name, {{method:'POST'}});
    if(resp.ok) location.reload();
}}
async function approve(name){{
    const resp = await fetch('/api/approve/' + name, {{method:'POST'}});
    if(resp.ok) location.reload();
}}
async function deleteImg(name){{
    if(!confirm('删除 ' + name + '?')) return;
    await fetch('/api/delete/' + name, {{method:'DELETE'}});
    location.reload();
}}
async function triggerRetrain(){{
    if(!confirm('确认将所有已审核图片加入训练集?')) return;
    const btn = event.target;
    btn.textContent = '处理中...';
    btn.disabled = true;
    const resp = await fetch('/api/trigger_retrain', {{method:'POST'}});
    const data = await resp.json();
    if(data.ok) alert('已加入训练集! 新图片数: ' + data.count);
    else alert('操作失败: ' + (data.error || ''));
    btn.textContent = '确认全部 → 加入训练集';
    btn.disabled = false;
}}
</script>
</body>
</html>"""


# ============================================================
# 主函数
# ============================================================

def main():
    parser = argparse.ArgumentParser(description="自动标注引擎")
    parser.add_argument("--model", type=str, required=True, help="模型路径")
    parser.add_argument("--image", type=str, default=None, help="单张图片")
    parser.add_argument("--dir", type=str, default=None, help="批量图片目录")
    parser.add_argument("--output", type=str, default=None, help="标注输出目录")
    parser.add_argument("--conf", type=float, default=0.3, help="置信度阈值")
    parser.add_argument("--device", type=str, default="cpu", help="设备")
    parser.add_argument("--overwrite", action="store_true", help="覆盖已有标注")
    parser.add_argument("--serve", action="store_true", help="启动审核服务")
    parser.add_argument("--port", type=int, default=8095, help="审核服务端口")

    args = parser.parse_args()

    labeler = AutoLabeler(args.model, args.conf, args.device)

    if args.serve:
        from flask import Flask, send_from_directory, jsonify, request
        import shutil

        app = Flask(__name__)
        labeled_dir = args.output or args.dir or "datasets/uploaded"
        ensure_dir(labeled_dir)

        @app.route("/")
        def review():
            return create_review_page(labeled_dir)

        @app.route("/photos/<filename>")
        def serve_photo(filename):
            return send_from_directory(labeled_dir, filename)

        @app.route("/api/relabel/<filename>", methods=["POST"])
        def api_relabel(filename):
            img_path = Path(labeled_dir) / filename
            if not img_path.exists():
                return jsonify({"ok": False, "error": "图片不存在"}), 404
            labeler.auto_label(str(img_path), str(img_path.parent), overwrite=True)
            return jsonify({"ok": True})

        @app.route("/api/approve/<filename>", methods=["POST"])
        def api_approve(filename):
            img_path = Path(labeled_dir) / filename
            if not img_path.exists():
                return jsonify({"ok": False, "error": "图片不存在"}), 404
            # 标记为已审核
            approved_file = Path(labeled_dir) / ".approved.json"
            approved = safe_json_load(str(approved_file), default=[])
            if filename not in approved:
                approved.append(filename)
            safe_json_dump(approved, str(approved_file))
            return jsonify({"ok": True})

        @app.route("/api/delete/<filename>", methods=["DELETE"])
        def api_delete(filename):
            img_path = Path(labeled_dir) / filename
            label_path = Path(labeled_dir) / f"{img_path.stem}.txt"
            if img_path.exists():
                img_path.unlink()
            if label_path.exists():
                label_path.unlink()
            return jsonify({"ok": True})

        print(f"\n审核服务启动: http://0.0.0.0:{args.port}")
        print(f"标注目录: {labeled_dir}")
        app.run(host="0.0.0.0", port=args.port, debug=False)

    elif args.image:
        ok, label_path, dets = labeler.auto_label(
            args.image, args.output, args.overwrite
        )
        if ok:
            print(f"标注完成: {label_path}")
            for d in dets:
                print(f"  [{d['cls_name']}] conf={d['conf']:.3f} "
                      f"bbox={d['bbox_abs']}")
        else:
            print("标注失败")

    elif args.dir:
        stats = labeler.batch_label(args.dir, args.output, args.overwrite)
        print(json.dumps(stats, indent=2, ensure_ascii=False))
    else:
        parser.print_help()


if __name__ == "__main__":
    main()