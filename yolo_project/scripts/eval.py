#!/usr/bin/env python3
"""
YOLOv11 模型评估脚本
评估指标: mAP@50, mAP@50-95, Precision, Recall
"""

import argparse
from pathlib import Path
import yaml
from ultralytics import YOLO


def parse_args():
    parser = argparse.ArgumentParser(description="YOLOv11 模型评估")
    parser.add_argument(
        "--model", type=str, required=True,
        help="模型权重路径"
    )
    parser.add_argument(
        "--data", type=str, default="configs/dataset.yaml",
        help="数据集配置文件"
    )
    parser.add_argument(
        "--imgsz", type=int, default=640,
        help="图片尺寸"
    )
    parser.add_argument(
        "--batch", type=int, default=16,
        help="批次大小"
    )
    parser.add_argument(
        "--device", type=str, default="0",
        help="设备"
    )
    parser.add_argument(
        "--conf", type=float, default=0.001,
        help="评估置信度阈值"
    )
    parser.add_argument(
        "--iou", type=float, default=0.6,
        help="评估 IoU 阈值"
    )
    parser.add_argument(
        "--split", type=str, default="val",
        choices=["val", "test"],
        help="评估数据集划分"
    )
    parser.add_argument(
        "--save_json", action="store_true",
        help="保存评估结果为 JSON"
    )
    parser.add_argument(
        "--plots", action="store_true", default=True,
        help="生成评估图表"
    )
    return parser.parse_args()


def main():
    args = parse_args()

    model_path = Path(args.model)
    if not model_path.exists():
        raise FileNotFoundError(f"模型不存在: {model_path}")

    model = YOLO(str(model_path))

    results = model.val(
        data=args.data,
        imgsz=args.imgsz,
        batch=args.batch,
        device=args.device,
        conf=args.conf,
        iou=args.iou,
        split=args.split,
        save_json=args.save_json,
        plots=args.plots,
    )

    # 打印主要指标
    print("\n" + "=" * 50)
    print("评估结果")
    print("=" * 50)
    print(f"mAP@50:      {results.box.map50:.4f}")
    print(f"mAP@50-95:   {results.box.map:.4f}")
    print(f"Precision:   {results.box.mp:.4f}")
    print(f"Recall:      {results.box.mr:.4f}")

    # 逐类别指标
    if hasattr(results.box, "ap_class_index"):
        print("\n逐类别 AP:")
        for i, ap in enumerate(results.box.ap):
            cls = results.box.ap_class_index[i]
            print(f"  类别 {cls}: AP@50-95 = {ap:.4f}")


if __name__ == "__main__":
    main()