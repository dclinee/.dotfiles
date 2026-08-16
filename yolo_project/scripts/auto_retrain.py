#!/usr/bin/env python3
"""
智慧工地 - 拍照上传 + 自动训练流水线

工作流程:
  1. 工人手机拍照 → 上传到服务器
  2. 自动预标注 (用当前模型)
  3. 人工审核 (可选)
  4. 累积到阈值 → 自动触发重训练
  5. 新模型部署 → 替换旧模型

API 接口:
  POST /api/upload           上传照片
  GET  /api/status           训练状态
  POST /api/trigger_retrain  手动触发训练
  GET  /api/models           模型版本列表
  GET  /                     手机端拍照上传页面

用法:
  # 启动完整服务
  python scripts/auto_retrain.py --model best.pt --port 8096

  # 仅上传收集 (不自动训练)
  python scripts/auto_retrain.py --model best.pt --collect-only

  # 仅手动触发训练
  python scripts/auto_retrain.py --model best.pt --train-only
"""

import argparse
import json
import os
import shutil
import subprocess
import sys
import time
import threading
import uuid
from pathlib import Path
from datetime import datetime
from collections import defaultdict

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from utils.common import (
    CLASS_NAMES, ensure_dir, safe_json_load, safe_json_dump, now_str,
)
from utils.logger import get_logger

logger = get_logger("auto_retrain")


# ============================================================
# 配置
# ============================================================

UPLOAD_DIR = Path("datasets/uploaded")
REVIEWED_DIR = Path("datasets/reviewed")
TRAINING_DIR = Path("datasets/training_pool")
MODEL_REGISTRY = Path("models/registry.json")
TRAINING_LOG = Path("runs/training_history.json")

# 阈值
MIN_NEW_IMAGES = 20       # 最少新图片数才触发训练
AUTO_RETRAIN = True        # 是否自动触发训练
CHECK_INTERVAL = 300       # 检查间隔 (秒)


# ============================================================
# 手机端拍照上传 H5 页面
# ============================================================

MOBILE_UPLOAD_PAGE = """<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1,user-scalable=no">
<title>智慧工地 - 拍照上传</title>
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:"Microsoft YaHei",sans-serif;background:#0f1923;color:#e0e0e0;min-height:100vh;padding:15px}
.header{text-align:center;padding:20px 0;border-bottom:2px solid #2a3a4a;margin-bottom:20px}
.header h1{color:#00d4ff;font-size:20px}
.header .sub{color:#667788;font-size:12px;margin-top:5px}
.card{background:#1a2a3a;border-radius:12px;padding:20px;margin-bottom:15px;border:1px solid #2a3a4a}
.card h3{color:#00d4ff;font-size:15px;margin-bottom:15px}
.form-group{margin-bottom:15px}
.form-group label{display:block;color:#8899aa;font-size:13px;margin-bottom:5px}
.form-group input,.form-group select{width:100%;padding:12px;background:#0f1923;border:1px solid #2a3a4a;border-radius:8px;color:#e0e0e0;font-size:15px}
.form-group input:focus{border-color:#00d4ff;outline:none}
.checkbox-group{display:flex;flex-wrap:wrap;gap:8px}
.checkbox-group label{display:flex;align-items:center;gap:6px;padding:8px 12px;background:#0f1923;border:1px solid #2a3a4a;border-radius:6px;cursor:pointer;font-size:13px;color:#e0e0e0}
.checkbox-group label.selected{border-color:#00d4ff;background:#1a3040}
.checkbox-group input{display:none}
.btn{width:100%;padding:14px;border:none;border-radius:8px;font-size:16px;font-weight:bold;cursor:pointer;margin-top:10px;transition:all .2s}
.btn-primary{background:#00d4ff;color:#0f1923}
.btn-primary:active{background:#00aacc}
.btn-primary:disabled{background:#3a5a6a;color:#8899aa}
.preview{width:100%;max-height:300px;object-fit:contain;border-radius:8px;border:1px solid #2a3a4a;margin-bottom:10px;display:none}
.upload-area{text-align:center;padding:30px;border:2px dashed #2a3a4a;border-radius:12px;cursor:pointer;margin-bottom:15px;transition:all .2s}
.upload-area:active{border-color:#00d4ff;background:#1a3040}
.upload-area .icon{font-size:40px;margin-bottom:10px}
.upload-area .text{color:#8899aa;font-size:14px}
.status-bar{display:flex;justify-content:space-around;padding:15px;background:#1a2a3a;border-radius:12px;margin-bottom:15px}
.status-item{text-align:center}
.status-item .value{font-size:22px;font-weight:bold;color:#00d4ff}
.status-item .label{font-size:11px;color:#8899aa;margin-top:3px}
.alert{background:#ff4444;color:#fff;padding:12px;border-radius:8px;margin-bottom:15px;display:none;text-align:center}
.alert.show{display:block}
.alert.success{background:#00cc66}
.history{max-height:200px;overflow-y:auto}
.history .entry{display:flex;justify-content:space-between;padding:6px 0;font-size:12px;border-bottom:1px solid #1a2838}
.history .entry .name{color:#e0e0e0;flex:1}
.history .entry .time{color:#667788}
.history .entry .ok{color:#00ff88}
.history .entry .fail{color:#ff4444}
</style>
</head>
<body>

<div class="header">
    <h1>智慧工地 - 拍照上传</h1>
    <div class="sub" id="pageTime">--</div>
</div>

<div class="alert" id="alertBox"></div>

<div class="card">
    <h3>身份信息</h3>
    <div class="form-group">
        <label>手机号</label>
        <input type="tel" id="phone" placeholder="输入手机号" maxlength="11">
    </div>
    <div class="form-group">
        <label>拍摄位置</label>
        <select id="location">
            <option value="">选择位置...</option>
            <option value="entrance">工地入口</option>
            <option value="zone_a">A区施工区</option>
            <option value="zone_b">B区施工区</option>
            <option value="zone_c">C区施工区</option>
            <option value="tower">塔吊周边</option>
            <option value="office">办公区</option>
            <option value="other">其他</option>
        </select>
    </div>
</div>

<div class="card">
    <h3>拍摄内容</h3>
    <div class="checkbox-group" id="classTags">
        <label><input type="checkbox" value="person">人员</label>
        <label><input type="checkbox" value="helmet">安全帽</label>
        <label><input type="checkbox" value="no_helmet">未戴安全帽</label>
        <label><input type="checkbox" value="vest">反光衣</label>
        <label><input type="checkbox" value="no_vest">未穿反光衣</label>
        <label><input type="checkbox" value="vehicle">车辆</label>
        <label><input type="checkbox" value="smoke_fire">烟雾/火焰</label>
    </div>
    <div class="form-group">
        <label>备注</label>
        <input type="text" id="remark" placeholder="可选备注...">
    </div>
</div>

<div class="upload-area" id="uploadArea" onclick="document.getElementById('imageInput').click()">
    <div class="icon">📷</div>
    <div class="text">点击拍照或选择图片</div>
</div>
<input type="file" id="imageInput" accept="image/*" capture="environment" style="display:none" onchange="previewImage(event)">

<img class="preview" id="preview">

<button class="btn btn-primary" id="uploadBtn" onclick="uploadPhoto()" disabled>上传照片</button>

<div class="alert" id="successAlert" style="background:#00cc66"></div>

<div class="card" id="statsCard">
    <h3>上传统计</h3>
    <div class="status-bar">
        <div class="status-item"><div class="value" id="todayCount">0</div><div class="label">今日上传</div></div>
        <div class="status-item"><div class="value" id="totalCount">0</div><div class="label">累计上传</div></div>
        <div class="status-item"><div class="value" id="pendingTrain">0</div><div class="label">待训练</div></div>
    </div>
</div>

<div class="card" id="historyCard">
    <h3>上传历史</h3>
    <div class="history" id="historyList">
        <div style="text-align:center;color:#667788;padding:10px">暂无记录</div>
    </div>
</div>

<script>
let selectedFile = null;

// 复选框样式
document.querySelectorAll('#classTags label').forEach(label => {
    label.addEventListener('click', function(e) {
        const cb = this.querySelector('input');
        cb.checked = !cb.checked;
        this.classList.toggle('selected', cb.checked);
    });
});

// 时间更新
setInterval(() => {
    document.getElementById('pageTime').textContent = new Date().toLocaleString('zh-CN');
}, 1000);

async function previewImage(event) {
    const file = event.target.files[0];
    if (!file) return;
    selectedFile = file;

    const reader = new FileReader();
    reader.onload = e => {
        const preview = document.getElementById('preview');
        preview.src = e.target.result;
        preview.style.display = 'block';
    };
    reader.readAsDataURL(file);

    document.getElementById('uploadBtn').disabled = false;
    document.getElementById('uploadArea').style.display = 'none';
}

async function uploadPhoto() {
    if (!selectedFile) return;

    const phone = document.getElementById('phone').value.trim();
    const location = document.getElementById('location').value;
    const remark = document.getElementById('remark').value.trim();

    // 获取选中的标签
    const tags = [];
    document.querySelectorAll('#classTags input:checked').forEach(cb => tags.push(cb.value));

    const btn = document.getElementById('uploadBtn');
    btn.disabled = true;
    btn.textContent = '上传中...';

    const formData = new FormData();
    formData.append('image', selectedFile);
    formData.append('phone', phone);
    formData.append('location', location);
    formData.append('tags', JSON.stringify(tags));
    formData.append('remark', remark);

    try {
        const resp = await fetch('/api/upload', { method: 'POST', body: formData });
        const data = await resp.json();

        if (data.ok) {
            showAlert('上传成功! 已自动预标注 ' + data.labels + ' 个目标', true);
            // 重置
            selectedFile = null;
            document.getElementById('preview').style.display = 'none';
            document.getElementById('imageInput').value = '';
            document.getElementById('uploadArea').style.display = 'block';
            document.getElementById('uploadBtn').disabled = true;
            document.getElementById('remark').value = '';
            document.querySelectorAll('#classTags input').forEach(cb => cb.checked = false);
            document.querySelectorAll('#classTags label').forEach(l => l.classList.remove('selected'));
            loadStats();
        } else {
            showAlert('上传失败: ' + (data.error || '请重试'));
        }
    } catch(e) {
        showAlert('网络错误: ' + e.message);
    }

    btn.disabled = false;
    btn.textContent = '上传照片';
}

function showAlert(msg, isGood) {
    const box = document.getElementById('alertBox');
    box.textContent = msg;
    box.className = 'alert show' + (isGood ? ' success' : '');
    setTimeout(() => box.classList.remove('show'), 3000);
}

async function loadStats() {
    try {
        const resp = await fetch('/api/status');
        const data = await resp.json();
        document.getElementById('todayCount').textContent = data.today_uploads || 0;
        document.getElementById('totalCount').textContent = data.total_uploads || 0;
        document.getElementById('pendingTrain').textContent = data.pending_train || 0;

        const list = document.getElementById('historyList');
        if (data.recent && data.recent.length > 0) {
            list.innerHTML = data.recent.map(r =>
                `<div class="entry">
                    <span class="name">${r.filename}</span>
                    <span class="time">${r.time}</span>
                    <span class="${r.ok ? 'ok' : 'fail'}">${r.ok ? '✓' : '✗'}</span>
                </div>`
            ).join('');
        }
    } catch(e) {}
}

loadStats();
setInterval(loadStats, 30000);
</script>
</body>
</html>"""


# ============================================================
# 模型版本管理
# ============================================================

class ModelRegistry:
    """模型版本管理"""

    def __init__(self, registry_path: str = None):
        self.registry_path = Path(registry_path or MODEL_REGISTRY)
        self._load()

    def _load(self):
        ensure_dir(self.registry_path.parent)
        self.data = safe_json_load(str(self.registry_path), default={
            "current_model": "",
            "versions": [],
            "training_history": [],
        })

    def _save(self):
        safe_json_dump(self.data, str(self.registry_path))

    def add_version(self, model_path: str, metrics: dict = None,
                    notes: str = ""):
        """添加新模型版本"""
        version = {
            "id": str(uuid.uuid4())[:8],
            "path": model_path,
            "created_at": now_str(),
            "metrics": metrics or {},
            "notes": notes,
        }
        self.data["versions"].append(version)
        self.data["current_model"] = model_path
        self._save()
        return version

    def get_current_model(self) -> str:
        return self.data.get("current_model", "")

    def get_versions(self, limit: int = 10) -> list:
        return self.data["versions"][-limit:]

    def add_training_record(self, record: dict):
        self.data["training_history"].append(record)
        if len(self.data["training_history"]) > 100:
            self.data["training_history"] = \
                self.data["training_history"][-100:]
        self._save()


# ============================================================
# 上传 + 训练管理器
# ============================================================

class AutoRetrainManager:
    """拍照上传 + 自动训练管理器"""

    def __init__(self, model_path: str, device: str = "cpu",
                 min_new_images: int = MIN_NEW_IMAGES):
        self.model_path = Path(model_path)
        self.device = device
        self.min_new_images = min_new_images

        ensure_dir(UPLOAD_DIR)
        ensure_dir(REVIEWED_DIR)
        ensure_dir(TRAINING_DIR)
        ensure_dir(Path("runs/auto_train"))

        self.registry = ModelRegistry()
        self.upload_history = safe_json_load(
            str(UPLOAD_DIR / ".upload_history.json"), default=[]
        )

        self._training_lock = threading.Lock()
        self._training_status = {
            "running": False,
            "last_run": None,
            "last_result": None,
            "progress": "",
        }

    # ============================================================
    # 上传处理
    # ============================================================

    def handle_upload(self, image_data: bytes, filename: str,
                      phone: str = "", location: str = "",
                      tags: list = None, remark: str = "") -> dict:
        """处理上传"""
        # 保存图片
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        safe_filename = f"{timestamp}_{phone or 'anon'}_{filename}"
        img_path = UPLOAD_DIR / safe_filename

        with open(img_path, "wb") as f:
            f.write(image_data)

        # 自动预标注
        labels_count = 0
        try:
            from scripts.auto_label import AutoLabeler
            labeler = AutoLabeler(str(self.model_path), device=self.device)
            ok, label_path, dets = labeler.auto_label(
                str(img_path), str(UPLOAD_DIR), overwrite=True
            )
            if ok and dets:
                labels_count = len(dets)
        except Exception as e:
            logger.warning(f"预标注失败: {e}")

        # 记录
        record = {
            "filename": safe_filename,
            "phone": phone,
            "location": location,
            "tags": tags or [],
            "remark": remark,
            "time": now_str(),
            "labels_count": labels_count,
            "status": "uploaded",
        }
        self.upload_history.append(record)
        if len(self.upload_history) > 500:
            self.upload_history = self.upload_history[-500:]

        safe_json_dump(self.upload_history, str(UPLOAD_DIR / ".upload_history.json"))

        logger.info(f"上传: {safe_filename} | 预标注: {labels_count} 个目标")
        return record

    def get_status(self) -> dict:
        """获取训练状态"""
        today = datetime.now().strftime("%Y-%m-%d")
        today_uploads = sum(1 for r in self.upload_history
                            if r["time"].startswith(today))

        pending = sum(1 for r in self.upload_history
                      if r.get("status") == "uploaded")

        return {
            "today_uploads": today_uploads,
            "total_uploads": len(self.upload_history),
            "pending_train": pending,
            "pending_review": self._count_pending_review(),
            "training_running": self._training_status["running"],
            "training_progress": self._training_status["progress"],
            "last_training": self._training_status["last_run"],
            "last_result": self._training_status["last_result"],
            "current_model": self.registry.get_current_model(),
            "min_for_retrain": self.min_new_images,
            "recent": [
                {"filename": r["filename"][:40], "time": r["time"][11:19],
                 "ok": r.get("status") == "uploaded"}
                for r in self.upload_history[-20:]
            ],
        }

    def _count_pending_review(self) -> int:
        approved = safe_json_load(str(UPLOAD_DIR / ".approved.json"), default=[])
        return sum(1 for r in self.upload_history
                   if r.get("status") == "uploaded"
                   and r["filename"] not in approved)

    # ============================================================
    # 训练触发
    # ============================================================

    def trigger_retrain(self, force: bool = False) -> dict:
        """触发重训练"""
        # 收集新图片
        new_images = self._collect_new_training_data()

        if not force and len(new_images) < self.min_new_images:
            return {
                "ok": False,
                "error": f"新图片不足 ({len(new_images)}/{self.min_new_images})",
                "count": len(new_images),
            }

        if self._training_lock.locked():
            return {"ok": False, "error": "训练进行中"}

        # 后台线程执行训练
        thread = threading.Thread(
            target=self._run_training, args=(new_images,),
            daemon=True,
        )
        thread.start()

        return {
            "ok": True,
            "count": len(new_images),
            "message": f"训练已启动, 新图片: {len(new_images)} 张",
        }

    def _collect_new_training_data(self) -> list:
        """收集新图片加入训练集"""
        approved = safe_json_load(str(UPLOAD_DIR / ".approved.json"), default=[])
        new_images = []

        for record in self.upload_history:
            if record.get("status") != "uploaded":
                continue
            filename = record["filename"]
            if filename in approved:
                continue

            img_path = UPLOAD_DIR / filename
            label_path = UPLOAD_DIR / f"{Path(filename).stem}.txt"

            if img_path.exists() and label_path.exists():
                # 移到训练池
                dest_img = TRAINING_DIR / filename
                dest_label = TRAINING_DIR / f"{Path(filename).stem}.txt"

                shutil.copy2(img_path, dest_img)
                if label_path.stat().st_size > 0:
                    shutil.copy2(label_path, dest_label)

                new_images.append(filename)
                record["status"] = "training"
                approved.append(filename)

        safe_json_dump(self.upload_history, str(UPLOAD_DIR / ".upload_history.json"))
        safe_json_dump(approved, str(UPLOAD_DIR / ".approved.json"))

        return new_images

    def _run_training(self, new_images: list):
        """执行训练 (后台)"""
        with self._training_lock:
            self._training_status["running"] = True
            self._training_status["progress"] = "开始训练..."

            try:
                # 输出模型路径
                timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
                output_name = f"auto_retrain_{timestamp}"
                output_dir = Path("runs/auto_train") / output_name

                logger.info(f"自动训练启动: {len(new_images)} 新图片, 输出: {output_name}")

                self._training_status["progress"] = f"训练中 ({len(new_images)} 新图片)..."

                # 调用训练脚本
                cmd = [
                    sys.executable, "scripts/train.py",
                    "--config", "configs/smart_construction.yaml",
                    "--model", str(self.model_path),
                    "--epochs", "30",  # 增量训练, 较少 epochs
                    "--batch", "8",
                    "--device", self.device,
                    "--project", "runs/auto_train",
                    "--name", output_name,
                ]

                result = subprocess.run(
                    cmd,
                    capture_output=True,
                    text=True,
                    timeout=3600,
                    cwd=str(Path(__file__).resolve().parent.parent),
                )

                if result.returncode == 0:
                    # 找 best.pt
                    best_pt = output_dir / "weights" / "best.pt"
                    if best_pt.exists():
                        # 注册新模型
                        self.registry.add_version(
                            str(best_pt),
                            notes=f"自动训练 - {len(new_images)} 新图片",
                        )
                        self.model_path = best_pt

                    self._training_status["last_result"] = "成功"
                    self._training_status["progress"] = "训练完成"
                    logger.info(f"自动训练完成: {output_name}")
                else:
                    self._training_status["last_result"] = "失败"
                    self._training_status["progress"] = "训练失败"
                    logger.error(f"自动训练失败: {result.stderr[:200]}")

                self._training_status["last_run"] = now_str()

                # 记录
                self.registry.add_training_record({
                    "time": now_str(),
                    "images": len(new_images),
                    "output": str(output_name),
                    "result": "成功" if result.returncode == 0 else "失败",
                    "error": result.stderr[:200] if result.returncode != 0 else "",
                })

            except subprocess.TimeoutExpired:
                self._training_status["last_result"] = "超时"
                self._training_status["progress"] = "训练超时"
                logger.error("自动训练超时")
            except Exception as e:
                self._training_status["last_result"] = "错误"
                self._training_status["progress"] = str(e)[:50]
                logger.error(f"自动训练异常: {e}")
            finally:
                self._training_status["running"] = False


# ============================================================
# Flask 应用
# ============================================================

def create_app(manager: AutoRetrainManager):
    from flask import Flask, request, jsonify, send_from_directory

    app = Flask(__name__)
    app.config["MAX_CONTENT_LENGTH"] = 50 * 1024 * 1024  # 50MB

    @app.route("/")
    def index():
        return MOBILE_UPLOAD_PAGE

    @app.route("/api/upload", methods=["POST"])
    def api_upload():
        if "image" not in request.files:
            return jsonify({"ok": False, "error": "缺少图片"}), 400

        file = request.files["image"]
        if file.filename == "":
            return jsonify({"ok": False, "error": "文件名为空"}), 400

        try:
            record = manager.handle_upload(
                image_data=file.read(),
                filename=file.filename,
                phone=request.form.get("phone", ""),
                location=request.form.get("location", ""),
                tags=json.loads(request.form.get("tags", "[]")),
                remark=request.form.get("remark", ""),
            )
            return jsonify({
                "ok": True,
                "filename": record["filename"],
                "labels": record["labels_count"],
            })
        except Exception as e:
            return jsonify({"ok": False, "error": str(e)}), 500

    @app.route("/api/status")
    def api_status():
        return jsonify(manager.get_status())

    @app.route("/api/trigger_retrain", methods=["POST"])
    def api_trigger_retrain():
        force = request.args.get("force", "0") == "1"
        result = manager.trigger_retrain(force=force)
        return jsonify(result)

    @app.route("/api/models")
    def api_models():
        return jsonify({
            "current": manager.registry.get_current_model(),
            "versions": manager.registry.get_versions(),
        })

    @app.route("/photos/<filename>")
    def serve_photo(filename):
        return send_from_directory(str(UPLOAD_DIR), filename)

    return app


# ============================================================
# 主函数
# ============================================================

def main():
    parser = argparse.ArgumentParser(description="拍照上传 + 自动训练流水线")
    parser.add_argument("--model", type=str, required=True, help="当前模型路径")
    parser.add_argument("--port", type=int, default=8096, help="服务端口")
    parser.add_argument("--host", type=str, default="0.0.0.0", help="监听地址")
    parser.add_argument("--device", type=str, default="cpu", help="训练设备")
    parser.add_argument("--min-images", type=int, default=MIN_NEW_IMAGES,
                        help="触发训练的最小新图片数")
    parser.add_argument("--train-only", action="store_true",
                        help="仅手动触发训练")
    parser.add_argument("--force", action="store_true",
                        help="强制训练 (忽略最小图片数)")

    args = parser.parse_args()

    manager = AutoRetrainManager(
        model_path=args.model,
        device=args.device,
        min_new_images=args.min_images,
    )

    if args.train_only:
        result = manager.trigger_retrain(force=args.force)
        print(json.dumps(result, indent=2, ensure_ascii=False))
        return

    app = create_app(manager)

    print(f"\n{'='*60}")
    print(f"  智慧工地 - 拍照上传 + 自动训练服务")
    print(f"{'='*60}")
    print(f"  监听: http://{args.host}:{args.port}")
    print(f"  模型: {args.model}")
    print(f"  训练触发: ≥ {args.min_images} 新图片")
    print(f"")
    print(f"  接口:")
    print(f"    POST /api/upload           上传照片")
    print(f"    GET  /api/status           训练状态")
    print(f"    POST /api/trigger_retrain  手动触发训练")
    print(f"    GET  /api/models           模型版本")
    print(f"{'='*60}\n")

    app.run(host=args.host, port=args.port, debug=False)


if __name__ == "__main__":
    main()