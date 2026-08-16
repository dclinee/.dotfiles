#!/usr/bin/env python3
"""
可视化工具
"""

import cv2
import numpy as np
from pathlib import Path
import matplotlib.pyplot as plt


def draw_boxes(image, boxes, class_names, conf_threshold=0.25, line_width=2):
    """
    在图片上绘制检测框

    Args:
        image: numpy array (H, W, 3) BGR
        boxes: ultralytics Results.boxes 对象
        class_names: dict {class_id: name}
        conf_threshold: 置信度阈值
        line_width: 框线宽

    Returns:
        绘制后的图片 (numpy array, BGR)
    """
    colors = {}
    np.random.seed(42)
    for i in range(100):
        colors[i] = tuple(np.random.randint(50, 255, 3).tolist())

    img = image.copy()
    h, w = img.shape[:2]

    for box in boxes:
        cls_id = int(box.cls[0])
        conf = float(box.conf[0])

        if conf < conf_threshold:
            continue

        x1, y1, x2, y2 = box.xyxy[0].tolist()
        x1, y1, x2, y2 = int(x1), int(y1), int(x2), int(y2)
        color = colors.get(cls_id, (0, 255, 0))

        cv2.rectangle(img, (x1, y1), (x2, y2), color, line_width)

        label = f"{class_names.get(cls_id, f'cls_{cls_id}')} {conf:.2f}"
        (tw, th), _ = cv2.getTextSize(label, cv2.FONT_HERSHEY_SIMPLEX, 0.6, 2)
        cv2.rectangle(img, (x1, y1 - th - 6), (x1 + tw + 4, y1), color, -1)
        cv2.putText(img, label, (x1 + 2, y1 - 4),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255, 255, 255), 2)

    return img


def plot_training_results(results_dir):
    """
    绘制训练结果对比图

    Args:
        results_dir: 训练结果目录 (包含 results.csv)
    """
    import pandas as pd

    results_dir = Path(results_dir)
    csv_path = results_dir / "results.csv"

    if not csv_path.exists():
        print(f"未找到 results.csv: {csv_path}")
        return

    df = pd.read_csv(csv_path)
    df.columns = df.columns.str.strip()

    fig, axes = plt.subplots(2, 3, figsize=(18, 10))

    # Loss
    for ax, col, title in [
        (axes[0, 0], "train/box_loss", "Train Box Loss"),
        (axes[0, 1], "train/cls_loss", "Train Class Loss"),
        (axes[0, 2], "train/dfl_loss", "Train DFL Loss"),
        (axes[1, 0], "val/box_loss", "Val Box Loss"),
        (axes[1, 1], "val/cls_loss", "Val Class Loss"),
        (axes[1, 2], "val/dfl_loss", "Val DFL Loss"),
    ]:
        if col in df.columns:
            ax.plot(df[col], label=col)
            ax.set_title(title)
            ax.set_xlabel("Epoch")
            ax.grid(True, alpha=0.3)

    plt.tight_layout()
    save_path = results_dir / "training_curves.png"
    plt.savefig(save_path, dpi=150)
    plt.close()
    print(f"训练曲线已保存: {save_path}")

    # mAP
    fig, axes = plt.subplots(1, 2, figsize=(12, 5))
    for ax, col, title in [
        (axes[0], "metrics/mAP50(B)", "mAP@50"),
        (axes[1], "metrics/mAP50-95(B)", "mAP@50-95"),
    ]:
        if col in df.columns:
            ax.plot(df[col], label=col)
            ax.set_title(title)
            ax.set_xlabel("Epoch")
            ax.grid(True, alpha=0.3)

    plt.tight_layout()
    save_path = results_dir / "metrics_curves.png"
    plt.savefig(save_path, dpi=150)
    plt.close()
    print(f"指标曲线已保存: {save_path}")