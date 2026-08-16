#!/usr/bin/env python3
"""
智慧工地 - 多路摄像头实时监控
支持同时监控多个摄像头 (RTSP/本地摄像头/USB摄像头)
包含安全装备检测 + 危险区域入侵检测 + 人员统计
"""

import argparse
import json
import os
import sys
import threading
import time
from pathlib import Path
from datetime import datetime
from queue import Queue
import cv2
import numpy as np
from ultralytics import YOLO

# 添加项目根目录到 path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from utils.notify import LarkNotifier


class CameraWorker(threading.Thread):
    """单个摄像头工作线程"""

    def __init__(self, camera_id, source, model, danger_zones,
                 conf=0.3, sample_interval=5, alarm_queue=None,
                 notifier=None):
        super().__init__(daemon=True)
        self.camera_id = camera_id
        self.source = source
        self.model = model
        self.danger_zones = danger_zones
        self.conf = conf
        self.sample_interval = sample_interval
        self.alarm_queue = alarm_queue
        self.notifier = notifier

        self.running = False
        self.frame_count = 0
        self.last_alarm = {}

    def run(self):
        self.running = True
        cap = cv2.VideoCapture(self.source)

        if not cap.isOpened():
            print(f"[Camera {self.camera_id}] 无法打开视频源: {self.source}")
            return

        print(f"[Camera {self.camera_id}] 已连接: {self.source}")

        while self.running:
            ret, frame = cap.read()
            if not ret:
                time.sleep(0.1)
                continue

            self.frame_count += 1

            if self.frame_count % self.sample_interval != 0:
                continue

            # 推理
            results = self.model(frame, conf=self.conf, verbose=False)

            for result in results:
                boxes = result.boxes
                if boxes is None:
                    continue

                self._analyze(frame, boxes, result.orig_img.shape)

            # 控制帧率
            time.sleep(0.03)

        cap.release()
        print(f"[Camera {self.camera_id}] 已断开")

    def stop(self):
        self.running = False

    def _analyze(self, frame, boxes, img_shape):
        """分析帧内容"""
        img_h, img_w = img_shape[:2]
        stats = Counter()
        intrusions = []

        for box in boxes:
            cls_id = int(box.cls[0])
            conf = float(box.conf[0])

            if conf < self.conf:
                continue

            stats[cls_id] += 1

            # 入侵检测 (仅人员 class_id=0)
            if cls_id == 0 and self.danger_zones:
                x1, y1, x2, y2 = box.xyxy[0].tolist()
                cx = (x1 + x2) / 2
                cy = (y1 + y2) / 2

                for zi, zone in enumerate(self.danger_zones):
                    zone_px = [(x * img_w, y * img_h) for x, y in zone]
                    if self._point_in_polygon((cx, cy), zone_px):
                        intrusions.append(zi)
                        break

        # 生成报警
        now = time.time()
        alarms = []

        # 安全装备违规
        if stats.get(2, 0) > 0:  # no_helmet
            if now - self.last_alarm.get("no_helmet", 0) > 5:
                self.last_alarm["no_helmet"] = now
                alarms.append(f"摄像头 {self.camera_id}: 未戴安全帽 x{stats[2]}")
                if self.notifier:
                    self.notifier.send_alarm("no_helmet", camera_id=self.camera_id, count=stats[2])

        if stats.get(4, 0) > 0:  # no_vest
            if now - self.last_alarm.get("no_vest", 0) > 5:
                self.last_alarm["no_vest"] = now
                alarms.append(f"摄像头 {self.camera_id}: 未穿反光衣 x{stats[4]}")
                if self.notifier:
                    self.notifier.send_alarm("no_vest", camera_id=self.camera_id, count=stats[4])

        for zi in intrusions:
            if now - self.last_alarm.get(f"zone_{zi}", 0) > 5:
                self.last_alarm[f"zone_{zi}"] = now
                alarms.append(f"摄像头 {self.camera_id}: 人员闯入危险区域 #{zi}")
                if self.notifier:
                    zone_name = f"Zone_{zi}"
                    self.notifier.send_alarm("intrusion", camera_id=self.camera_id, zone_name=zone_name)

        if alarms and self.alarm_queue:
            for alarm in alarms:
                self.alarm_queue.put(alarm)

    @staticmethod
    def _point_in_polygon(point, polygon):
        """射线法判断点是否在多边形内"""
        x, y = point
        n = len(polygon)
        inside = False
        j = n - 1
        for i in range(n):
            xi, yi = polygon[i]
            xj, yj = polygon[j]
            if ((yi > y) != (yj > y)) and (
                x < (xj - xi) * (y - yi) / (yj - yi) + xi
            ):
                inside = not inside
            j = i
        return inside


class AlarmMonitor:
    """报警监控与记录"""

    def __init__(self, log_dir="runs/camera_monitor"):
        self.log_dir = Path(log_dir)
        self.log_dir.mkdir(parents=True, exist_ok=True)
        self.alarm_queue = Queue()
        self.alarm_log = []
        self.running = False

    def start(self):
        self.running = True
        self._monitor_thread = threading.Thread(target=self._monitor_loop, daemon=True)
        self._monitor_thread.start()

    def stop(self):
        self.running = False
        self._save_log()

    def _monitor_loop(self):
        while self.running:
            try:
                alarm = self.alarm_queue.get(timeout=1)
                timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
                msg = f"[{timestamp}] {alarm}"
                self.alarm_log.append(msg)
                print(f"  [ALARM] {msg}")
            except Exception:
                pass

    def _save_log(self):
        if not self.alarm_log:
            return
        path = self.log_dir / f"alarm_{datetime.now().strftime('%Y%m%d_%H%M%S')}.log"
        with open(path, "w") as f:
            f.write("\n".join(self.alarm_log))
        print(f"报警日志已保存: {path}")


class MultiCameraMonitor:
    """多路摄像头监控管理器"""

    def __init__(self, model_path, cameras_config, danger_zones=None,
                 conf=0.3, sample_interval=5, notify=False,
                 personnel_config="configs/personnel.json"):
        """
        Args:
            model_path: YOLO 模型路径
            cameras_config: 摄像头配置, dict 或 JSON 文件路径
                格式: {"camera_1": "rtsp://...", "camera_2": 0, ...}
            danger_zones: 危险区域配置
        """
        self.model = YOLO(model_path)
        self.conf = conf
        self.sample_interval = sample_interval
        self.notify = notify

        # 飞书通知器
        self.notifier = LarkNotifier(personnel_config) if notify else None

        # 加载摄像头配置
        if isinstance(cameras_config, str):
            with open(cameras_config, "r") as f:
                self.cameras_config = json.load(f)
        else:
            self.cameras_config = cameras_config

        # 加载危险区域
        if danger_zones is None:
            self.danger_zones = []
        elif isinstance(danger_zones, str):
            with open(danger_zones, "r") as f:
                data = json.load(f)
                self.danger_zones = data.get("zones", [])
        else:
            self.danger_zones = danger_zones

        self.alarm_monitor = AlarmMonitor()
        self.workers = []

    def start(self):
        """启动所有摄像头监控"""
        print(f"启动 {len(self.cameras_config)} 路摄像头监控...")
        self.alarm_monitor.start()

        for cam_id, source in self.cameras_config.items():
            worker = CameraWorker(
                camera_id=cam_id,
                source=source,
                model=self.model,
                danger_zones=self.danger_zones,
                conf=self.conf,
                sample_interval=self.sample_interval,
                alarm_queue=self.alarm_monitor.alarm_queue,
                notifier=self.notifier,
            )
            worker.start()
            self.workers.append(worker)
            time.sleep(0.5)  # 错开启动

        print(f"监控已启动, 共 {len(self.workers)} 路摄像头")
        print("按 Ctrl+C 停止监控")

    def stop(self):
        """停止所有监控"""
        print("\n正在停止监控...")
        for worker in self.workers:
            worker.stop()
        for worker in self.workers:
            worker.join(timeout=3)
        self.alarm_monitor.stop()
        print("监控已停止")

    def run_forever(self):
        """持续运行直到手动停止"""
        self.start()
        try:
            while True:
                time.sleep(1)
        except KeyboardInterrupt:
            self.stop()


def main():
    parser = argparse.ArgumentParser(description="智慧工地 - 多路摄像头实时监控")
    parser.add_argument("--model", type=str, required=True, help="训练好的模型路径")
    parser.add_argument("--cameras", type=str, required=True,
                        help="摄像头配置 JSON 文件")
    parser.add_argument("--zones", type=str, default=None,
                        help="危险区域配置 JSON 文件")
    parser.add_argument("--conf", type=float, default=0.3, help="置信度阈值")
    parser.add_argument("--sample_interval", type=int, default=5,
                        help="推理间隔 (每N帧)")
    parser.add_argument("--device", type=str, default="0", help="推理设备")
    parser.add_argument("--notify", action="store_true", help="启用飞书告警通知")
    parser.add_argument("--personnel-config", type=str, default="configs/personnel.json",
                        help="人员配置文件路径")

    args = parser.parse_args()

    monitor = MultiCameraMonitor(
        model_path=args.model,
        cameras_config=args.cameras,
        danger_zones=args.zones,
        conf=args.conf,
        sample_interval=args.sample_interval,
        notify=args.notify,
        personnel_config=args.personnel_config,
    )

    monitor.run_forever()


if __name__ == "__main__":
    main()