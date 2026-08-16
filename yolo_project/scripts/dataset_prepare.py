#!/usr/bin/env python3
"""
数据集预处理工具
支持:
  1. 随机划分训练集/验证集
  2. 格式转换 (COCO/VOC -> YOLO)
  3. 数据集统计分析
  4. 数据增强预览
"""

import argparse
import os
import random
import shutil
from pathlib import Path
import yaml
import cv2
import numpy as np
from collections import Counter


def parse_args():
    parser = argparse.ArgumentParser(description="数据集预处理工具")
    subparsers = parser.add_subparsers(dest="command", help="子命令")

    # split: 划分训练集/验证集
    split_parser = subparsers.add_parser("split", help="划分训练集/验证集")
    split_parser.add_argument("--images", type=str, required=True, help="图片目录")
    split_parser.add_argument("--labels", type=str, required=True, help="标注目录 (YOLO格式)")
    split_parser.add_argument("--output", type=str, default="../datasets", help="输出目录")
    split_parser.add_argument("--ratio", type=float, default=0.8, help="训练集比例 (默认 0.8)")
    split_parser.add_argument("--seed", type=int, default=42, help="随机种子")

    # stats: 统计数据集信息
    stats_parser = subparsers.add_parser("stats", help="统计数据集信息")
    stats_parser.add_argument("--labels", type=str, required=True, help="标注目录")
    stats_parser.add_argument("--names", type=str, default=None, help="类别名称文件 (yaml)")

    # convert: 格式转换 (VOC -> YOLO)
    convert_parser = subparsers.add_parser("convert", help="格式转换")
    convert_parser.add_argument("--format", type=str, required=True,
                                choices=["voc", "coco"],
                                help="源格式")
    convert_parser.add_argument("--annotations", type=str, required=True, help="标注文件路径")
    convert_parser.add_argument("--output", type=str, required=True, help="输出目录")
    convert_parser.add_argument("--class_map", type=str, required=True, help="类别映射 yaml")

    # visualize: 可视化标注
    vis_parser = subparsers.add_parser("visualize", help="可视化标注")
    vis_parser.add_argument("--images", type=str, required=True, help="图片目录")
    vis_parser.add_argument("--labels", type=str, required=True, help="标注目录")
    vis_parser.add_argument("--names", type=str, default=None, help="类别名称 yaml")
    vis_parser.add_argument("--output", type=str, default="dataset_vis", help="输出目录")
    vis_parser.add_argument("--num", type=int, default=10, help="可视化数量")

    return parser.parse_args()


def split_dataset(images_dir, labels_dir, output_dir, ratio, seed):
    """划分训练集和验证集"""
    random.seed(seed)

    images_dir = Path(images_dir)
    labels_dir = Path(labels_dir)
    output_dir = Path(output_dir)

    # 收集所有图片文件
    image_files = []
    for ext in ["*.jpg", "*.jpeg", "*.png", "*.bmp", "*.tiff"]:
        image_files.extend(images_dir.glob(ext))

    if not image_files:
        raise FileNotFoundError(f"在 {images_dir} 中未找到图片文件")

    # 过滤出有对应标注文件的图片
    valid_files = []
    for img_path in image_files:
        label_path = labels_dir / f"{img_path.stem}.txt"
        if label_path.exists():
            valid_files.append(img_path)

    if not valid_files:
        raise FileNotFoundError(f"在 {images_dir} 和 {labels_dir} 中未找到匹配的图片-标注对")

    print(f"找到 {len(valid_files)} 个有效图片-标注对")

    # 随机打乱
    random.shuffle(valid_files)
    split_idx = int(len(valid_files) * ratio)
    train_files = valid_files[:split_idx]
    val_files = valid_files[split_idx:]

    # 创建输出目录
    train_img_dir = output_dir / "images" / "train"
    val_img_dir = output_dir / "images" / "val"
    train_lbl_dir = output_dir / "labels" / "train"
    val_lbl_dir = output_dir / "labels" / "val"

    for d in [train_img_dir, val_img_dir, train_lbl_dir, val_lbl_dir]:
        d.mkdir(parents=True, exist_ok=True)

    # 复制文件
    def copy_files(file_list, img_dst, lbl_dst):
        for img_path in file_list:
            shutil.copy2(img_path, img_dst / img_path.name)
            label_path = labels_dir / f"{img_path.stem}.txt"
            shutil.copy2(label_path, lbl_dst / label_path.name)

    copy_files(train_files, train_img_dir, train_lbl_dir)
    copy_files(val_files, val_img_dir, val_lbl_dir)

    print(f"训练集: {len(train_files)} 张")
    print(f"验证集: {len(val_files)} 张")
    print(f"数据已保存到: {output_dir.resolve()}")


def dataset_stats(labels_dir, names_file):
    """统计数据集信息"""
    labels_dir = Path(labels_dir)
    label_files = list(labels_dir.glob("*.txt"))

    if not label_files:
        raise FileNotFoundError(f"在 {labels_dir} 中未找到标注文件")

    # 加载类别名称
    class_names = {}
    if names_file:
        with open(names_file, "r") as f:
            cfg = yaml.safe_load(f)
            class_names = {i: name for i, name in enumerate(cfg.get("names", []))}

    # 统计
    class_counts = Counter()
    total_boxes = 0
    image_box_counts = []

    for label_file in label_files:
        with open(label_file, "r") as f:
            lines = f.readlines()
        total_boxes += len(lines)
        image_box_counts.append(len(lines))

        for line in lines:
            parts = line.strip().split()
            if len(parts) >= 5:
                class_id = int(parts[0])
                class_counts[class_id] += 1

    print(f"=" * 50)
    print(f"数据集统计")
    print(f"=" * 50)
    print(f"图片总数:     {len(label_files)}")
    print(f"标注框总数:   {total_boxes}")
    print(f"平均每张框数: {total_boxes / len(label_files):.2f}")
    print(f"最多框数:     {max(image_box_counts)}")
    print(f"最少框数:     {min(image_box_counts)}")
    print(f"\n类别分布:")
    for class_id, count in sorted(class_counts.items()):
        name = class_names.get(class_id, f"class_{class_id}")
        pct = count / total_boxes * 100
        print(f"  [{class_id}] {name}: {count} ({pct:.1f}%)")

    return class_counts


def visualize_labels(images_dir, labels_dir, names_file, output_dir, num):
    """可视化标注框"""
    import matplotlib.pyplot as plt
    import matplotlib.patches as patches

    images_dir = Path(images_dir)
    labels_dir = Path(labels_dir)
    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    # 加载类别名称
    class_names = {}
    colors = {}
    if names_file:
        with open(names_file, "r") as f:
            cfg = yaml.safe_load(f)
            class_names = {i: name for i, name in enumerate(cfg.get("names", []))}

    # 收集图片
    image_files = []
    for ext in ["*.jpg", "*.jpeg", "*.png"]:
        image_files.extend(images_dir.glob(ext))
    image_files = image_files[:num]

    # 生成颜色映射
    np.random.seed(42)
    for i in range(100):
        colors[i] = tuple(np.random.randint(50, 255, 3).tolist())

    for img_path in image_files:
        label_path = labels_dir / f"{img_path.stem}.txt"
        if not label_path.exists():
            continue

        img = cv2.imread(str(img_path))
        img = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
        h, w = img.shape[:2]

        fig, ax = plt.subplots(1, figsize=(12, 8))
        ax.imshow(img)

        with open(label_path, "r") as f:
            for line in f:
                parts = line.strip().split()
                if len(parts) < 5:
                    continue
                class_id = int(parts[0])
                cx, cy, bw, bh = map(float, parts[1:5])

                # 转换为像素坐标
                x1 = (cx - bw / 2) * w
                y1 = (cy - bh / 2) * h
                box_w = bw * w
                box_h = bh * h

                color = [c / 255 for c in colors.get(class_id, (255, 0, 0))]
                rect = patches.Rectangle(
                    (x1, y1), box_w, box_h,
                    linewidth=2, edgecolor=color, facecolor="none"
                )
                ax.add_patch(rect)
                name = class_names.get(class_id, f"cls_{class_id}")
                ax.text(x1, y1 - 5, name, color=color, fontsize=10,
                        bbox=dict(facecolor="white", alpha=0.7))

        ax.set_title(img_path.name)
        ax.axis("off")
        plt.tight_layout()
        save_path = output_dir / f"{img_path.stem}_vis.jpg"
        plt.savefig(save_path, dpi=150, bbox_inches="tight")
        plt.close(fig)
        print(f"已保存: {save_path}")

    print(f"\n可视化完成，共 {len(image_files)} 张，保存在 {output_dir}")


def main():
    args = parse_args()

    if args.command == "split":
        split_dataset(args.images, args.labels, args.output, args.ratio, args.seed)
    elif args.command == "stats":
        dataset_stats(args.labels, args.names)
    elif args.command == "visualize":
        visualize_labels(args.images, args.labels, args.names, args.output, args.num)
    elif args.command == "convert":
        print("格式转换功能暂未实现，请先将数据转为 YOLO 格式后使用")
        print("YOLO 格式: class_id cx cy w h (归一化坐标)")
    else:
        print("请指定子命令: split / stats / visualize / convert")
        print("示例: python dataset_prepare.py split --images ./images --labels ./labels")


if __name__ == "__main__":
    main()