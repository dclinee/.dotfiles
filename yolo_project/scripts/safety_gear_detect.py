#!/usr/bin/env python3
"""
智慧工地 - 安全装备检测
检测工地人员是否佩戴安全帽和反光衣，违规时报警
"""

import argparse
import os
import sys
import time
from pathlib import Path
from datetime import datetime
import cv2
import numpy as np
from ultralytics import YOLO

# 添加项目根目录到 path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from utils.notify import LarkNotifier, alarm_no_helmet, alarm_no_vest


# 安全装备类别映射
SAFETY_CLASSES = {
    "helmet": 1,       # 安全帽
    "no_helmet": 2,    # 未戴安全帽
    "vest": 3,         # 反光衣
    "no_vest": 4,      # 未穿反光衣
    "person": 0,       # 人员
}


class SafetyGearMonitor:
    """安全装备监控器"""

    def __init__(self, model_path, conf=0.3, iou=0.5, device="0",
                 notify=False, personnel_config="configs/personnel.json"):
        self.model = YOLO(model_path)
        self.conf = conf
        self.iou = iou
        self.device = device

        # 报警记录
        self.alarm_log = []
        self.alarm_cooldown = {}  # 避免重复报警

        # 飞书通知
        self.notify = notify
        self.notifier = LarkNotifier(personnel_config) if notify else None

        # 颜色定义
        self.colors = {
            "helmet": (0, 255, 0),      # 绿色 - 合规
            "no_helmet": (0, 0, 255),   # 红色 - 违规
            "vest": (0, 255, 0),        # 绿色 - 合规
            "no_vest": (0, 0, 255),     # 红色 - 违规
            "person": (255, 255, 0),    # 黄色 - 人员
            "vehicle": (0, 255, 255),   # 青色 - 车辆
        }

    def detect(self, source, save=True, show=False, alarm_interval=5):
        """
        执行安全装备检测

        Args:
            source: 图片/视频/摄像头
            save: 是否保存结果
            show: 是否实时显示
            alarm_interval: 报警间隔(秒), 避免重复报警
        """
        results = self.model.predict(
            source=source,
            conf=self.conf,
            iou=self.iou,
            device=self.device,
            save=save,
            project="runs/safety_gear",
            name=datetime.now().strftime("%Y%m%d_%H%M%S"),
            show=show,
            stream=True,  # 流式处理视频
        )

        frame_count = 0
        violation_count = 0
        total_person = 0

        for result in results:
            frame_count += 1
            boxes = result.boxes

            if boxes is None or len(boxes) == 0:
                continue

            frame_violations = self._analyze_frame(boxes, frame_count, alarm_interval)

            if frame_violations:
                violation_count += 1
                total_person += frame_violations.get("total_person", 0)
                self._log_alarm(frame_count, frame_violations)

        # 打印汇总
        print(f"\n{'='*50}")
        print(f"检测完成")
        print(f"总帧数: {frame_count}")
        print(f"违规帧数: {violation_count}")
        if total_person > 0:
            print(f"检测人员总数: {total_person}")
        print(f"报警记录: {len(self.alarm_log)} 条")
        print(f"{'='*50}")

    def _analyze_frame(self, boxes, frame_id, alarm_interval):
        """分析单帧检测结果"""
        stats = {
            "person": 0,
            "helmet": 0,
            "no_helmet": 0,
            "vest": 0,
            "no_vest": 0,
        }

        for box in boxes:
            cls_id = int(box.cls[0])
            conf = float(box.conf[0])

            for name, cid in SAFETY_CLASSES.items():
                if cls_id == cid and conf >= self.conf:
                    stats[name] = stats.get(name, 0) + 1

        # 判断违规
        violations = {}
        if stats["no_helmet"] > 0:
            violations["no_helmet"] = stats["no_helmet"]
        if stats["no_vest"] > 0:
            violations["no_vest"] = stats["no_vest"]

        if violations:
            violations["total_person"] = stats["person"]

        return violations

    def _log_alarm(self, frame_id, violations):
        """记录报警"""
        now = datetime.now()

        # 冷却检查
        for key in violations:
            if key in self.alarm_cooldown:
                if (now - self.alarm_cooldown[key]).seconds < 5:
                    return

        timestamp = now.strftime("%Y-%m-%d %H:%M:%S")
        alarm_msg = f"[{timestamp}] Frame {frame_id}: "

        details = []
        if "no_helmet" in violations:
            details.append(f"未戴安全帽 x{violations['no_helmet']}")
            self.alarm_cooldown["no_helmet"] = now
        if "no_vest" in violations:
            details.append(f"未穿反光衣 x{violations['no_vest']}")
            self.alarm_cooldown["no_vest"] = now

        alarm_msg += ", ".join(details)
        self.alarm_log.append(alarm_msg)
        print(f"  [ALARM] {alarm_msg}")

        # 飞书通知
        if self.notify:
            if "no_helmet" in violations:
                self.notifier.send_alarm(
                    "no_helmet",
                    camera_id=getattr(self, "camera_id", None),
                    count=violations["no_helmet"],
                )
            if "no_vest" in violations:
                self.notifier.send_alarm(
                    "no_vest",
                    camera_id=getattr(self, "camera_id", None),
                    count=violations["no_vest"],
                )

    def save_alarm_log(self, path="runs/safety_gear/alarm_log.txt"):
        """保存报警日志"""
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w") as f:
            f.write("\n".join(self.alarm_log))
        print(f"报警日志已保存: {path}")


def main():
    parser = argparse.ArgumentParser(description="智慧工地 - 安全装备检测")
    parser.add_argument("--model", type=str, required=True, help="训练好的模型路径")
    parser.add_argument("--source", type=str, required=True, help="图片/视频/摄像头(0)")
    parser.add_argument("--conf", type=float, default=0.3, help="置信度阈值")
    parser.add_argument("--iou", type=float, default=0.5, help="NMS IoU 阈值")
    parser.add_argument("--device", type=str, default="0", help="设备")
    parser.add_argument("--nosave", action="store_true", help="不保存结果")
    parser.add_argument("--show", action="store_true", help="实时显示")
    parser.add_argument("--alarm_interval", type=int, default=5, help="报警间隔(秒)")
    parser.add_argument("--notify", action="store_true", help="启用飞书告警通知")
    parser.add_argument("--personnel-config", type=str, default="configs/personnel.json",
                        help="人员配置文件路径")
    parser.add_argument("--camera-id", type=str, default=None, help="摄像头编号")

    args = parser.parse_args()

    monitor = SafetyGearMonitor(
        model_path=args.model,
        conf=args.conf,
        iou=args.iou,
        device=args.device,
        notify=args.notify,
        personnel_config=args.personnel_config,
    )
    monitor.camera_id = args.camera_id

    source = args.source
    if source.isdigit():
        source = int(source)

    monitor.detect(
        source=source,
        save=not args.nosave,
        show=args.show,
        alarm_interval=args.alarm_interval,
    )

    monitor.save_alarm_log()


if __name__ == "__main__":
    main()