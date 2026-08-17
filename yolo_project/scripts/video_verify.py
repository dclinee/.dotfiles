#!/usr/bin/env python3
"""
智慧工地 - 单路视频端到端验证
整合: 安全装备检测 + 入侵检测 + 统计报表 → 一次运行全部验证

输出:
  - 带标注的视频
  - 违规截图 (存入 runs/video_verify/captures/)
  - 统计报告 (CSV/JSON)
  - 事件日志

用法:
  # 完整验证
  python scripts/video_verify.py --model best.pt --source site_video.mp4

  # 仅安全检测
  python scripts/video_verify.py --model best.pt --source video.mp4 --mode safety

  # 安全+入侵
  python scripts/video_verify.py --model best.pt --source video.mp4 --zones configs/danger_zones.json --mode all
"""

import argparse
import json
import os
import sys
import time
from pathlib import Path
from datetime import datetime
from collections import defaultdict, deque
import cv2
import numpy as np
from ultralytics import YOLO

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from utils.common import (
    point_in_polygon, CLASS_NAMES, CLASS_COLORS, SAFETY_VIOLATION_CLASSES,
    bbox_iou, calc_rate, ALERT_COOLDOWN, now_str,
)
from utils.logger import get_logger

# 可选重型依赖 —— 未启用时不阻塞基础功能
try:
    from utils.storage import get_storage, SiteDatabase
    _STORAGE_AVAILABLE = True
except Exception as _e:
    _STORAGE_AVAILABLE = False
    get_storage = None
    SiteDatabase = None

try:
    from utils.notify import LarkNotifier
    _NOTIFY_AVAILABLE = True
except Exception as _e:
    _NOTIFY_AVAILABLE = False
    LarkNotifier = None


# ============================================================
# 配置
# ============================================================

# 使用 common 模块中的统一常量
SAFETY_VIOLATIONS = SAFETY_VIOLATION_CLASSES
COLORS = CLASS_COLORS


# ============================================================
# 视频验证器
# ============================================================

class VideoVerifier:
    """单路视频端到端验证器"""

    def __init__(self, model_path, source,
                 danger_zones=None, conf=0.3, iou=0.5,
                 mode="all", device="cpu",
                 output_dir="runs/video_verify",
                 save_video=True, show_display=True,
                 skip_frames=1, alert_cooldown=5,
                 camera_id="cam_01",
                 enable_storage=False, db_path="runs/data/site.db",
                 enable_notify=False, personnel_config="configs/personnel.json",
                 compliance_threshold=80.0):
        """
        Args:
            model_path: 模型权重路径
            source: 视频源 (文件/摄像头/RTSP)
            danger_zones: 危险区域多边形 [{name, points}, ...]
            conf: 置信度阈值
            iou: NMS IoU 阈值
            mode: 检测模式 (safety / intrusion / all)
            device: 设备
            output_dir: 输出目录
            save_video: 是否保存视频
            show_display: 是否显示画面
            skip_frames: 跳帧 (1=不跳, 2=隔一帧)
            alert_cooldown: 告警冷却时间 (秒)
            camera_id: 摄像头标识 (用于存储和通知)
            enable_storage: 是否启用 SQLite 持久化存储
            db_path: SQLite 数据库路径
            enable_notify: 是否启用飞书告警通知
            personnel_config: 人员角色通知配置文件路径
            compliance_threshold: 合规率告警阈值 (%), 低于即触发统计告警
        """
        self.model = YOLO(model_path)
        self.source = source
        self.danger_zones = danger_zones or []
        self.conf = conf
        self.iou = iou
        self.mode = mode
        self.device = device
        self.output_dir = Path(output_dir)
        self.save_video = save_video
        self.show_display = show_display
        self.skip_frames = skip_frames
        self.alert_cooldown = alert_cooldown
        self.camera_id = camera_id
        self.compliance_threshold = compliance_threshold

        # 创建输出目录
        self.output_dir.mkdir(parents=True, exist_ok=True)
        (self.output_dir / "captures").mkdir(exist_ok=True)
        (self.output_dir / "violations").mkdir(exist_ok=True)

        # ============================================
        # 统计 (含 Person 级合规率)
        # ============================================
        self.stats = {
            "total_frames": 0,
            "processed_frames": 0,
            # ---- 原始计数 (保留原逻辑兼容) ----
            "total_persons": 0,
            "total_helmets": 0,
            "total_no_helmets": 0,
            "total_vests": 0,
            "total_no_vests": 0,
            "total_vehicles": 0,
            "violations_captured": 0,
            "intrusions_detected": 0,
            # ---- Person 级合规 (新增, 更精确) ----
            "person_helmet_ok": 0,     # 有头盔的 person
            "person_helmet_bad": 0,    # 明确无头盔的 person
            "person_helmet_unknown": 0,# 无头盔检测结果的 person
            "person_vest_ok": 0,
            "person_vest_bad": 0,
            "person_vest_unknown": 0,
            # ---- 累计用于检测聚合 ----
            "agg_persons": 0,
            "agg_helmets": 0,
            "agg_no_helmets": 0,
            "agg_vests": 0,
            "agg_no_vests": 0,
            "agg_vehicles": 0,
            "agg_intrusions": 0,
            "start_time": time.time(),
        }

        # 告警冷却
        self._last_alert = defaultdict(float)

        # 事件日志
        self.events = []
        self._event_log_path = self.output_dir / "events.jsonl"

        # 入侵追踪
        self._intrusion_tracker = defaultdict(int)  # track_id -> count

        # 视频属性
        self._fps = 30
        self._width = 1280
        self._height = 720

        # ============================================
        # SQLite 存储 (可选)
        # ============================================
        self.storage = None
        if enable_storage:
            if not _STORAGE_AVAILABLE:
                print(f"[Storage] ⚠️  存储模块不可用, 已跳过")
            else:
                self.storage = get_storage(db_path)
                print(f"[Storage] ✅ 已启用 SQLite: {db_path}")

        # ============================================
        # 飞书通知 (可选)
        # ============================================
        self.notifier = None
        if enable_notify:
            if not _NOTIFY_AVAILABLE:
                print(f"[Notify]  ⚠️  通知模块不可用, 已跳过")
            else:
                try:
                    self.notifier = LarkNotifier(personnel_config)
                    role_count = len(self.notifier.roles)
                    print(f"[Notify]  ✅ 已启用飞书通知, {role_count} 个通知角色")
                except Exception as e:
                    print(f"[Notify]  ⚠️  初始化失败: {e}, 已跳过")

        # 合规率告警冷却 (防止同一小时反复发)
        self._last_compliance_alert = {"helmet": 0.0, "vest": 0.0}

    # ============================================================
    # Person 级合规率匹配 (新增核心能力)
    # ============================================================

    def _match_gear_to_persons(self, detections):
        """
        将 helmet / no_helmet / vest / no_vest 装备框分配给最近的 person 框。
        基于「装备中心点在 person 框上部 (头盔) / 中部 (反光衣) + 最大IoU优先」的策略。

        Args:
            detections: 本帧所有检测列表 [{"cls_id","cls_name","conf","bbox":(x1,y1,x2,y2)}, ...]

        Returns:
            person_statuses: [{
                "bbox": person_bbox,
                "helmet": "ok" / "bad" / "unknown",
                "vest":   "ok" / "bad" / "unknown",
                "helmet_bbox": gear_bbox or None,
                "vest_bbox":   gear_bbox or None,
            }, ...]
        """
        persons = [d for d in detections if d["cls_id"] == 0]
        helmets =    [d for d in detections if d["cls_id"] == 1]
        no_helmets = [d for d in detections if d["cls_id"] == 2]
        vests =      [d for d in detections if d["cls_id"] == 3]
        no_vests =   [d for d in detections if d["cls_id"] == 4]

        person_statuses = []
        assigned_helmet_idx = set()
        assigned_vest_idx = set()

        for p in persons:
            px1, py1, px2, py2 = p["bbox"]
            pw, ph = px2 - px1, py2 - py1
            if pw <= 0 or ph <= 0:
                continue

            status = {
                "bbox": p["bbox"],
                "helmet": "unknown",
                "vest": "unknown",
                "helmet_bbox": None,
                "vest_bbox": None,
                "helmet_cls_id": None,
                "vest_cls_id": None,
            }

            # ---- 找头盔: person 顶部 30% 区域内匹配最佳 IoU ----
            helmet_candidates = []
            head_area = (px1, py1, px2, py1 + ph * 0.35)  # 头部 = person 上 1/3
            for gi, g in enumerate(helmets):
                if gi in assigned_helmet_idx:
                    continue
                iou = bbox_iou(g["bbox"], head_area)
                if iou > 0.01:
                    helmet_candidates.append((iou, gi, 1, g))
            for gi, g in enumerate(no_helmets):
                if gi in assigned_helmet_idx:
                    continue
                real_idx = len(helmets) + gi
                iou = bbox_iou(g["bbox"], head_area)
                if iou > 0.01:
                    helmet_candidates.append((iou, real_idx, 2, g))

            if helmet_candidates:
                helmet_candidates.sort(reverse=True, key=lambda x: x[0])
                _, h_idx, cls_id, gear = helmet_candidates[0]
                assigned_helmet_idx.add(h_idx)
                status["helmet"] = "ok" if cls_id == 1 else "bad"
                status["helmet_bbox"] = gear["bbox"]
                status["helmet_cls_id"] = cls_id

            # ---- 找反光衣: person 中部 40%~80% 区域内匹配最佳 IoU ----
            vest_candidates = []
            vest_area = (px1, py1 + ph * 0.3, px2, py1 + ph * 0.85)
            for gi, g in enumerate(vests):
                if gi in assigned_vest_idx:
                    continue
                real_idx = 100000 + gi
                iou = bbox_iou(g["bbox"], vest_area)
                if iou > 0.01:
                    vest_candidates.append((iou, real_idx, 3, g))
            for gi, g in enumerate(no_vests):
                if gi in assigned_vest_idx:
                    continue
                real_idx = 200000 + gi
                iou = bbox_iou(g["bbox"], vest_area)
                if iou > 0.01:
                    vest_candidates.append((iou, real_idx, 4, g))

            if vest_candidates:
                vest_candidates.sort(reverse=True, key=lambda x: x[0])
                _, v_idx, cls_id, gear = vest_candidates[0]
                assigned_vest_idx.add(v_idx)
                status["vest"] = "ok" if cls_id == 3 else "bad"
                status["vest_bbox"] = gear["bbox"]
                status["vest_cls_id"] = cls_id

            person_statuses.append(status)

            # ---- 更新累计 Person 级合规 ----
            if status["helmet"] == "ok":
                self.stats["person_helmet_ok"] += 1
            elif status["helmet"] == "bad":
                self.stats["person_helmet_bad"] += 1
            else:
                self.stats["person_helmet_unknown"] += 1

            if status["vest"] == "ok":
                self.stats["person_vest_ok"] += 1
            elif status["vest"] == "bad":
                self.stats["person_vest_bad"] += 1
            else:
                self.stats["person_vest_unknown"] += 1

        return person_statuses

    # ============================================================
    # 告警存储 + 通知 (新增)
    # ============================================================

    def _dispatch_alarm(self, alarm_type: str, level: str = "high",
                        message: str = "", details: dict = None,
                        notify_kwargs: dict = None):
        """
        统一告警分发: SQLite落库 + 飞书推送 (如启用)

        Args:
            alarm_type: 告警类型 (no_helmet / no_vest / intrusion / compliance_low)
            level: high / medium / low / critical
            message: 人类可读描述
            details: 结构化细节 (存 DB)
            notify_kwargs: 传给 LarkNotifier.send_alarm 的模板变量
        """
        now = time.time()
        cooldown_key = f"{alarm_type}:{self.camera_id}"

        # 冷却
        if cooldown_key in self._last_alert:
            elapsed = now - self._last_alert[cooldown_key]
            cd = ALERT_COOLDOWN.get(alarm_type, 300)
            if elapsed < cd:
                return False

        self._last_alert[cooldown_key] = now

        # ---- 1. SQLite 落库 ----
        if self.storage is not None:
            try:
                self.storage.log_alarm(
                    alarm_type=alarm_type,
                    level=level,
                    camera_id=self.camera_id,
                    message=message,
                    details=details,
                )
            except Exception as e:
                print(f"[Storage] 写入告警失败: {e}")

            try:
                self.storage.log_event(
                    event_type=f"alarm:{alarm_type}",
                    source=self.camera_id,
                    message=message,
                    details=details,
                )
            except Exception:
                pass

        # ---- 2. 飞书通知 ----
        if self.notifier is not None:
            try:
                kwargs = notify_kwargs or {}
                self.notifier.send_alarm(
                    alarm_type,
                    camera_id=self.camera_id,
                    **kwargs,
                )
            except Exception as e:
                print(f"[Notify]  推送失败: {e}")

        return True

    def _check_and_alert_compliance(self):
        """
        定期检查 Person 级合规率, 低于阈值时发出 compliance_low 告警
        """
        now_t = time.time()
        cd = ALERT_COOLDOWN.get("compliance_low", 600)

        # ---- 头盔合规率 ----
        known_h = self.stats["person_helmet_ok"] + self.stats["person_helmet_bad"]
        if known_h >= 5:  # 样本足够才统计
            h_rate = calc_rate(self.stats["person_helmet_ok"], known_h)
            if h_rate < self.compliance_threshold:
                if now_t - self._last_compliance_alert["helmet"] > cd:
                    self._last_compliance_alert["helmet"] = now_t
                    self._dispatch_alarm(
                        alarm_type="helmet_compliance_low",
                        level="medium",
                        message=f"安全帽佩戴率仅 {h_rate}% (<{self.compliance_threshold}%)",
                        details={"rate": h_rate, "threshold": self.compliance_threshold},
                        notify_kwargs={"rate": h_rate},
                    )

        # ---- 反光衣合规率 ----
        known_v = self.stats["person_vest_ok"] + self.stats["person_vest_bad"]
        if known_v >= 5:
            v_rate = calc_rate(self.stats["person_vest_ok"], known_v)
            if v_rate < self.compliance_threshold:
                if now_t - self._last_compliance_alert["vest"] > cd:
                    self._last_compliance_alert["vest"] = now_t
                    self._dispatch_alarm(
                        alarm_type="vest_compliance_low",
                        level="medium",
                        message=f"反光衣穿戴率仅 {v_rate}% (<{self.compliance_threshold}%)",
                        details={"rate": v_rate, "threshold": self.compliance_threshold},
                        notify_kwargs={"rate": v_rate},
                    )

    def _flush_detection_aggregation(self):
        """
        将累计的检测聚合写入 detections 表 (每 N 帧/定时调用)
        """
        if self.storage is None:
            return
        if self.stats["agg_persons"] == 0:
            return
        try:
            self.storage.log_detection(
                camera_id=self.camera_id,
                total_persons=self.stats["agg_persons"],
                total_helmets=self.stats["agg_helmets"],
                total_no_helmets=self.stats["agg_no_helmets"],
                total_vests=self.stats["agg_vests"],
                total_no_vests=self.stats["agg_no_vests"],
                total_vehicles=self.stats["agg_vehicles"],
                intrusion_count=self.stats["agg_intrusions"],
            )
            # 清空本轮聚合
            self.stats["agg_persons"] = 0
            self.stats["agg_helmets"] = 0
            self.stats["agg_no_helmets"] = 0
            self.stats["agg_vests"] = 0
            self.stats["agg_no_vests"] = 0
            self.stats["agg_vehicles"] = 0
            self.stats["agg_intrusions"] = 0
        except Exception as e:
            print(f"[Storage] 写入检测聚合失败: {e}")

    # ============================================================
    # 核心: 处理单帧
    # ============================================================

    def process_frame(self, frame, frame_idx, timestamp):
        """
        处理单帧

        Returns:
            annotated_frame, violations, intrusions
        """
        h, w = frame.shape[:2]
        self.stats["processed_frames"] += 1

        # 运行 YOLO 推理
        results = self.model(frame, conf=self.conf, iou=self.iou,
                             device=self.device, verbose=False)

        violations = []
        intrusions = []
        annotated = frame.copy()

        if len(results) == 0 or results[0].boxes is None:
            return annotated, violations, intrusions

        boxes = results[0].boxes
        if boxes.xyxy is None or len(boxes.xyxy) == 0:
            return annotated, violations, intrusions

        # 结构化收集检测 (用于 Person 级合规匹配)
        detections = []
        # 先收集全部检测
        for i in range(len(boxes.xyxy)):
            cls_id = int(boxes.cls[i])
            conf_val = float(boxes.conf[i])
            x1, y1, x2, y2 = boxes.xyxy[i].tolist()
            x1, y1, x2, y2 = int(x1), int(y1), int(x2), int(y2)
            detections.append({
                "idx": i,
                "cls_id": cls_id,
                "cls_name": CLASS_NAMES.get(cls_id, f"cls_{cls_id}"),
                "conf": conf_val,
                "bbox": (x1, y1, x2, y2),
            })

        # ---- Person 级合规率匹配 (新增) ----
        person_statuses = []
        if self.mode in ("safety", "all"):
            person_statuses = self._match_gear_to_persons(detections)

        # ---- 逐框绘制 + 违规统计 + 聚合 ----
        for d in detections:
            cls_id = d["cls_id"]
            conf_val = d["conf"]
            x1, y1, x2, y2 = d["bbox"]
            cls_name = d["cls_name"]
            color = CLASS_COLORS.get(cls_id, (255, 255, 255))

            # 原始计数
            if cls_id == 0:
                self.stats["total_persons"] += 1
            elif cls_id == 1:
                self.stats["total_helmets"] += 1
            elif cls_id == 2:
                self.stats["total_no_helmets"] += 1
            elif cls_id == 3:
                self.stats["total_vests"] += 1
            elif cls_id == 4:
                self.stats["total_no_vests"] += 1
            elif cls_id == 5:
                self.stats["total_vehicles"] += 1

            # ---- 安全违规检测 (基于装备框, 兼容旧逻辑) ----
            if cls_id in SAFETY_VIOLATION_CLASSES and self.mode in ("safety", "all"):
                violation_type = SAFETY_VIOLATION_CLASSES[cls_id]
                violations.append({
                    "type": violation_type,
                    "cls_id": cls_id,
                    "conf": conf_val,
                    "bbox": (x1, y1, x2, y2),
                    "frame": frame_idx,
                    "timestamp": timestamp,
                })
                self.stats["violations_captured"] += 1
                color = (0, 0, 255)  # 违规红框

                # ---- 统一分发: 存储 + 通知 ----
                count_desc = {
                    "no_helmet": "未戴安全帽",
                    "no_vest": "未穿反光衣",
                }.get(violation_type, violation_type)
                self._dispatch_alarm(
                    alarm_type=violation_type,
                    level="high",
                    message=f"检测到{count_desc} (置信度 {conf_val:.2f})",
                    details={
                        "cls_id": cls_id, "confidence": round(conf_val, 3),
                        "frame": frame_idx, "timestamp_s": round(timestamp, 2),
                        "bbox": [x1, y1, x2, y2],
                    },
                    notify_kwargs={"count": 1},
                )

                # 保存违规截图 (每张类型每次冷却截一张)
                self._save_violation_capture(frame, violation_type, frame_idx)

            # ---- 入侵检测 ----
            if cls_id == 0 and self.mode in ("intrusion", "all"):
                foot_x = (x1 + x2) // 2
                foot_y = y2
                # 转成归一化坐标 (与 zone["points"] 的 pixel_norm 匹配)
                nx = foot_x / w
                ny = foot_y / h

                for zone in self.danger_zones:
                    # zone["points"] 是 pixel_norm (0~1)，用归一化坐标判断
                    if self._point_in_polygon(nx, ny, zone["points"]):
                        # 依据区域类型 alert_level 决定告警级别
                        zone_level = zone.get("alert_level", "high")
                        zone_type = zone.get("type", "danger")
                        if zone_type == "danger":
                            alarm_level = "critical" if zone_level in ("high", "critical") else "high"
                        elif zone_type == "restricted":
                            alarm_level = "high" if zone_level == "high" else "mid"
                        else:
                            alarm_level = "low"
                        zone_id = zone.get("id", "")
                        intrusions.append({
                            "zone_id": zone_id,
                            "zone": zone["name"],
                            "zone_type": zone_type,
                            "alert_level": zone_level,
                            "person_bbox": (x1, y1, x2, y2),
                            "frame": frame_idx,
                            "timestamp": timestamp,
                        })
                        self.stats["intrusions_detected"] += 1
                        self._draw_intrusion_warning(annotated, zone["name"],
                                                     foot_x, foot_y)

                        # ---- 统一分发 (带区域id/type/level) ----
                        self._dispatch_alarm(
                            alarm_type="intrusion",
                            level=alarm_level,
                            message=f"人员闯入{'危险' if zone_type=='danger' else '受限'}区域: {zone['name']}",
                            details={
                                "zone_id": zone_id,
                                "zone": zone["name"],
                                "zone_type": zone_type,
                                "zone_alert_level": zone_level,
                                "frame": frame_idx,
                                "timestamp_s": round(timestamp, 2),
                                "foot_point": [foot_x, foot_y],
                            },
                            notify_kwargs={"zone_name": zone["name"],
                                           "zone_id": zone_id,
                                           "zone_type": zone_type},
                        )

            # 绘制检测框
            self._draw_box(annotated, x1, y1, x2, y2, cls_name, conf_val, color)

        # ---- 绘制 Person 级合规状态 (小徽章叠加) ----
        if person_statuses:
            self._draw_person_compliance_badges(annotated, person_statuses)

        # ---- 聚合累计 (用于写入 detections 表) ----
        self.stats["agg_persons"] += self.stats["total_persons"] - \
            (getattr(self, "_prev_total_persons", self.stats["total_persons"]))
        self._prev_total_persons = self.stats["total_persons"]
        # 上面逻辑过于复杂, 直接按本帧贡献累加:
        frame_persons = len(person_statuses) if person_statuses else sum(
            1 for d in detections if d["cls_id"] == 0)
        frame_helmets = sum(1 for d in detections if d["cls_id"] == 1)
        frame_no_helmets = sum(1 for d in detections if d["cls_id"] == 2)
        frame_vests = sum(1 for d in detections if d["cls_id"] == 3)
        frame_no_vests = sum(1 for d in detections if d["cls_id"] == 4)
        frame_vehicles = sum(1 for d in detections if d["cls_id"] == 5)

        self.stats["agg_persons"] += frame_persons
        self.stats["agg_helmets"] += frame_helmets
        self.stats["agg_no_helmets"] += frame_no_helmets
        self.stats["agg_vests"] += frame_vests
        self.stats["agg_no_vests"] += frame_no_vests
        self.stats["agg_vehicles"] += frame_vehicles
        self.stats["agg_intrusions"] += len(intrusions)

        return annotated, violations, intrusions

    # ============================================================
    # Person 合规徽章绘制 (新增)
    # ============================================================

    def _draw_person_compliance_badges(self, frame, person_statuses):
        """在 person 框左上角画 H/V 徽章: H=绿色(戴盔)/红(无盔)/灰(未知)"""
        for ps in person_statuses:
            x1, y1, _, _ = ps["bbox"]
            # 头盔徽章
            if ps["helmet"] == "ok":
                h_color = (0, 180, 0)
                h_txt = "H"
            elif ps["helmet"] == "bad":
                h_color = (0, 0, 220)
                h_txt = "H!"
            else:
                h_color = (120, 120, 120)
                h_txt = "H?"
            cv2.rectangle(frame, (x1, y1 - 40), (x1 + 22, y1 - 18), h_color, -1)
            cv2.putText(frame, h_txt, (x1 + 3, y1 - 24),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.55, (255, 255, 255), 1)

            # 反光衣徽章
            if ps["vest"] == "ok":
                v_color = (0, 180, 0)
                v_txt = "V"
            elif ps["vest"] == "bad":
                v_color = (0, 0, 220)
                v_txt = "V!"
            else:
                v_color = (120, 120, 120)
                v_txt = "V?"
            cv2.rectangle(frame, (x1 + 26, y1 - 40), (x1 + 48, y1 - 18), v_color, -1)
            cv2.putText(frame, v_txt, (x1 + 28, y1 - 24),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.55, (255, 255, 255), 1)

    # ============================================================
    # 运行
    # ============================================================

    def run(self, max_frames=0):
        """
        运行视频验证

        Args:
            max_frames: 最大处理帧数 (0=全部)
        """
        cap = cv2.VideoCapture(self.source)
        if not cap.isOpened():
            print(f"无法打开视频源: {self.source}")
            return

        self._fps = cap.get(cv2.CAP_PROP_FPS) or 30
        self._width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
        self._height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
        total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))

        print(f"视频源: {self.source}")
        print(f"分辨率: {self._width}x{self._height} | FPS: {self._fps:.1f}")
        print(f"总帧数: {total_frames} | 检测模式: {self.mode}")
        print(f"危险区域: {len(self.danger_zones)} 个")
        print(f"跳帧: {self.skip_frames} | 置信度: {self.conf}")
        print(f"{'='*60}")

        # 视频写入器
        video_writer = None
        if self.save_video:
            out_path = str(self.output_dir / "annotated_output.mp4")
            fourcc = cv2.VideoWriter_fourcc(*"mp4v")
            video_writer = cv2.VideoWriter(
                out_path, fourcc, self._fps / self.skip_frames,
                (self._width, self._height),
            )

        frame_idx = 0
        processed = 0
        start_time = time.time()
        all_violations = []
        all_intrusions = []
        last_flush_t = time.time()
        last_compliance_check_t = time.time()

        while True:
            ret, frame = cap.read()
            if not ret:
                break

            frame_idx += 1
            self.stats["total_frames"] = frame_idx

            # 跳帧
            if frame_idx % self.skip_frames != 0:
                continue

            # 计算时间戳
            timestamp = frame_idx / self._fps

            # 处理
            annotated, violations, intrusions = self.process_frame(
                frame, frame_idx, timestamp
            )

            all_violations.extend(violations)
            all_intrusions.extend(intrusions)

            # 帧信息叠加
            self._draw_frame_info(annotated, frame_idx, total_frames, timestamp)

            # 保存
            if video_writer:
                video_writer.write(annotated)

            # 显示
            if self.show_display:
                cv2.imshow("Video Verifier", annotated)
                key = cv2.waitKey(1) & 0xFF
                if key == ord("q"):
                    break
                elif key == ord(" "):
                    while True:
                        if cv2.waitKey(0) & 0xFF == ord(" "):
                            break

            processed += 1

            # ============================================
            # 定时: 写检测聚合 / 合规率告警
            # ============================================
            now = time.time()
            if now - last_flush_t >= 10:
                self._flush_detection_aggregation()
                last_flush_t = now

            if now - last_compliance_check_t >= 30:
                self._check_and_alert_compliance()
                last_compliance_check_t = now

            # 进度
            if processed % 50 == 0:
                elapsed = time.time() - start_time
                fps = processed / elapsed if elapsed > 0 else 0
                pct = (frame_idx / total_frames * 100) if total_frames > 0 else 0
                print(f"  进度: {frame_idx}/{total_frames} ({pct:.0f}%) | "
                      f"FPS: {fps:.1f} | "
                      f"违规: {len(all_violations)} | "
                      f"入侵: {len(all_intrusions)}")

            if max_frames > 0 and processed >= max_frames:
                break

        # 清理
        cap.release()
        if video_writer:
            video_writer.release()
        cv2.destroyAllWindows()

        self.stats["end_time"] = time.time()

        # 最后一次 flush 聚合 + 合规率检查
        self._flush_detection_aggregation()
        self._check_and_alert_compliance()

        # 保存事件日志
        self._save_events(all_violations, all_intrusions)

        # 打印报告
        self._print_report(all_violations, all_intrusions)

    # ============================================================
    # 报告
    # ============================================================

    def _print_report(self, violations, intrusions):
        """打印验证报告"""
        elapsed = self.stats["end_time"] - self.stats["start_time"]
        fps = self.stats["processed_frames"] / elapsed if elapsed > 0 else 0

        print(f"\n{'='*60}")
        print(f"  视频验证报告")
        print(f"{'='*60}")
        print(f"  处理帧数: {self.stats['processed_frames']}/{self.stats['total_frames']}")
        print(f"  耗时: {elapsed:.1f}s (实际 FPS: {fps:.1f})")
        print(f"  摄像头: {self.camera_id}")
        if self.storage is not None:
            print(f"  [Storage] ✅ 已写入 SQLite")
        if self.notifier is not None:
            print(f"  [Notify]  ✅ 已启用飞书通知")
        print(f"")
        print(f"  检测统计 (原始累计):")
        print(f"    人员: {self.stats['total_persons']}")
        print(f"    安全帽: {self.stats['total_helmets']}")
        print(f"    未戴安全帽: {self.stats['total_no_helmets']}")
        print(f"    反光衣: {self.stats['total_vests']}")
        print(f"    未穿反光衣: {self.stats['total_no_vests']}")
        print(f"    车辆: {self.stats['total_vehicles']}")
        print(f"")

        # ---- Person 级合规率 (新增, 更精确) ----
        h_ok = self.stats["person_helmet_ok"]
        h_bad = self.stats["person_helmet_bad"]
        h_unk = self.stats["person_helmet_unknown"]
        h_total = h_ok + h_bad + h_unk
        h_known = h_ok + h_bad

        v_ok = self.stats["person_vest_ok"]
        v_bad = self.stats["person_vest_bad"]
        v_unk = self.stats["person_vest_unknown"]
        v_total = v_ok + v_bad + v_unk
        v_known = v_ok + v_bad

        if h_total > 0 or v_total > 0:
            print(f"  ── Person 级合规率 (精确统计) ──")
            print(f"  已匹配 Person: 头盔 {h_total} 人 | 反光衣 {v_total} 人")
            if h_known > 0:
                p_helmet = calc_rate(h_ok, h_known)
                print(f"    安全帽: 合规 {h_ok} / 违规 {h_bad} / 未知 {h_unk}"
                      f" | 佩戴率 {p_helmet:.1f}% (仅含已知 {h_known} 人)")
            else:
                print(f"    安全帽: 合规 {h_ok} / 违规 {h_bad} / 未知 {h_unk} (样本不足)")
            if v_known > 0:
                p_vest = calc_rate(v_ok, v_known)
                print(f"    反光衣: 合规 {v_ok} / 违规 {v_bad} / 未知 {v_unk}"
                      f" | 穿戴率 {p_vest:.1f}% (仅含已知 {v_known} 人)")
            else:
                print(f"    反光衣: 合规 {v_ok} / 违规 {v_bad} / 未知 {v_unk} (样本不足)")
            print(f"")

        # 原始合规率 (兼容)
        total_gear = (self.stats['total_helmets'] + self.stats['total_no_helmets'])
        total_vest_gear = (self.stats['total_vests'] + self.stats['total_no_vests'])
        helmet_rate = (self.stats['total_helmets'] / total_gear * 100
                       if total_gear > 0 else 0)
        vest_rate = (self.stats['total_vests'] / total_vest_gear * 100
                     if total_vest_gear > 0 else 0)

        print(f"  安全合规率 (装备级累计, 参考):")
        print(f"    安全帽佩戴率: {helmet_rate:.1f}%")
        print(f"    反光衣穿戴率: {vest_rate:.1f}%")
        print(f"")

        # 违规
        v_by_type = defaultdict(int)
        for v in violations:
            v_by_type[v["type"]] += 1

        print(f"  违规事件:")
        print(f"    安全帽违规: {v_by_type.get('no_helmet', 0)} 次")
        print(f"    反光衣违规: {v_by_type.get('no_vest', 0)} 次")
        print(f"    入侵事件: {len(intrusions)} 次")
        print(f"")

        # 入侵详情
        if intrusions:
            i_by_zone = defaultdict(int)
            for intr in intrusions:
                i_by_zone[intr["zone"]] += 1
            print(f"  入侵详情:")
            for zone, count in i_by_zone.items():
                print(f"    {zone}: {count} 次")

        print(f"")
        print(f"  输出文件:")
        print(f"    标注视频: {self.output_dir}/annotated_output.mp4")
        print(f"    违规截图: {self.output_dir}/violations/")
        print(f"    事件日志: {self._event_log_path}")
        print(f"    报表 JSON: {self.output_dir}/report.json")
        if self.storage is not None:
            print(f"    SQLite 数据库: {self.storage.db_path}")
        print(f"{'='*60}")

        # 保存 JSON 报告
        report = {
            "source": self.source,
            "camera_id": self.camera_id,
            "model": self.model.model_name if hasattr(self.model, 'model_name') else "",
            "mode": self.mode,
            "storage_enabled": self.storage is not None,
            "notify_enabled": self.notifier is not None,
            "stats": {
                "total_frames": self.stats["total_frames"],
                "processed_frames": self.stats["processed_frames"],
                "elapsed_s": round(elapsed, 1),
                "actual_fps": round(fps, 1),
                # 原始累计
                "total_persons": self.stats["total_persons"],
                "total_helmets": self.stats["total_helmets"],
                "total_no_helmets": self.stats["total_no_helmets"],
                "total_vests": self.stats["total_vests"],
                "total_no_vests": self.stats["total_no_vests"],
                "total_vehicles": self.stats["total_vehicles"],
                "helmet_compliance_rate_raw": round(helmet_rate, 1),
                "vest_compliance_rate_raw": round(vest_rate, 1),
                # Person 级精确
                "person_level": {
                    "helmet": {
                        "ok": h_ok, "bad": h_bad, "unknown": h_unk,
                        "compliance_rate_known": round(calc_rate(h_ok, h_known), 1)
                        if h_known > 0 else 0.0,
                    },
                    "vest": {
                        "ok": v_ok, "bad": v_bad, "unknown": v_unk,
                        "compliance_rate_known": round(calc_rate(v_ok, v_known), 1)
                        if v_known > 0 else 0.0,
                    },
                },
                "violations": dict(v_by_type),
                "intrusions": len(intrusions),
            },
            "violations": violations[:100],  # 截断
            "intrusions": intrusions[:100],
            "generated_at": now_str(),
        }

        with open(self.output_dir / "report.json", "w") as f:
            json.dump(report, f, indent=2, ensure_ascii=False)

    # ============================================================
    # 绘制
    # ============================================================

    def _draw_box(self, frame, x1, y1, x2, y2, label, conf, color):
        """绘制检测框"""
        cv2.rectangle(frame, (x1, y1), (x2, y2), color, 2)

        # 标签背景
        text = f"{label} {conf:.2f}"
        (tw, th), _ = cv2.getTextSize(text, cv2.FONT_HERSHEY_SIMPLEX, 0.5, 1)
        cv2.rectangle(frame, (x1, y1 - th - 6), (x1 + tw, y1), color, -1)
        cv2.putText(frame, text, (x1, y1 - 4),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 0, 0), 1)

    def _draw_intrusion_warning(self, frame, zone_name, x, y):
        """绘制入侵警告"""
        # 闪烁警告圈
        if int(time.time() * 3) % 2:
            cv2.circle(frame, (x, y), 40, (0, 0, 255), 3)
            cv2.putText(frame, f"INTRUSION: {zone_name}",
                        (x + 45, y - 10),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 0, 255), 2)

    def _draw_frame_info(self, frame, frame_idx, total, timestamp):
        """绘制帧信息"""
        h, w = frame.shape[:2]

        # 顶部信息栏
        overlay = frame.copy()
        cv2.rectangle(overlay, (0, 0), (w, 40), (0, 0, 0), -1)
        frame = cv2.addWeighted(overlay, 0.4, frame, 0.6, 0)

        mins = int(timestamp // 60)
        secs = int(timestamp % 60)
        info = (f"Frame: {frame_idx}/{total} | "
                f"Time: {mins:02d}:{secs:02d} | "
                f"Mode: {self.mode} | "
                f"Violations: {self.stats['violations_captured']} | "
                f"Intrusions: {self.stats['intrusions_detected']}")

        cv2.putText(frame, info, (10, 28),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255, 255, 255), 1)

        # 画危险区域 (zone["points"] 是归一化坐标 0~1, 先 × 分辨率转像素)
        for zone in self.danger_zones:
            px_pts = [[int(p[0] * w), int(p[1] * h)] for p in zone["points"]]
            pts = np.array(px_pts, np.int32).reshape((-1, 1, 2))
            # 区域类型决定颜色: danger=红, restricted=橙, 其他=黄
            ztype = zone.get("type", "danger")
            if ztype == "danger":
                color = (0, 0, 255)
            elif ztype == "restricted":
                color = (0, 140, 255)
            else:
                color = (0, 210, 255)
            cv2.polylines(frame, [pts], True, color, 2)
            label = zone["name"]
            if zone.get("id") and zone["id"].startswith("zone_danger"):
                pass  # 标签用 name 即可
            # 标签放在第一个顶点上方 8px
            tx, ty = px_pts[0]
            ty = max(14, ty - 6)
            cv2.putText(frame, label, (tx, ty),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.5, color, 1)

    # ============================================================
    # 工具
    # ============================================================

    def _point_in_polygon(self, x, y, polygon):
        """射线法判断点是否在多边形内 (委托给 common 模块)"""
        return point_in_polygon(x, y, polygon)

    def _save_violation_capture(self, frame, vtype, frame_idx):
        """保存违规截图"""
        filename = f"{vtype}_{frame_idx:06d}.jpg"
        path = self.output_dir / "violations" / filename
        cv2.imwrite(str(path), frame)

    def _save_events(self, violations, intrusions):
        """保存事件日志"""
        with open(self._event_log_path, "w") as f:
            for v in violations:
                event = {
                    "type": "violation",
                    "violation_type": v["type"],
                    "frame": v["frame"],
                    "timestamp": round(v["timestamp"], 2),
                    "conf": round(v["conf"], 3),
                }
                f.write(json.dumps(event, ensure_ascii=False) + "\n")

            for intr in intrusions:
                event = {
                    "type": "intrusion",
                    "zone": intr["zone"],
                    "frame": intr["frame"],
                    "timestamp": round(intr["timestamp"], 2),
                }
                f.write(json.dumps(event, ensure_ascii=False) + "\n")


# ============================================================
# 危险区域标注工具
# ============================================================

def annotate_danger_zones(image_path, output_path="configs/my_zones.json"):
    """交互式标注危险区域"""
    img = cv2.imread(image_path)
    if img is None:
        print(f"无法读取图片: {image_path}")
        return

    zones = []
    current_zone = []
    drawing = False

    def draw_callback(event, x, y, flags, param):
        nonlocal drawing, current_zone
        if event == cv2.EVENT_LBUTTONDOWN:
            current_zone.append([x, y])
            drawing = True
        elif event == cv2.EVENT_MOUSEMOVE and drawing:
            pass
        elif event == cv2.EVENT_LBUTTONUP:
            drawing = False

    print("\n危险区域标注工具")
    print("  点击左键: 添加顶点")
    print("  按 'n': 完成当前区域, 开始下一个")
    print("  按 's': 保存所有区域")
    print("  按 'q': 退出")
    print("  按 'u': 撤销上一个顶点")

    cv2.namedWindow("Annotate Danger Zones")
    cv2.setMouseCallback("Annotate Danger Zones", draw_callback)

    display = img.copy()

    while True:
        display = img.copy()

        # 画已完成的区域
        for i, zone in enumerate(zones):
            pts = np.array(zone["points"], np.int32).reshape((-1, 1, 2))
            cv2.polylines(display, [pts], True, (0, 0, 255), 2)
            cv2.putText(display, zone["name"],
                        tuple(zone["points"][0]),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 0, 255), 1)

        # 画当前区域
        if len(current_zone) > 1:
            pts = np.array(current_zone, np.int32).reshape((-1, 1, 2))
            cv2.polylines(display, [pts], False, (0, 255, 255), 2)
        for pt in current_zone:
            cv2.circle(display, tuple(pt), 4, (0, 255, 255), -1)

        # 提示
        cv2.putText(display, f"Zones: {len(zones)} | Vertices: {len(current_zone)}",
                    (10, 30), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 255, 255), 2)
        cv2.putText(display, "n=next zone | s=save | u=undo | q=quit",
                    (10, 55), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (200, 200, 200), 1)

        cv2.imshow("Annotate Danger Zones", display)
        key = cv2.waitKey(100) & 0xFF

        if key == ord("n") and len(current_zone) >= 3:
            name = input(f"  区域 {len(zones)+1} 名称: ").strip() or f"zone_{len(zones)+1}"
            zones.append({"name": name, "points": current_zone.copy()})
            current_zone = []
            print(f"  已添加区域: {name} ({len(zones[-1]['points'])} 个顶点)")
        elif key == ord("s"):
            break
        elif key == ord("q"):
            cv2.destroyAllWindows()
            return
        elif key == ord("u") and current_zone:
            current_zone.pop()

    cv2.destroyAllWindows()

    if zones:
        with open(output_path, "w") as f:
            json.dump(zones, f, indent=2, ensure_ascii=False)
        print(f"\n已保存 {len(zones)} 个危险区域到: {output_path}")
    else:
        print("未标注任何区域")


# ============================================================
# 主函数
# ============================================================

def main():
    parser = argparse.ArgumentParser(
        description="智慧工地 - 单路视频端到端验证",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
示例:
  # 完整验证 (安全+入侵)
  python scripts/video_verify.py --model best.pt --source video.mp4 --zones configs/danger_zones.json

  # 仅安全装备检测
  python scripts/video_verify.py --model best.pt --source video.mp4 --mode safety

  # 交互式标注危险区域
  python scripts/video_verify.py --annotate scene.jpg --annotate-output configs/my_zones.json

  # 仅入侵检测
  python scripts/video_verify.py --model best.pt --source video.mp4 --zones configs/my_zones.json --mode intrusion

  # 无显示模式 (服务器)
  python scripts/video_verify.py --model best.pt --source video.mp4 --no-display

  # ★ 完整生产模式: 存储 + 通知 + Person合规率统计
  python scripts/video_verify.py \\
      --model runs/syn_train/syn_exp1/weights/best.pt \\
      --source datasets/images/val \\
      --zones configs/danger_zones.json \\
      --mode all --no-display --no-video --storage --notify \\
      --camera-id cam_entrance --compliance-threshold 80
        """,
    )

    parser.add_argument("--model", type=str, default=None,
                        help="模型权重路径")
    parser.add_argument("--source", type=str, default=None,
                        help="视频源 (文件/目录/摄像头/RTSP)")
    parser.add_argument("--zones", type=str, default=None,
                        help="危险区域 JSON 文件")
    parser.add_argument("--mode", type=str, default="all",
                        choices=["safety", "intrusion", "all"],
                        help="检测模式")
    parser.add_argument("--conf", type=float, default=0.3,
                        help="置信度阈值")
    parser.add_argument("--device", type=str, default="cpu",
                        help="设备")
    parser.add_argument("--output", type=str, default="runs/video_verify",
                        help="输出目录")
    parser.add_argument("--skip-frames", type=int, default=1,
                        help="跳帧 (1=不跳)")
    parser.add_argument("--no-display", action="store_true",
                        help="不显示画面")
    parser.add_argument("--no-video", action="store_true",
                        help="不保存视频")
    parser.add_argument("--max-frames", type=int, default=0,
                        help="最大处理帧数 (0=全部)")
    parser.add_argument("--annotate", type=str, default=None,
                        help="交互式标注危险区域 (输入图片路径)")
    parser.add_argument("--annotate-output", type=str, default="configs/my_zones.json",
                        help="标注输出路径")
    # ---- 新增: 存储 + 通知 + 合规率参数 ----
    parser.add_argument("--camera-id", type=str, default="cam_01",
                        help="摄像头标识 (用于存储/通知字段)")
    parser.add_argument("--storage", action="store_true",
                        help="启用 SQLite 持久化存储 (写入 alarms/detections/events)")
    parser.add_argument("--db", type=str, default="runs/data/site.db",
                        help="SQLite 数据库路径 (配合 --storage 使用)")
    parser.add_argument("--notify", action="store_true",
                        help="启用飞书告警推送 (需 personnel.json 配置)")
    parser.add_argument("--personnel-config", type=str,
                        default="configs/personnel.json",
                        help="人员角色通知配置文件路径")
    parser.add_argument("--compliance-threshold", type=float, default=80.0,
                        help="合规率告警阈值 (%%), 低于此值触发 compliance_low 告警 (默认 80%%)")

    args = parser.parse_args()

    # 交互式标注模式
    if args.annotate:
        annotate_danger_zones(args.annotate, args.annotate_output)
        return

    if not args.model or not args.source:
        parser.error("需要 --model 和 --source 参数")

    # 加载危险区域
    danger_zones = []
    if args.zones:
        from utils.common import (
            load_unified_zones, print_zones_summary, ZoneCoords,
        )
        # 统一加载: 自动识别 danger_zones.json / site_geofence.json / 纯数组
        all_zones = load_unified_zones(args.zones)
        # 视频入侵只取 pixel 坐标; GPS 区域明确提示如何使用
        gps_zones = [z for z in all_zones if z["coords"] == ZoneCoords.GPS_WGS84.value]
        if gps_zones:
            print(f"[Zones] ⚠️  video_verify 使用视频像素坐标, 跳过 {len(gps_zones)} 个GPS区域: "
                  f"{[z['id'] for z in gps_zones]}")
            print("        如需对GPS危险区做映射到视频画面, 可先用 zones_tool extract 导出后, "
                  "在实际画面上再用 --annotate 重新标注像素多边形。")
        video_zones = [z for z in all_zones
                       if z["coords"] in (ZoneCoords.PIXEL_NORM.value,
                                          ZoneCoords.PIXEL_ABS.value)]
        # 转 pixel_norm (pixel_abs 需参考分辨率换算; 无则 1920×1080)
        for z in video_zones:
            if z["coords"] == ZoneCoords.PIXEL_NORM.value:
                pts = z["points"]
            else:
                w, h = z.get("reference_resolution") or (1920, 1080)
                pts = [[p[0] / w, p[1] / h] for p in z["points"]]
            danger_zones.append({
                "id": z["id"], "name": z["name"], "points": pts,
                "type": z["type"], "alert_level": z.get("alert_level", "high"),
            })
        print_zones_summary(video_zones, title="视频检测加载区域")

    if danger_zones:
        print(f"最终有效视频危险区域: {len(danger_zones)} 个")
        for z in danger_zones:
            print(f"  - {z['name']} (id={z['id']}, 顶点={len(z['points'])}, "
                  f"level={z['alert_level']})")

    # 运行验证
    verifier = VideoVerifier(
        model_path=args.model,
        source=args.source,
        danger_zones=danger_zones,
        conf=args.conf,
        mode=args.mode,
        device=args.device,
        output_dir=args.output,
        save_video=not args.no_video,
        show_display=not args.no_display,
        skip_frames=args.skip_frames,
        camera_id=args.camera_id,
        enable_storage=args.storage,
        db_path=args.db,
        enable_notify=args.notify,
        personnel_config=args.personnel_config,
        compliance_threshold=args.compliance_threshold,
    )

    verifier.run(max_frames=args.max_frames)


if __name__ == "__main__":
    main()