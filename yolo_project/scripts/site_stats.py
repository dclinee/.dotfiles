#!/usr/bin/env python3
"""
智慧工地 - 工地人员/车辆统计与报表
统计各区域人员数量、安全装备合规率、生成日报/周报
"""

import argparse
import os
import csv
import json
from pathlib import Path
from datetime import datetime, timedelta
from collections import defaultdict, Counter
import cv2
import numpy as np
from ultralytics import YOLO


class SiteStatsCollector:
    """工地数据统计收集器"""

    def __init__(self, model_path, conf=0.3, device="0"):
        self.model = YOLO(model_path)
        self.conf = conf
        self.device = device

        # 统计数据结构
        self.frame_stats = []
        self.summary = {
            "total_frames": 0,
            "total_persons": 0,
            "total_helmets": 0,
            "total_no_helmets": 0,
            "total_vests": 0,
            "total_no_vests": 0,
            "total_vehicles": 0,
            "helmet_compliance": 0.0,  # 安全帽佩戴率
            "vest_compliance": 0.0,     # 反光衣穿戴率
            "max_persons": 0,           # 最大同时在场人数
            "avg_persons": 0.0,         # 平均在场人数
            "detection_time": "",
        }

    def collect_from_video(self, source, sample_interval=5):
        """
        从视频流采集统计数据

        Args:
            source: 视频文件路径 或 RTSP 地址
            sample_interval: 采样间隔 (每 N 帧统计一次)
        """
        results = self.model.predict(
            source=source,
            conf=self.conf,
            device=self.device,
            stream=True,
            verbose=False,
        )

        frame_count = 0
        start_time = datetime.now()

        for result in results:
            frame_count += 1

            if frame_count % sample_interval != 0:
                continue

            boxes = result.boxes
            if boxes is None:
                continue

            frame_data = self._extract_frame_data(boxes, frame_count)
            self.frame_stats.append(frame_data)
            self.summary["total_frames"] += 1

        self.summary["detection_time"] = str(datetime.now() - start_time)
        self._compute_summary()

    def collect_from_image_dir(self, image_dir):
        """从图片目录采集统计"""
        image_dir = Path(image_dir)
        image_files = []
        for ext in ["*.jpg", "*.jpeg", "*.png"]:
            image_files.extend(image_dir.glob(ext))

        if not image_files:
            raise FileNotFoundError(f"未找到图片: {image_dir}")

        start_time = datetime.now()

        for i, img_path in enumerate(image_files):
            results = self.model.predict(
                source=str(img_path),
                conf=self.conf,
                device=self.device,
                verbose=False,
            )

            for result in results:
                boxes = result.boxes
                if boxes is None:
                    continue
                frame_data = self._extract_frame_data(boxes, i + 1)
                self.frame_stats.append(frame_data)
                self.summary["total_frames"] += 1

        self.summary["detection_time"] = str(datetime.now() - start_time)
        self._compute_summary()

    def _extract_frame_data(self, boxes, frame_id):
        """从检测框提取统计数据"""
        data = {
            "frame_id": frame_id,
            "person": 0,
            "helmet": 0,
            "no_helmet": 0,
            "vest": 0,
            "no_vest": 0,
            "vehicle": 0,
            "smoke_fire": 0,
        }

        for box in boxes:
            cls_id = int(box.cls[0])
            conf = float(box.conf[0])

            if conf < self.conf:
                continue

            class_map = {
                0: "person", 1: "helmet", 2: "no_helmet",
                3: "vest", 4: "no_vest", 5: "vehicle", 6: "smoke_fire",
            }

            name = class_map.get(cls_id)
            if name:
                data[name] += 1

        return data

    def _compute_summary(self):
        """计算汇总统计"""
        if not self.frame_stats:
            return

        for fs in self.frame_stats:
            self.summary["total_persons"] += fs["person"]
            self.summary["total_helmets"] += fs["helmet"]
            self.summary["total_no_helmets"] += fs["no_helmet"]
            self.summary["total_vests"] += fs["vest"]
            self.summary["total_no_vests"] += fs["no_vest"]
            self.summary["total_vehicles"] += fs["vehicle"]

            self.summary["max_persons"] = max(
                self.summary["max_persons"], fs["person"]
            )

        n = self.summary["total_frames"]
        if n > 0:
            self.summary["avg_persons"] = self.summary["total_persons"] / n

        # 安全帽佩戴率
        total_helmet = self.summary["total_helmets"] + self.summary["total_no_helmets"]
        if total_helmet > 0:
            self.summary["helmet_compliance"] = (
                self.summary["total_helmets"] / total_helmet * 100
            )

        # 反光衣穿戴率
        total_vest = self.summary["total_vests"] + self.summary["total_no_vests"]
        if total_vest > 0:
            self.summary["vest_compliance"] = (
                self.summary["total_vests"] / total_vest * 100
            )

    def print_summary(self):
        """打印统计摘要"""
        s = self.summary
        print("\n" + "=" * 60)
        print("  智慧工地 - 安全检测统计报告")
        print("=" * 60)
        print(f"  检测时间:       {s['detection_time']}")
        print(f"  分析帧数:       {s['total_frames']}")
        print(f"  检测总人数:     {s['total_persons']}")
        print(f"  最大同时在场:   {s['max_persons']}")
        print(f"  平均在场人数:   {s['avg_persons']:.1f}")
        print(f"  检测车辆数:     {s['total_vehicles']}")
        print("-" * 60)
        print(f"  安全帽检测:     {s['total_helmets'] + s['total_no_helmets']}")
        print(f"    佩戴:         {s['total_helmets']}")
        print(f"    未佩戴:       {s['total_no_helmets']}")
        print(f"    佩戴率:       {s['helmet_compliance']:.1f}%")
        print("-" * 60)
        print(f"  反光衣检测:     {s['total_vests'] + s['total_no_vests']}")
        print(f"    穿着:         {s['total_vests']}")
        print(f"    未穿着:       {s['total_no_vests']}")
        print(f"    穿着率:       {s['vest_compliance']:.1f}%")
        print("=" * 60)

        # 合规评估
        if s["helmet_compliance"] >= 95 and s["vest_compliance"] >= 95:
            print("  [评估] 安全装备合规率优秀")
        elif s["helmet_compliance"] >= 80 and s["vest_compliance"] >= 80:
            print("  [评估] 安全装备合规率良好，需持续关注")
        else:
            print("  [评估] 安全装备合规率不达标，需立即整改!")

    def save_csv(self, path="runs/site_stats/stats.csv"):
        """保存统计数据到 CSV"""
        if not self.frame_stats:
            print("无统计数据可保存")
            return

        os.makedirs(os.path.dirname(path), exist_ok=True)

        fieldnames = [
            "frame_id", "person", "helmet", "no_helmet",
            "vest", "no_vest", "vehicle", "smoke_fire",
        ]

        with open(path, "w", newline="") as f:
            writer = csv.DictWriter(f, fieldnames=fieldnames)
            writer.writeheader()
            writer.writerows(self.frame_stats)

        print(f"统计数据已保存: {path}")

    def save_summary_json(self, path="runs/site_stats/summary.json"):
        """保存摘要到 JSON"""
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w") as f:
            json.dump(self.summary, f, indent=2, ensure_ascii=False)
        print(f"摘要已保存: {path}")

    def generate_report(self, output_dir="runs/site_stats"):
        """生成完整统计报告"""
        os.makedirs(output_dir, exist_ok=True)
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")

        self.print_summary()
        self.save_csv(os.path.join(output_dir, f"stats_{timestamp}.csv"))
        self.save_summary_json(os.path.join(output_dir, f"summary_{timestamp}.json"))


def main():
    parser = argparse.ArgumentParser(description="智慧工地 - 人员统计与报表")
    parser.add_argument("--model", type=str, required=True, help="训练好的模型路径")
    parser.add_argument("--source", type=str, required=True, help="视频/图片目录/RTSP流")
    parser.add_argument("--conf", type=float, default=0.3, help="置信度阈值")
    parser.add_argument("--device", type=str, default="0", help="设备")
    parser.add_argument("--sample_interval", type=int, default=5,
                        help="采样间隔 (每N帧统计一次)")
    parser.add_argument("--output", type=str, default="runs/site_stats",
                        help="输出目录")
    parser.add_argument("--mode", type=str, default="auto",
                        choices=["auto", "video", "images"],
                        help="数据源模式: auto/video/images")
    args = parser.parse_args()

    collector = SiteStatsCollector(
        model_path=args.model,
        conf=args.conf,
        device=args.device,
    )

    source = args.source
    source_path = Path(source)

    if args.mode == "images" or (args.mode == "auto" and source_path.is_dir()):
        print(f"从图片目录采集: {source}")
        collector.collect_from_image_dir(source)
    else:
        if source.isdigit():
            source = int(source)
        print(f"从视频流采集: {source}")
        collector.collect_from_video(source, sample_interval=args.sample_interval)

    collector.generate_report(output_dir=args.output)


if __name__ == "__main__":
    main()