#!/usr/bin/env python3
"""
数据增强脚本
在训练前对标注数据进行增强, 扩充数据集

支持的增强:
  - 水平翻转 / 垂直翻转
  - 亮度/对比度/饱和度调整
  - 高斯噪声 / 椒盐噪声
  - 旋转 (90°/180°/270°)
  - 模糊 (高斯模糊/运动模糊)
  - 随机裁剪 (保持标注框)

输出: 增强后的图片和对应的 YOLO 格式标注
"""

import argparse
import os
import random
import sys
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor, as_completed
import cv2
import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))


class DataAugmentor:
    """数据增强器"""

    def __init__(self, input_dir, output_dir, seed=42):
        self.input_dir = Path(input_dir)
        self.output_dir = Path(output_dir)
        random.seed(seed)
        np.random.seed(seed)

        self.output_dir.mkdir(parents=True, exist_ok=True)
        (self.output_dir / "images" / "train").mkdir(parents=True, exist_ok=True)
        (self.output_dir / "labels" / "train").mkdir(parents=True, exist_ok=True)

    def _load_data(self, split="train"):
        """加载图片和标注"""
        img_dir = self.input_dir / "images" / split
        lbl_dir = self.input_dir / "labels" / split

        pairs = []
        for img_path in img_dir.glob("*.jpg"):
            lbl_path = lbl_dir / f"{img_path.stem}.txt"
            if lbl_path.exists():
                pairs.append((img_path, lbl_path))
        for img_path in img_dir.glob("*.png"):
            lbl_path = lbl_dir / f"{img_path.stem}.txt"
            if lbl_path.exists():
                pairs.append((img_path, lbl_path))

        return pairs

    def _read_labels(self, lbl_path):
        """读取 YOLO 格式标注"""
        boxes = []
        if lbl_path.exists():
            with open(lbl_path, "r") as f:
                for line in f:
                    parts = line.strip().split()
                    if len(parts) >= 5:
                        cls_id = int(parts[0])
                        cx, cy, bw, bh = map(float, parts[1:5])
                        boxes.append((cls_id, cx, cy, bw, bh))
        return boxes

    def _save_labels(self, boxes, path):
        """保存 YOLO 格式标注"""
        with open(path, "w") as f:
            for cls_id, cx, cy, bw, bh in boxes:
                f.write(f"{cls_id} {cx:.6f} {cy:.6f} {bw:.6f} {bh:.6f}\n")

    # ============================================================
    # 增强方法
    # ============================================================

    def flip_horizontal(self, img, boxes):
        """水平翻转"""
        img = cv2.flip(img, 1)
        new_boxes = []
        for cls_id, cx, cy, bw, bh in boxes:
            new_boxes.append((cls_id, 1.0 - cx, cy, bw, bh))
        return img, new_boxes

    def flip_vertical(self, img, boxes):
        """垂直翻转"""
        img = cv2.flip(img, 0)
        new_boxes = []
        for cls_id, cx, cy, bw, bh in boxes:
            new_boxes.append((cls_id, cx, 1.0 - cy, bw, bh))
        return img, new_boxes

    def adjust_brightness_contrast(self, img, boxes):
        """亮度/对比度调整"""
        alpha = random.uniform(0.7, 1.3)  # 对比度
        beta = random.randint(-30, 30)     # 亮度
        img = cv2.convertScaleAbs(img, alpha=alpha, beta=beta)
        return img, boxes

    def adjust_saturation(self, img, boxes):
        """饱和度调整"""
        hsv = cv2.cvtColor(img, cv2.COLOR_BGR2HSV).astype(np.float32)
        hsv[:, :, 1] *= random.uniform(0.5, 1.5)
        hsv[:, :, 1] = np.clip(hsv[:, :, 1], 0, 255)
        img = cv2.cvtColor(hsv.astype(np.uint8), cv2.COLOR_HSV2BGR)
        return img, boxes

    def add_gaussian_noise(self, img, boxes):
        """高斯噪声"""
        noise = np.random.normal(0, random.randint(5, 15), img.shape).astype(np.uint8)
        img = cv2.add(img, noise)
        return img, boxes

    def add_salt_pepper_noise(self, img, boxes):
        """椒盐噪声"""
        amount = random.uniform(0.001, 0.01)
        salt = np.random.random(img.shape[:2]) < amount / 2
        pepper = np.random.random(img.shape[:2]) < amount / 2
        img[salt] = 255
        img[pepper] = 0
        return img, boxes

    def rotate_90(self, img, boxes):
        """旋转 90°"""
        img = cv2.rotate(img, cv2.ROTATE_90_CLOCKWISE)
        new_boxes = []
        for cls_id, cx, cy, bw, bh in boxes:
            new_boxes.append((cls_id, cy, 1.0 - cx, bh, bw))
        return img, new_boxes

    def rotate_180(self, img, boxes):
        """旋转 180°"""
        img = cv2.rotate(img, cv2.ROTATE_180)
        new_boxes = []
        for cls_id, cx, cy, bw, bh in boxes:
            new_boxes.append((cls_id, 1.0 - cx, 1.0 - cy, bw, bh))
        return img, new_boxes

    def rotate_270(self, img, boxes):
        """旋转 270°"""
        img = cv2.rotate(img, cv2.ROTATE_90_COUNTERCLOCKWISE)
        new_boxes = []
        for cls_id, cx, cy, bw, bh in boxes:
            new_boxes.append((cls_id, 1.0 - cy, cx, bh, bw))
        return img, new_boxes

    def gaussian_blur(self, img, boxes):
        """高斯模糊"""
        ksize = random.choice([3, 5])
        img = cv2.GaussianBlur(img, (ksize, ksize), 0)
        return img, boxes

    # ============================================================
    # 执行
    # ============================================================

    def augment(self, split="train", augmentations=None, max_workers=4):
        """
        执行数据增强

        Args:
            split: 数据集划分
            augmentations: 要应用的增强列表, None=全部
            max_workers: 并行数
        """
        pairs = self._load_data(split)
        print(f"找到 {len(pairs)} 个图片-标注对")

        all_augs = {
            "flip_h": self.flip_horizontal,
            "flip_v": self.flip_vertical,
            "brightness": self.adjust_brightness_contrast,
            "saturation": self.adjust_saturation,
            "gaussian_noise": self.add_gaussian_noise,
            "salt_pepper": self.add_salt_pepper_noise,
            "rotate_90": self.rotate_90,
            "rotate_180": self.rotate_180,
            "rotate_270": self.rotate_270,
            "blur": self.gaussian_blur,
        }

        if augmentations is None:
            augmentations = list(all_augs.keys())
        else:
            # 验证增强名称
            for aug_name in augmentations:
                if aug_name not in all_augs:
                    print(f"未知增强: {aug_name}, 可用: {list(all_augs.keys())}")
                    return

        print(f"应用增强: {augmentations}")

        total_generated = 0
        img_out = self.output_dir / "images" / "train"
        lbl_out = self.output_dir / "labels" / "train"

        # 先复制原始数据
        print("复制原始数据...")
        for img_path, lbl_path in pairs:
            cv2.imwrite(str(img_out / img_path.name),
                        cv2.imread(str(img_path)))
            with open(lbl_path, "r") as src, \
                 open(lbl_out / lbl_path.name, "w") as dst:
                dst.write(src.read())

        # 并行增强
        tasks = []
        for img_path, lbl_path in pairs:
            for aug_name in augmentations:
                tasks.append((img_path, lbl_path, aug_name))

        print(f"生成增强数据 ({len(tasks)} 个任务)...")

        def process_one(item):
            img_path, lbl_path, aug_name = item
            img = cv2.imread(str(img_path))
            if img is None:
                return None
            boxes = self._read_labels(lbl_path)
            aug_func = all_augs[aug_name]

            try:
                aug_img, aug_boxes = aug_func(img, boxes)
            except Exception as e:
                return None

            stem = f"{img_path.stem}_{aug_name}"
            cv2.imwrite(str(img_out / f"{stem}.jpg"), aug_img)
            self._save_labels(aug_boxes, lbl_out / f"{stem}.txt")
            return aug_name

        with ThreadPoolExecutor(max_workers=max_workers) as executor:
            futures = [executor.submit(process_one, t) for t in tasks]
            for f in as_completed(futures):
                if f.result():
                    total_generated += 1

            # 进度
            if total_generated % 100 == 0:
                pass

        final_count = len(list(img_out.glob("*.jpg"))) + len(list(img_out.glob("*.png")))
        print(f"\n增强完成! 原始: {len(pairs)} -> 增强后: {final_count}")
        print(f"生成: {total_generated} 张新图片")
        print(f"输出目录: {self.output_dir.resolve()}")


def main():
    parser = argparse.ArgumentParser(description="数据增强")
    parser.add_argument("--input", type=str, default="datasets",
                        help="输入数据集目录")
    parser.add_argument("--output", type=str, default="datasets_augmented",
                        help="输出目录")
    parser.add_argument("--augmentations", type=str, nargs="+",
                        default=["flip_h", "brightness", "blur", "gaussian_noise"],
                        help="要应用的增强: flip_h flip_v brightness saturation "
                             "gaussian_noise salt_pepper rotate_90 rotate_180 rotate_270 blur")
    parser.add_argument("--workers", type=int, default=4,
                        help="并行数")
    args = parser.parse_args()

    augmentor = DataAugmentor(args.input, args.output)
    augmentor.augment(augmentations=args.augmentations, max_workers=args.workers)


if __name__ == "__main__":
    main()