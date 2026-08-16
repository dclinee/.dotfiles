#!/usr/bin/env python3
"""
YOLOv11 推理脚本
支持单张图片、图片目录、视频文件、摄像头实时推理
"""

import argparse
import os
import sys
from pathlib import Path
import cv2
import numpy as np
from ultralytics import YOLO


def parse_args():
    parser = argparse.ArgumentParser(description="YOLOv11 推理脚本")
    parser.add_argument(
        "--model", type=str, required=True,
        help="模型权重路径 (e.g. runs/train/exp/weights/best.pt)"
    )
    parser.add_argument(
        "--source", type=str, required=True,
        help="推理源: 图片路径 / 图片目录 / 视频路径 / 0 (摄像头)"
    )
    parser.add_argument(
        "--conf", type=float, default=0.25,
        help="置信度阈值"
    )
    parser.add_argument(
        "--iou", type=float, default=0.7,
        help="NMS IoU 阈值"
    )
    parser.add_argument(
        "--imgsz", type=int, default=640,
        help="推理图片尺寸"
    )
    parser.add_argument(
        "--device", type=str, default="0",
        help="推理设备: 0 / cpu"
    )
    parser.add_argument(
        "--save", action="store_true", default=True,
        help="保存推理结果"
    )
    parser.add_argument(
        "--save_txt", action="store_true",
        help="保存检测结果为 txt 文件"
    )
    parser.add_argument(
        "--save_conf", action="store_true",
        help="保存时附带置信度"
    )
    parser.add_argument(
        "--nosave", action="store_true",
        help="不保存推理结果"
    )
    parser.add_argument(
        "--project", type=str, default="runs/inference",
        help="推理结果保存目录"
    )
    parser.add_argument(
        "--name", type=str, default="exp",
        help="推理实验名称"
    )
    parser.add_argument(
        "--show", action="store_true",
        help="实时显示推理结果"
    )
    parser.add_argument(
        "--line_width", type=int, default=2,
        help="绘制框线宽"
    )
    return parser.parse_args()


def main():
    args = parse_args()

    # 加载模型
    if not Path(args.model).exists():
        raise FileNotFoundError(f"模型文件不存在: {args.model}")
    model = YOLO(args.model)
    print(f"模型加载成功: {args.model}")

    # 处理 source 参数
    source = args.source
    if source.isdigit():
        source = int(source)  # 摄像头编号

    # 执行推理
    results = model.predict(
        source=source,
        conf=args.conf,
        iou=args.iou,
        imgsz=args.imgsz,
        device=args.device,
        save=not args.nosave,
        save_txt=args.save_txt,
        save_conf=args.save_conf,
        project=args.project,
        name=args.name,
        show=args.show,
        line_width=args.line_width,
        exist_ok=True,
    )

    # 打印检测结果摘要
    print(f"\n推理完成! 结果保存在: {Path(args.project) / args.name}")
    print(f"共处理 {len(results)} 个输入")

    for i, result in enumerate(results):
        boxes = result.boxes
        if boxes is not None and len(boxes) > 0:
            print(f"  [{i}] 检测到 {len(boxes)} 个目标")


if __name__ == "__main__":
    main()