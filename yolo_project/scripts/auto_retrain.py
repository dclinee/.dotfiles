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

# 伪标签质量阈值
CONF_MIN_WRITE = 0.2       # 低于该置信度的框直接丢弃 (不写入YOLO标注)
CONF_LOW_MARK = 0.5        # 低于该置信度视为低质量框，计入 low_conf_ratio
AVG_CONF_GOOD = 0.6        # 平均置信度 ≥ 此值 且 low_conf_ratio < 此值 → 认定高质量
LOW_RATIO_GOOD = 0.3       # 低置信度框占比 < 此值 才认可质量合格


class AutoRetrainManager:
    """拍照上传 + 自动训练管理器"""

    def __init__(self, model_path: str, device: str = "cpu",
                 min_new_images: int = MIN_NEW_IMAGES,
                 storage=None):
        """
        Args:
            storage: SiteDatabase 实例 (None 时不启用 SQLite 持久化)
        """
        self.model_path = Path(model_path)
        self.device = device
        self.min_new_images = min_new_images
        self.storage = storage

        ensure_dir(UPLOAD_DIR)
        ensure_dir(REVIEWED_DIR)
        ensure_dir(TRAINING_DIR)
        ensure_dir(Path("runs/auto_train"))

        self.registry = ModelRegistry()
        self.upload_history = safe_json_load(
            str(UPLOAD_DIR / ".upload_history.json"), default=[]
        )

        # AutoLabeler 单例 (惰性初始化，避免导入就加载模型)
        self._labeler = None

        self._training_lock = threading.Lock()
        self._training_status = {
            "running": False,
            "last_run": None,
            "last_result": None,
            "progress": "",
        }

    # ============================================================
    # Labeler 懒加载
    # ============================================================
    def _get_labeler(self):
        if self._labeler is None:
            from scripts.auto_label import AutoLabeler
            self._labeler = AutoLabeler(str(self.model_path), device=self.device)
        return self._labeler

    # ============================================================
    # 上传处理
    # ============================================================

    def handle_upload(self, image_data: bytes, filename: str,
                      phone: str = "", location: str = "",
                      tags: list = None, remark: str = "",
                      uploader_name: str = "", uploader_team: str = "",
                      ) -> dict:
        """处理上传
        Returns:
            dict 含: photo_id, filename, duplicate(bool), labels_count,
                    status, avg_confidence, low_conf_ratio
        """
        # ---------- 1) hash 去重 ----------
        content_hash = None
        photo_id = None
        duplicate = False
        if self.storage is not None:
            content_hash = self.storage.compute_content_hash(image_data)
            existing = self.storage.find_photo_by_hash(content_hash)
            if existing:
                photo_id = existing["id"]
                duplicate = True
                return {
                    "photo_id": photo_id,
                    "filename": existing.get("filename", filename),
                    "duplicate": True,
                    "status": existing.get("status", "uploaded"),
                    "labels_count": existing.get("labels_count", 0),
                    "avg_confidence": existing.get("avg_confidence", 0),
                    "low_conf_ratio": existing.get("low_conf_ratio", 0),
                    "message": "该图片已上传过，跳过重复内容",
                }

        # ---------- 2) 保存图片到磁盘 ----------
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        photo_uuid = uuid.uuid4().hex[:12]
        safe_filename = f"{timestamp}_{phone or 'anon'}_{photo_uuid}_{filename}"
        img_path = UPLOAD_DIR / safe_filename
        with open(img_path, "wb") as f:
            f.write(image_data)
        file_size = len(image_data)

        # 读图片尺寸 (用 PIL/cv2 都可以，优先 cv2 更轻)
        image_w = image_h = None
        try:
            import cv2
            import numpy as np
            arr = np.frombuffer(image_data, dtype=np.uint8)
            img = cv2.imdecode(arr, cv2.IMREAD_UNCHANGED)
            if img is not None and img.ndim >= 2:
                image_h, image_w = img.shape[:2]
        except Exception:
            pass

        # ---------- 3) 写入 photos 表 (status = uploaded) ----------
        if self.storage is not None:
            photo_id = self.storage.add_photo(
                photo_uuid=photo_uuid,
                filename=safe_filename,
                file_path=str(img_path),
                content_hash=content_hash,
                file_size=file_size,
                image_w=image_w, image_h=image_h,
                uploader_phone=phone,
                uploader_name=uploader_name,
                uploader_team=uploader_team,
                location_tag=location,
                user_tags=list(tags) if tags else [],
                remark=remark,
                model_version=str(self.model_path),
                status="uploaded",
            )
            # status 置为 labeling
            self.storage.update_photo_status(photo_id, "labeling")

        # ---------- 4) 自动预标注 ----------
        detections = []
        labels_count = 0
        avg_confidence = 0.0
        low_conf_ratio = 0.0
        try:
            labeler = self._get_labeler()
            # 用 predict() 直接拿结构化 dets (不用默认 auto_label，因为我们还要做过滤)
            detections = labeler.predict(str(img_path))
        except Exception as e:
            logger.warning(f"预标注失败: {e}")
            detections = []

        # ---------- 5) 置信度过滤 + 质量评估 ----------
        if detections:
            # a) 丢弃 conf < CONF_MIN_WRITE 的框 (太不可靠, 不进标注)
            keep = [d for d in detections if float(d.get("conf", 0)) >= CONF_MIN_WRITE]
            # b) 统计
            all_confs = [float(d.get("conf", 0)) for d in keep]
            labels_count = len(keep)
            avg_confidence = round(sum(all_confs) / len(all_confs), 4) if all_confs else 0.0
            low_cnt = sum(1 for c in all_confs if c < CONF_LOW_MARK)
            low_conf_ratio = round(low_cnt / len(all_confs), 3) if all_confs else 0.0

            # c) 写 photo_labels 明细 (保留原始 dets，包含丢弃的低置信度框也可以一并入库供审计)
            if self.storage is not None and photo_id is not None:
                self.storage.add_photo_labels_batch(photo_id, detections)

            # d) 重写 YOLO label.txt （只用 keep 的）
            label_path = UPLOAD_DIR / f"{img_path.stem}.txt"
            lines = []
            for d in keep:
                cx, cy, bw, bh = d["bbox_yolo"]
                lines.append(f"{d['cls_id']} {cx:.6f} {cy:.6f} {bw:.6f} {bh:.6f}")
            label_path.write_text("\n".join(lines) + "\n" if lines else "")
        else:
            # 0 个目标: 写空标签 (负样本)
            label_path = UPLOAD_DIR / f"{img_path.stem}.txt"
            label_path.write_text("")
            labels_count = 0
            avg_confidence = 0.0
            low_conf_ratio = 0.0

        # ---------- 6) 判定最终 status ----------
        if labels_count == 0:
            final_status = "need_review"  # 空图: 需人工确认 (也许是新场景)
        elif avg_confidence < AVG_CONF_GOOD or low_conf_ratio > LOW_RATIO_GOOD:
            final_status = "need_review"  # 质量差: 需人工复核
        else:
            final_status = "labeled"       # 高质量: 可自动进入 (仍可人工抽查)

        if self.storage is not None and photo_id is not None:
            self.storage.update_photo_status(
                photo_id, final_status,
                labels_count=labels_count,
                avg_confidence=avg_confidence,
                low_conf_ratio=low_conf_ratio,
            )

        # ---------- 7) upload_history JSON (保持兼容) ----------
        record = {
            "photo_id": photo_id,
            "uuid": photo_uuid,
            "filename": safe_filename,
            "phone": phone,
            "location": location,
            "tags": tags or [],
            "remark": remark,
            "time": now_str(),
            "labels_count": labels_count,
            "status": final_status,
            "avg_confidence": avg_confidence,
            "low_conf_ratio": low_conf_ratio,
            "duplicate": duplicate,
        }
        self.upload_history.append(record)
        if len(self.upload_history) > 500:
            self.upload_history = self.upload_history[-500:]
        safe_json_dump(self.upload_history, str(UPLOAD_DIR / ".upload_history.json"))

        logger.info(
            f"上传: {safe_filename} | id={photo_id} | "
            f"伪标签 {labels_count} 个 | avg_conf={avg_confidence:.2f} | "
            f"low_ratio={low_conf_ratio:.0%} → status={final_status}"
            + (" [DUPLICATE]" if duplicate else "")
        )
        return record

    # ============================================================
    # 审核接口 (review)
    # ============================================================

    def relabel_photo(self, photo_id: int) -> dict:
        """重新跑一次 AutoLabeler (不改变原上传内容, 只更新标注)"""
        if self.storage is None:
            return {"ok": False, "error": "storage 未启用"}
        photo = self.storage.get_photo(photo_id)
        if not photo:
            return {"ok": False, "error": "photo_id 不存在"}
        img_path = Path(photo["file_path"])
        if not img_path.exists():
            return {"ok": False, "error": f"图片文件缺失: {photo['file_path']}"}

        self.storage.update_photo_status(photo_id, "labeling")
        self.storage.delete_photo_labels(photo_id)

        try:
            labeler = self._get_labeler()
            dets = labeler.predict(str(img_path))
            keep = [d for d in dets if float(d.get("conf", 0)) >= CONF_MIN_WRITE]

            # 入库
            self.storage.add_photo_labels_batch(photo_id, dets)

            # 重写标签
            label_path = img_path.with_suffix(".txt") if img_path.suffix.lower() != ".txt" \
                else Path(str(img_path) + ".txt")
            label_path = UPLOAD_DIR / f"{img_path.stem}.txt"
            lines = [f"{d['cls_id']} {d['bbox_yolo'][0]:.6f} {d['bbox_yolo'][1]:.6f} "
                     f"{d['bbox_yolo'][2]:.6f} {d['bbox_yolo'][3]:.6f}" for d in keep]
            label_path.write_text("\n".join(lines) + "\n" if lines else "")

            all_confs = [float(d.get("conf", 0)) for d in keep]
            labels_count = len(keep)
            avg_conf = round(sum(all_confs) / labels_count, 4) if labels_count else 0.0
            low_cnt = sum(1 for c in all_confs if c < CONF_LOW_MARK)
            low_ratio = round(low_cnt / labels_count, 3) if labels_count else 0.0
            status = ("labeled" if labels_count > 0
                      and avg_conf >= AVG_CONF_GOOD and low_ratio <= LOW_RATIO_GOOD
                      else "need_review")
            self.storage.update_photo_status(
                photo_id, status, labels_count=labels_count,
                avg_confidence=avg_conf, low_conf_ratio=low_ratio,
            )
            return {"ok": True, "photo_id": photo_id, "labels_count": labels_count,
                    "status": status, "avg_confidence": avg_conf,
                    "low_conf_ratio": low_ratio}
        except Exception as e:
            logger.exception("重标失败")
            self.storage.update_photo_status(photo_id, "need_review")
            return {"ok": False, "error": str(e)}

    def approve_photo(self, photo_id: int, reviewer: str = "web") -> dict:
        if self.storage is None:
            return {"ok": False, "error": "storage 未启用"}
        photo = self.storage.get_photo(photo_id)
        if not photo:
            return {"ok": False, "error": "photo_id 不存在"}
        # 若此时还没 .txt 标注 (edge case: labeled空的need_review但直接approve), 补写空标签
        label_path = Path(photo["file_path"])
        label_path = label_path.parent / f"{label_path.stem}.txt"
        if not label_path.exists():
            label_path.write_text("")
        self.storage.update_photo_status(photo_id, "reviewed", review_by=reviewer)

        # 同步 .approved.json (保持老逻辑兼容)
        approved_file = UPLOAD_DIR / ".approved.json"
        approved = safe_json_load(str(approved_file), default=[])
        fn = photo["filename"]
        if fn not in approved:
            approved.append(fn)
        safe_json_dump(approved, str(approved_file))

        return {"ok": True, "photo_id": photo_id, "status": "reviewed", "review_by": reviewer}

    def reject_photo(self, photo_id: int, reviewer: str = "web") -> dict:
        if self.storage is None:
            return {"ok": False, "error": "storage 未启用"}
        photo = self.storage.get_photo(photo_id)
        if not photo:
            return {"ok": False, "error": "photo_id 不存在"}
        self.storage.update_photo_status(photo_id, "rejected", review_by=reviewer)
        return {"ok": True, "photo_id": photo_id, "status": "rejected", "review_by": reviewer}

    # ============================================================
    # 状态查询
    # ============================================================

    def get_status(self) -> dict:
        """获取训练状态 / 流水线总体状态"""
        today = datetime.now().strftime("%Y-%m-%d")
        today_uploads = sum(1 for r in self.upload_history
                            if r["time"].startswith(today))

        # Storage 优先 (全局完整视角)
        photos_by_status: Dict[str, int] = {}
        pending_train = 0
        pending_review = 0
        if self.storage is not None:
            photos_by_status = self.storage.count_photos_by_status()
            pending_train = photos_by_status.get("reviewed", 0)
            pending_review = sum(photos_by_status.get(s, 0) for s in
                                 ("uploaded", "labeling", "labeled", "need_review"))
        else:
            # Fallback: 基于 JSON 粗估
            pending_train = sum(1 for r in self.upload_history
                                if r.get("status") in ("reviewed",))
            pending_review = sum(1 for r in self.upload_history
                                 if r.get("status") in (None, "uploaded", "labeled", "need_review"))
            photos_by_status = {}
            for r in self.upload_history:
                s = r.get("status", "uploaded")
                photos_by_status[s] = photos_by_status.get(s, 0) + 1

        return {
            "today_uploads": today_uploads,
            "total_uploads": len(self.upload_history),
            "photos_by_status": photos_by_status,
            "pending_train": pending_train,
            "pending_review": pending_review,
            "training_running": self._training_status["running"],
            "training_progress": self._training_status["progress"],
            "last_training": self._training_status["last_run"],
            "last_result": self._training_status["last_result"],
            "current_model": self.registry.get_current_model(),
            "min_for_retrain": self.min_new_images,
            "quality_threshold": {
                "avg_conf_good": AVG_CONF_GOOD,
                "low_ratio_good": LOW_RATIO_GOOD,
                "min_write_conf": CONF_MIN_WRITE,
                "low_conf_mark": CONF_LOW_MARK,
            },
            "storage_enabled": self.storage is not None,
            "recent": [
                {"filename": r["filename"][:40], "time": r["time"][11:19],
                 "status": r.get("status", "uploaded"),
                 "ok": r.get("status") in ("labeled", "reviewed", "trained", "training")}
                for r in self.upload_history[-20:]
            ],
        }

    def _count_pending_review(self) -> int:
        return self.get_status()["pending_review"]

    def trigger_retrain(self, force: bool = False) -> dict:
        """触发重训练。
        收集顺序:
          1) storage 存在时: SELECT photos WHERE status='reviewed' AND training_run_id IS NULL
          2) 退化: upload_history JSON 中 status=uploaded 且未在 .approved.json 的
        训练开始登记到 training_runs 表, 并把涉及的照片置为 training。
        """
        # 收集新图片
        collected = self._collect_new_training_data()
        new_images = collected["filenames"]

        if not force and len(new_images) < self.min_new_images:
            return {
                "ok": False,
                "error": f"「已通过」图片不足 ({len(new_images)}/{self.min_new_images})。"
                         f"可在 /review 页面通过图片，或使用 --force 强制训练。",
                "count": len(new_images),
                "collected_from": collected.get("source"),
            }

        if self._training_lock.locked():
            return {"ok": False, "error": "训练进行中，请稍后再试"}

        # ---- 登记 training run ----
        run_id = None
        run_uuid = uuid.uuid4().hex[:12]
        if self.storage is not None:
            run_id = self.storage.start_training_run(
                run_uuid=run_uuid,
                trigger_type="force" if force else "auto",
                base_model=str(self.model_path),
                new_images=len(new_images),
                total_images=len(new_images),  # 后期可叠加已有训练集
                epochs=30,
            )
            # 将关联的 photo_ids 更新为 status=training + training_run_id
            for pid in collected.get("photo_ids", []):
                self.storage.update_photo_status(
                    pid, "training", training_run_id=run_id,
                    details={"collect_stage": "trigger_retrain", "run_uuid": run_uuid},
                )

        # 后台线程执行训练
        thread = threading.Thread(
            target=self._run_training,
            args=(new_images, {"run_id": run_id, "run_uuid": run_uuid,
                               "photo_ids": collected.get("photo_ids", [])}),
            daemon=True,
        )
        thread.start()

        return {
            "ok": True,
            "count": len(new_images),
            "run_id": run_id,
            "run_uuid": run_uuid,
            "message": f"训练已启动, 新图片: {len(new_images)} 张 (run_id={run_id})",
        }

    def _collect_new_training_data(self) -> dict:
        """收集新图片加入训练集
        Returns:
            {"filenames":[...], "photo_ids":[...], "source":"storage|json_legacy"}
        """
        # ---------- 优先走 storage (status=reviewed) ----------
        if self.storage is not None:
            reviewed = self.storage.query_photos(status="reviewed", limit=5000)
            approved_list = safe_json_load(
                str(UPLOAD_DIR / ".approved.json"), default=[]
            )
            filenames = []
            photo_ids = []
            ensure_dir(TRAINING_DIR)
            for p in reviewed:
                if p.get("training_run_id") is not None:
                    continue  # 已经参与过训练
                fn = p["filename"]
                img_path = Path(p.get("file_path") or "")
                if not img_path.exists():
                    img_path = UPLOAD_DIR / fn
                label_path = UPLOAD_DIR / f"{img_path.stem}.txt"
                if not img_path.exists():
                    logger.warning(f"[collect] 图片文件缺失, 跳过: {fn}")
                    continue
                # 训练集拷贝 (没有标签 = 负样本也要拷贝图片，空标签可跳过)
                shutil.copy2(img_path, TRAINING_DIR / fn)
                if label_path.exists():
                    shutil.copy2(label_path, TRAINING_DIR / label_path.name)
                filenames.append(fn)
                photo_ids.append(p["id"])
                # 同步 .approved.json (兼容老逻辑)
                if fn not in approved_list:
                    approved_list.append(fn)

            if approved_list:
                safe_json_dump(approved_list, str(UPLOAD_DIR / ".approved.json"))
            # 同步 upload_history JSON status
            for r in self.upload_history:
                if r.get("filename") in filenames:
                    r["status"] = "training"
            if self.upload_history:
                safe_json_dump(self.upload_history,
                               str(UPLOAD_DIR / ".upload_history.json"))
            return {
                "filenames": filenames,
                "photo_ids": photo_ids,
                "source": "storage",
            }

        # ---------- Fallback: JSON 逻辑 (storage 关闭时) ----------
        approved = safe_json_load(str(UPLOAD_DIR / ".approved.json"), default=[])
        filenames = []

        for record in self.upload_history:
            if record.get("status") != "uploaded":
                continue
            filename = record["filename"]
            if filename in approved:
                continue
            img_path = UPLOAD_DIR / filename
            label_path = UPLOAD_DIR / f"{Path(filename).stem}.txt"

            if img_path.exists() and label_path.exists():
                dest_img = TRAINING_DIR / filename
                dest_label = TRAINING_DIR / f"{Path(filename).stem}.txt"
                shutil.copy2(img_path, dest_img)
                if label_path.stat().st_size > 0:
                    shutil.copy2(label_path, dest_label)
                filenames.append(filename)
                record["status"] = "training"
                approved.append(filename)

        safe_json_dump(self.upload_history, str(UPLOAD_DIR / ".upload_history.json"))
        safe_json_dump(approved, str(UPLOAD_DIR / ".approved.json"))
        return {"filenames": filenames, "photo_ids": [], "source": "json_legacy"}

    def _run_training(self, new_images: list, meta: dict = None):
        """执行训练 (后台线程)
        meta: {"run_id": int|None, "run_uuid": str, "photo_ids": [int,...]}
        """
        meta = meta or {}
        run_id = meta.get("run_id")
        photo_ids = meta.get("photo_ids", []) or []
        run_uuid = meta.get("run_uuid") or uuid.uuid4().hex[:12]
        map50 = None
        output_model_path = ""
        final_status = "failed"
        error_msg = ""
        metrics_out: Dict[str, Any] = {}

        with self._training_lock:
            self._training_status["running"] = True
            self._training_status["progress"] = "开始训练..."

            try:
                timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
                output_name = f"auto_retrain_{timestamp}"
                output_dir = Path("runs/auto_train") / output_name

                logger.info(
                    f"自动训练启动: run_uuid={run_uuid} run_id={run_id} "
                    f"| 新图片 {len(new_images)} 张 | 输出: {output_name}"
                )
                self._training_status["progress"] = \
                    f"训练中 ({len(new_images)} 新图片)..."

                # 调用训练脚本
                cmd = [
                    sys.executable, "scripts/train.py",
                    "--config", "configs/smart_construction.yaml",
                    "--model", str(self.model_path),
                    "--epochs", "30",   # 增量训练, 较少 epochs
                    "--batch", "8",
                    "--device", self.device,
                    "--project", "runs/auto_train",
                    "--name", output_name,
                ]

                result = subprocess.run(
                    cmd, capture_output=True, text=True,
                    timeout=3600,
                    cwd=str(Path(__file__).resolve().parent.parent),
                )

                if result.returncode == 0:
                    # best.pt → 注册 + 切换为当前模型
                    best_pt = output_dir / "weights" / "best.pt"
                    if best_pt.exists():
                        output_model_path = str(best_pt)
                        self.registry.add_version(
                            output_model_path,
                            notes=f"自动训练 run={run_id or '-'} - {len(new_images)} 新图片",
                        )
                        self.model_path = best_pt

                    # 尝试从 results.csv 取最后一行的 metrics/mAP50
                    metrics_out = self._parse_training_metrics(output_dir, result.stdout)
                    map50 = metrics_out.get("map50")
                    final_status = "success"
                    self._training_status["last_result"] = "成功"
                    self._training_status["progress"] = f"训练完成 (mAP50={map50:.3f})" if map50 else "训练完成"
                    logger.info(f"自动训练完成: {output_name} mAP50={map50}")
                else:
                    final_status = "failed"
                    error_msg = result.stderr[:400] if result.stderr else "train.py exit non-zero"
                    self._training_status["last_result"] = "失败"
                    self._training_status["progress"] = "训练失败 (见 training_runs.error_msg)"
                    logger.error(f"自动训练失败: {error_msg[:200]}")

                self._training_status["last_run"] = now_str()

                # 写 JSON 训练历史 (兼容老字段)
                self.registry.add_training_record({
                    "run_uuid": run_uuid, "run_id": run_id,
                    "time": now_str(), "images": len(new_images),
                    "output": output_name,
                    "result": "成功" if result.returncode == 0 else "失败",
                    "error": error_msg,
                    "map50": map50,
                })

            except subprocess.TimeoutExpired:
                final_status = "timeout"
                error_msg = "subprocess timeout (3600s)"
                self._training_status["last_result"] = "超时"
                self._training_status["progress"] = "训练超时"
                logger.error("自动训练超时 (1h)")
            except Exception as e:
                final_status = "failed"
                error_msg = f"{type(e).__name__}: {e}"[:400]
                self._training_status["last_result"] = "错误"
                self._training_status["progress"] = error_msg[:80]
                logger.error(f"自动训练异常: {e}")
            finally:
                # ---- DB 收尾 ----
                if self.storage is not None and run_id is not None:
                    self.storage.finish_training_run(
                        run_id, status=final_status,
                        output_model=output_model_path,
                        map50=map50, error_msg=error_msg,
                        metrics=metrics_out or None,
                    )
                    if final_status == "success":
                        # 把参与训练的照片置为 trained
                        for pid in photo_ids:
                            self.storage.update_photo_status(pid, "trained")
                    else:
                        # 失败/超时: 回到 reviewed，允许下次重新参与
                        for pid in photo_ids:
                            self.storage.update_photo_status(
                                pid, "reviewed",
                                details={"train_failed": final_status,
                                         "last_run_id": run_id},
                            )
                self._training_status["running"] = False

    @staticmethod
    def _parse_training_metrics(output_dir: Path, stdout: str) -> dict:
        """从 ultralytics 输出目录提取核心指标"""
        out: Dict[str, Any] = {}
        csv_path = output_dir / "results.csv"
        try:
            if csv_path.exists():
                import csv
                with open(csv_path, "r", encoding="utf-8", errors="ignore") as f:
                    rows = list(csv.DictReader(f))
                if rows:
                    last = rows[-1]
                    for col, key in [
                        ("metrics/mAP50(B)", "map50"),
                        ("metrics/mAP50-95(B)", "map50_95"),
                        ("metrics/precision(B)", "precision"),
                        ("metrics/recall(B)", "recall"),
                        ("train/box_loss", "train_box_loss"),
                        ("val/box_loss", "val_box_loss"),
                    ]:
                        if col in last and last[col].strip() != "":
                            try:
                                out[key] = float(last[col])
                            except ValueError:
                                pass
        except Exception as e:
            out["parse_error"] = str(e)
        out["output_dir"] = str(output_dir)
        return out


# ============================================================
# Flask 应用
# ============================================================

REVIEW_PAGE = """<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>智慧工地 - 标注审核</title>
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:"Microsoft YaHei",sans-serif;background:#0f1923;color:#e0e0e0;padding:15px}
.header{text-align:center;padding:15px;margin-bottom:15px;border-bottom:2px solid #2a3a4a}
.header h1{color:#00d4ff;font-size:20px}
.tabs{display:flex;gap:8px;margin-bottom:15px;flex-wrap:wrap}
.tab{padding:8px 14px;background:#1a2a3a;border:1px solid #2a3a4a;border-radius:8px;color:#8899aa;cursor:pointer;font-size:13px}
.tab.active{background:#00d4ff;color:#0f1923;border-color:#00d4ff;font-weight:bold}
.stats{display:grid;grid-template-columns:repeat(auto-fill,minmax(130px,1fr));gap:10px;margin-bottom:15px}
.stat{background:#1a2a3a;border-radius:8px;padding:12px;text-align:center}
.stat .v{font-size:22px;font-weight:bold;color:#00d4ff}
.stat .l{font-size:11px;color:#8899aa;margin-top:3px}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(240px,1fr));gap:10px}
.card{background:#1a2a3a;border-radius:8px;overflow:hidden;border:2px solid #2a3a4a;position:relative;display:flex;flex-direction:column}
.card.pending{border-color:#ffaa00}
.card.labeled{border-color:#00aacc}
.card.need_review{border-color:#ff4444}
.card.reviewed{border-color:#00ff88}
.card img{width:100%;display:block;aspect-ratio:4/3;object-fit:cover;background:#000}
.card .badge{position:absolute;top:6px;right:6px;padding:3px 8px;border-radius:10px;font-size:11px;font-weight:bold}
.card .badge.pending{background:#ffaa00;color:#000}
.card .badge.labeled{background:#00aacc;color:#fff}
.card .badge.need_review{background:#ff4444;color:#fff}
.card .badge.reviewed{background:#00ff88;color:#000}
.card .info{padding:8px 10px;font-size:12px;flex:1}
.card .info .name{color:#e0e0e0;word-break:break-all;font-weight:bold;margin-bottom:4px}
.card .info .meta{color:#8899aa;font-size:11px;line-height:1.5}
.card .info .meta span.b{color:#e0e0e0;font-weight:bold}
.card .actions{display:flex;gap:5px;padding:0 10px 10px}
.card .actions button{flex:1;padding:7px;border:none;border-radius:5px;font-size:12px;cursor:pointer;font-weight:bold}
.btn-relabel{background:#ffaa00;color:#0f1923}
.btn-approve{background:#00ff88;color:#0f1923}
.btn-reject{background:#ff4444;color:#fff}
.btn-train{background:#00d4ff;color:#0f1923;padding:14px;font-size:16px;width:100%;border:none;border-radius:8px;margin-top:15px;cursor:pointer;font-weight:bold}
.btn-train:disabled{background:#3a5a6a;color:#8899aa;cursor:not-allowed}
.toast{position:fixed;top:15px;left:50%;transform:translateX(-50%);padding:12px 24px;border-radius:8px;z-index:9999;font-weight:bold;display:none}
.toast.ok{background:#00ff88;color:#0f1923}
.toast.err{background:#ff4444;color:#fff}
</style>
</head>
<body>
<div class="header"><h1>📸 标注审核面板</h1></div>
<div class="stats" id="stats"></div>
<div class="tabs" id="tabs">
  <div class="tab active" data-status="pending">待审核</div>
  <div class="tab" data-status="all">全部</div>
  <div class="tab" data-status="labeled">高质量已标注</div>
  <div class="tab" data-status="need_review">需人工复核</div>
  <div class="tab" data-status="reviewed">已通过</div>
  <div class="tab" data-status="rejected">已拒绝</div>
</div>
<div class="grid" id="grid"></div>
<button class="btn-train" id="trainBtn" onclick="triggerTrain()">🚀 触发重训练 (自动收集「已通过」图片)</button>
<div class="toast" id="toast"></div>
<script>
let curStatus = 'pending';
const statusMap = {
  pending:   {tag:'待审',  cls:'pending',    filter:'uploaded,labeled,labeling,need_review'},
  all:       {tag:'全部',  cls:'',           filter:''},
  labeled:   {tag:'已标',  cls:'labeled',    filter:'labeled'},
  need_review:{tag:'需复核',cls:'need_review',filter:'need_review'},
  reviewed:  {tag:'通过',  cls:'reviewed',   filter:'reviewed'},
  rejected:  {tag:'拒绝',  cls:'rejected',   filter:'rejected'},
};

function toast(msg, ok){
  const t = document.getElementById('toast');
  t.textContent = msg; t.className = 'toast ' + (ok?'ok':'err');
  t.style.display='block'; setTimeout(()=>t.style.display='none', 2200);
}
document.querySelectorAll('.tab').forEach(t=>{
  t.addEventListener('click',()=>{
    document.querySelectorAll('.tab').forEach(x=>x.classList.remove('active'));
    t.classList.add('active');
    curStatus = t.dataset.status;
    load();
  });
});

async function load(){
  const [statusR, listR] = await Promise.all([fetch('/api/status'),
    fetch('/api/review/list?status=' + encodeURIComponent(curStatus))]);
  const status = await statusR.json();
  const list = await listR.json();

  // 顶部统计
  const s = status.photos_by_status || {};
  const total = Object.values(s).reduce((a,b)=>a+b,0);
  const box = (l,v)=>`<div class="stat"><div class="v">${v}</div><div class="l">${l}</div></div>`;
  document.getElementById('stats').innerHTML =
    box('上传总数', total) +
    box('待审核(总)', status.pending_review) +
    box('高质量已标', s.labeled||0) +
    box('需人工复核', s.need_review||0) +
    box('已通过(可训练)', s.reviewed||0) +
    box('已拒绝', s.rejected||0) +
    box('训练中/已完成', (s.training||0)+(s.trained||0)) +
    box('今日上传', status.today_uploads);

  const grid = document.getElementById('grid');
  if(!list.photos || list.photos.length===0){
    grid.innerHTML = '<div style="grid-column:1/-1;text-align:center;padding:40px;color:#667788">该分类暂无图片</div>';
    return;
  }
  grid.innerHTML = list.photos.map(p=>{
    const st = p.status || 'uploaded';
    const stCfg = statusMap[st] || statusMap.pending;
    return `<div class="card ${stCfg.cls}">
      <div class="badge ${stCfg.cls}">${stCfg.tag}</div>
      <img src="/photos/${encodeURIComponent(p.filename)}" loading="lazy">
      <div class="info">
        <div class="name">#${p.id} ${(p.filename||'').slice(0,40)}</div>
        <div class="meta">
          上传: <span class="b">${(p.uploader_name||p.uploader_phone||'匿名')}</span> (${p.uploader_team||'-'})<br>
          地点: <span class="b">${p.location_tag||'-'}</span><br>
          伪标签: <span class="b">${p.labels_count||0}</span>框　平均置信: <span class="b">${(p.avg_confidence||0).toFixed(2)}</span><br>
          低质量框占比: <span class="b">${((p.low_conf_ratio||0)*100).toFixed(0)}%</span><br>
          上传时间: ${(p.created_at||'').slice(5,16)}
        </div>
      </div>
      <div class="actions">
        <button class="btn-relabel" onclick="relabel(${p.id})">重标</button>
        <button class="btn-approve" onclick="approve(${p.id})">通过</button>
        <button class="btn-reject" onclick="reject(${p.id})">拒绝</button>
      </div>
    </div>`;
  }).join('');
}

async function doAction(url, id, okMsg){
  try{
    const r = await fetch(url + id, {method:'POST'});
    const d = await r.json();
    if(d.ok){ toast(okMsg + ' #'+id, true); load(); }
    else { toast('失败: ' + (d.error||''), false); }
  }catch(e){ toast('网络错误: '+e.message, false); }
}
function relabel(id){ doAction('/api/review/relabel/', id, '已重标'); }
function approve(id){ doAction('/api/review/approve/', id, '已通过'); }
function reject(id){ doAction('/api/review/reject/', id, '已拒绝'); }

async function triggerTrain(){
  const btn = document.getElementById('trainBtn');
  btn.disabled = true;
  btn.textContent = '请求中...';
  try{
    const r = await fetch('/api/trigger_retrain', {method:'POST'});
    const d = await r.json();
    if(d.ok){ toast('✅ ' + (d.message||'已启动'), true); }
    else    { toast('⚠️ ' + (d.error||'启动失败'), false); btn.disabled = false; }
  }catch(e){ toast('网络错误', false); btn.disabled = false; }
  // 2s 后重新启用按钮 + 刷新
  setTimeout(()=>{ btn.disabled=false; btn.textContent='🚀 触发重训练 (自动收集「已通过」图片)'; load(); }, 4000);
}

load();
setInterval(load, 20000);
</script>
</body>
</html>"""


def create_app(manager: AutoRetrainManager):
    from flask import Flask, request, jsonify, send_from_directory

    app = Flask(__name__)
    app.config["MAX_CONTENT_LENGTH"] = 50 * 1024 * 1024  # 50MB

    # ========================================================
    # 页面
    # ========================================================
    @app.route("/")
    def index():
        return MOBILE_UPLOAD_PAGE

    @app.route("/review")
    def review_page():
        return REVIEW_PAGE

    # ========================================================
    # 上传 & 状态
    # ========================================================
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
                uploader_name=request.form.get("name", ""),
                uploader_team=request.form.get("team", ""),
            )
            resp = {
                "ok": True,
                "filename": record["filename"],
                "labels": record["labels_count"],
                "status": record.get("status"),
                "photo_id": record.get("photo_id"),
                "duplicate": record.get("duplicate", False),
                "avg_confidence": record.get("avg_confidence", 0),
                "low_conf_ratio": record.get("low_conf_ratio", 0),
            }
            if record.get("duplicate"):
                resp["message"] = record.get("message", "duplicate")
            return jsonify(resp)
        except Exception as e:
            logger.exception("上传接口异常")
            return jsonify({"ok": False, "error": str(e)}), 500

    @app.route("/api/status")
    def api_status():
        st = manager.get_status()
        # 补充 DB 里的最新训练 run
        if manager.storage is not None:
            latest = manager.storage.get_latest_training_run()
            if latest:
                st["last_training_run"] = {
                    "id": latest["id"], "status": latest["status"],
                    "new_images": latest["new_images"],
                    "total_images": latest["total_images"],
                    "started_at": latest["started_at"],
                    "finished_at": latest.get("finished_at"),
                    "map50": latest.get("map50"),
                    "output_model": latest.get("output_model"),
                    "error_msg": latest.get("error_msg"),
                }
        return jsonify(st)

    # ========================================================
    # 标注审核接口
    # ========================================================
    @app.route("/api/review/list")
    def api_review_list():
        status = request.args.get("status", "pending")
        limit = min(int(request.args.get("limit", 50)), 200)
        offset = int(request.args.get("offset", 0))

        photos = []
        if manager.storage is None:
            # 退化为 JSON 历史 (不含标注明细)
            for r in manager.upload_history[-limit:]:
                photos.append({
                    "id": r.get("photo_id") or 0,
                    "filename": r["filename"],
                    "status": r.get("status", "uploaded"),
                    "labels_count": r.get("labels_count", 0),
                    "avg_confidence": r.get("avg_confidence", 0),
                    "low_conf_ratio": r.get("low_conf_ratio", 0),
                    "uploader_phone": r.get("phone", ""),
                    "location_tag": r.get("location", ""),
                    "created_at": r.get("time", ""),
                })
        else:
            kw = {"limit": limit, "offset": offset}
            if status == "pending":
                kw["need_review"] = True
            elif status in ("uploaded", "labeling", "labeled", "need_review",
                            "reviewed", "rejected", "training", "trained"):
                kw["status"] = status
            # "all" → 不加过滤
            photos = manager.storage.query_photos(**kw)

        return jsonify({
            "ok": True, "status_filter": status,
            "count": len(photos), "photos": photos,
        })

    @app.route("/api/review/photo/<int:photo_id>")
    def api_review_photo(photo_id):
        if manager.storage is None:
            return jsonify({"ok": False, "error": "storage 未启用"}), 503
        photo = manager.storage.get_photo(photo_id)
        if not photo:
            return jsonify({"ok": False, "error": "不存在"}), 404
        labels = manager.storage.query_photo_labels(photo_id)
        return jsonify({"ok": True, "photo": photo, "labels": labels})

    @app.route("/api/review/approve/<int:photo_id>", methods=["POST"])
    def api_approve(photo_id):
        reviewer = request.args.get("by", "web")
        return jsonify(manager.approve_photo(photo_id, reviewer))

    @app.route("/api/review/reject/<int:photo_id>", methods=["POST"])
    def api_reject(photo_id):
        reviewer = request.args.get("by", "web")
        return jsonify(manager.reject_photo(photo_id, reviewer))

    @app.route("/api/review/relabel/<int:photo_id>", methods=["POST"])
    def api_relabel(photo_id):
        return jsonify(manager.relabel_photo(photo_id))

    # ========================================================
    # 训练触发 / 模型
    # ========================================================
    @app.route("/api/trigger_retrain", methods=["POST"])
    def api_trigger_retrain():
        force = request.args.get("force", "0") == "1"
        result = manager.trigger_retrain(force=force)
        return jsonify(result)

    @app.route("/api/models")
    def api_models():
        res = {
            "current": manager.registry.get_current_model(),
            "versions": manager.registry.get_versions(),
        }
        if manager.storage is not None:
            res["training_runs"] = manager.storage.query_training_runs(limit=10)
        return jsonify(res)

    @app.route("/photos/<filename>")
    def serve_photo(filename):
        return send_from_directory(str(UPLOAD_DIR), filename)

    return app


# ============================================================
# 主函数
# ============================================================

def main():
    parser = argparse.ArgumentParser(description="拍照上传 + 自动训练流水线")
    parser.add_argument("--model", type=str, required=True, help="当前模型路径 (用于伪标签 & 增量训练起点)")
    parser.add_argument("--port", type=int, default=8096, help="服务端口 (上传页 + 审核页共用)")
    parser.add_argument("--host", type=str, default="0.0.0.0", help="监听地址")
    parser.add_argument("--device", type=str, default="cpu", help="训练/推理设备 cpu/cuda:0/...")
    parser.add_argument("--min-images", type=int, default=MIN_NEW_IMAGES,
                        help="触发训练的最小新图片数 (默认 20)")
    parser.add_argument("--db", type=str, default="runs/data/site.db",
                        help="SQLite 存储路径 (默认 runs/data/site.db)")
    parser.add_argument("--no-storage", action="store_true",
                        help="禁用 SQLite 持久化 (仅写 JSON 历史)")
    parser.add_argument("--train-only", action="store_true",
                        help="不启动 web，只执行一次 trigger_retrain 后退出")
    parser.add_argument("--pipeline-run", action="store_true",
                        help="不启动 web：扫描 datasets/uploaded 目录 → 标注 → 质量判定 → 自动审核(高质量) → 触发训练")
    parser.add_argument("--force", action="store_true",
                        help="强制训练 (忽略 --min-images 门槛)")
    parser.add_argument("--auto-approve-high-quality", action="store_true",
                        help="[--pipeline-run 专用] 高质量(status=labeled)的图自动晋升 reviewed")

    args = parser.parse_args()

    # ---- Storage ----
    storage = None
    if not args.no_storage:
        from utils.storage import SiteDatabase
        storage = SiteDatabase(args.db)

    manager = AutoRetrainManager(
        model_path=args.model,
        device=args.device,
        min_new_images=args.min_images,
        storage=storage,
    )

    # ---- Pipeline 批处理模式 ----
    if args.pipeline_run:
        from scripts.auto_label import AutoLabeler
        labeler = AutoLabeler(args.model, device=args.device)
        image_exts = {".jpg", ".jpeg", ".png", ".bmp", ".webp"}
        files = sorted([p for p in Path(UPLOAD_DIR).iterdir()
                        if p.is_file() and p.suffix.lower() in image_exts])
        print(f"[Pipeline] 发现 {len(files)} 张图片 (目录: {UPLOAD_DIR})")
        processed = 0
        for fp in files:
            # 已被 storage 记录且 status!=uploaded 的跳过
            if storage is not None:
                with open(fp, "rb") as f:
                    h = storage.compute_content_hash(f.read())
                existing = storage.find_photo_by_hash(h)
                if existing and existing.get("status") not in ("uploaded",):
                    continue
            record = manager.handle_upload(
                image_data=fp.read_bytes(),
                filename=fp.name,
                phone="pipeline", location="", tags=[], remark="pipeline_batch",
            )
            processed += 1
            # 高质量自动过审 → reviewed
            if args.auto_approve_high_quality and \
               record.get("status") == "labeled" and \
               storage is not None and record.get("photo_id"):
                manager.approve_photo(record["photo_id"], reviewer="pipeline_auto")
            status = record.get("status")
            flag = '⚠️' if status=='need_review' else ('✅' if status=='labeled' else '📋')
            print(f"  {flag} #{record.get('photo_id') or '?':>3} {fp.name:<40s} "
                  f"{record.get('labels_count',0):>2d}框 avg_conf={record.get('avg_confidence',0):.2f} "
                  f"→ {status}" + ("  [DUP]" if record.get('duplicate') else ""))
        print(f"[Pipeline] 处理 {processed} 张")
        if storage:
            c = storage.count_photos_by_status()
            print(f"[Pipeline] 图片状态分布: {c}")
        # 尝试触发训练
        res = manager.trigger_retrain(force=args.force)
        print(f"[Pipeline] trigger_retrain: {json.dumps(res, ensure_ascii=False, indent=2)}")
        return

    # ---- 仅训练一次 ----
    if args.train_only:
        result = manager.trigger_retrain(force=args.force)
        print(json.dumps(result, indent=2, ensure_ascii=False))
        return

    app = create_app(manager)

    print(f"\n{'='*64}")
    print(f"  智慧工地 - 拍照上传 + 自动标注 + 审核 + 重训练 统一服务")
    print(f"{'='*64}")
    print(f"  📱 手机上传页  http://{args.host}:{args.port}/")
    print(f"  ✅ 审核面板    http://{args.host}:{args.port}/review")
    print(f"  🧠 模型:       {args.model}")
    print(f"  💾 存储:       {'SQLite ' + args.db if storage else 'JSON 历史'}")
    print(f"  🚀 触发门槛:   ≥ {args.min_images} 张「已通过」图片")
    print(f"  🎯 伪标签阈值: conf≥{CONF_MIN_WRITE} 写标注, avg≥{AVG_CONF_GOOD} 且低质框<{int(LOW_RATIO_GOOD*100)}% → 高质量")
    print(f"")
    print(f"  API 列表:")
    print(f"    POST /api/upload                         上传照片 (multipart/form-data)")
    print(f"    GET  /api/status                         流水线总体状态")
    print(f"    GET  /api/review/list?status=pending     审核列表")
    print(f"    GET  /api/review/photo/<id>              单张标注详情")
    print(f"    POST /api/review/approve/<id>            通过 → status=reviewed")
    print(f"    POST /api/review/reject/<id>             拒绝 → status=rejected")
    print(f"    POST /api/review/relabel/<id>            重新跑伪标签")
    print(f"    POST /api/trigger_retrain                触发重训练 (force=1 强制)")
    print(f"    GET  /api/models                         模型版本 & 训练历史")
    print(f"    GET  /photos/<filename>                  查看原图")
    print(f"{'='*64}\n")

    app.run(host=args.host, port=args.port, debug=False)


if __name__ == "__main__":
    main()