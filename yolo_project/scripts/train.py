#!/usr/bin/env python3
"""
YOLOv11 训练脚本
支持从零训练、微调、恢复训练等多种模式
"""

import argparse
import os
import yaml
from pathlib import Path
from ultralytics import YOLO


def parse_args():
    parser = argparse.ArgumentParser(description="YOLOv11 训练脚本")
    parser.add_argument(
        "--config", type=str, default="configs/dataset.yaml",
        help="数据集配置文件路径"
    )
    parser.add_argument(
        "--model", type=str, default="yolo11n.pt",
        choices=[
            "yolo11n.pt", "yolo11s.pt", "yolo11m.pt",
            "yolo11l.pt", "yolo11x.pt",
            "yolo11n.pt", "yolo11s.pt",  # 对齐
        ],
        help="预训练模型，n/s/m/l/x 从小到大"
    )
    parser.add_argument(
        "--epochs", type=int, default=100,
        help="训练轮数"
    )
    parser.add_argument(
        "--imgsz", type=int, default=640,
        help="输入图片尺寸"
    )
    parser.add_argument(
        "--batch", type=int, default=16,
        help="批次大小"
    )
    parser.add_argument(
        "--device", type=str, default="0",
        help="训练设备: 0 (GPU0), cpu, 或 '0,1' (多GPU)"
    )
    parser.add_argument(
        "--lr0", type=float, default=0.01,
        help="初始学习率"
    )
    parser.add_argument(
        "--lrf", type=float, default=0.01,
        help="最终学习率因子 (lr0 * lrf)"
    )
    parser.add_argument(
        "--patience", type=int, default=50,
        help="早停 patience，验证集无提升则提前停止"
    )
    parser.add_argument(
        "--resume", action="store_true",
        help="从上次中断处恢复训练"
    )
    parser.add_argument(
        "--freeze", type=int, default=None,
        help="冻结前 N 层 (迁移学习时使用)"
    )
    parser.add_argument(
        "--project", type=str, default="runs/train",
        help="训练结果保存目录"
    )
    parser.add_argument(
        "--name", type=str, default="exp",
        help="本次训练实验名称"
    )
    parser.add_argument(
        "--augment", action="store_true",
        help="启用更强数据增强 (适合小数据集)"
    )
    parser.add_argument(
        "--cos_lr", action="store_true", default=True,
        help="使用余弦学习率调度"
    )
    parser.add_argument(
        "--close_mosaic", type=int, default=10,
        help="最后 N 个 epoch 关闭 mosaic 增强"
    )
    return parser.parse_args()


def main():
    args = parse_args()

    # 确保配置文件存在
    config_path = Path(args.config)
    if not config_path.exists():
        raise FileNotFoundError(f"数据集配置文件不存在: {config_path}")

    # 加载配置确认类别
    with open(config_path, "r") as f:
        dataset_cfg = yaml.safe_load(f)
    print(f"类别数量: {dataset_cfg['nc']}")
    print(f"类别名称: {dataset_cfg['names']}")

    # 加载模型
    if args.resume:
        # 恢复训练: 查找最近的 checkpoint
        runs_dir = Path(args.project)
        last_pt = sorted(runs_dir.rglob("**/weights/last.pt"))
        if last_pt:
            model = YOLO(str(last_pt[-1]))
            print(f"从 checkpoint 恢复: {last_pt[-1]}")
        else:
            raise FileNotFoundError("未找到可恢复的 checkpoint")
    else:
        model = YOLO(args.model)
        print(f"加载预训练模型: {args.model}")

    # 训练参数
    results = model.train(
        data=str(config_path.resolve()),
        epochs=args.epochs,
        imgsz=args.imgsz,
        batch=args.batch,
        device=args.device,
        lr0=args.lr0,
        lrf=args.lrf,
        patience=args.patience,
        freeze=args.freeze,
        project=args.project,
        name=args.name,
        cos_lr=args.cos_lr,
        close_mosaic=args.close_mosaic,
        augment=args.augment,
        # 常用优化参数
        optimizer="auto",       # 自动选择优化器
        weight_decay=0.0005,    # 权重衰减
        warmup_epochs=3,        # 预热轮数
        warmup_momentum=0.8,    # 预热动量
        # 保存设置
        save=True,
        save_period=10,         # 每 10 个 epoch 保存一次
        exist_ok=True,          # 覆盖同名实验
        pretrained=True,        # 使用预训练权重
        # 验证
        val=True,
        plots=True,             # 生成训练曲线图
    )

    print(f"\n训练完成! 最佳模型: {results.save_dir}/weights/best.pt")
    print(f"训练结果: {results.save_dir}/")


if __name__ == "__main__":
    main()