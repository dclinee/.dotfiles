#!/usr/bin/env python3
"""
智慧工地 - 数据集引导脚本
功能:
  1. 尝试下载公开安全帽/工地数据集 (有网络时)
  2. 无网络时用 OpenCV 生成合成工地数据集 (有标注)
  3. 自动划分 train/val + YOLO 格式

用法:
  # 生成合成数据 (默认, 无网可用)
  python scripts/dataset_bootstrap.py --generate --num-train 200 --num-val 50

  # 尝试下载公开数据集
  python scripts/dataset_bootstrap.py --download

  # 生成 + 质量检查 + 增强 (一键)
  python scripts/dataset_bootstrap.py --generate --quality --augment
"""

import argparse
import json
import os
import random
import shutil
import sys
from pathlib import Path
from typing import List, Tuple

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from utils.common import CLASS_NAMES, CLASS_COLORS, ensure_dir, now_str, clamp
from utils.logger import get_logger

logger = get_logger("dataset_bootstrap")

# ============================================================
# 合成数据集生成器
# 用 OpenCV 绘制模拟工地场景: 地面背景 + 人物剪影 + 安全帽/反光衣
# ============================================================

class SyntheticDatasetGenerator:
    """合成工地数据集生成器"""

    def __init__(self, output_dir: str = "datasets", img_size: Tuple[int, int] = (640, 480)):
        self.output_dir = Path(output_dir)
        self.img_w, self.img_h = img_size
        self.seed = 42

        # 场景背景颜色池 (工地常见颜色)
        self.bg_colors = [
            (100, 100, 100),   # 水泥灰
            (80, 90, 100),     # 阴天工地
            (120, 110, 80),    # 黄土色
            (90, 100, 120),    # 灰色建筑
            (70, 80, 90),      # 深色地面
        ]

        # 工人衣服颜色
        self.cloth_colors = [
            (30, 60, 120),     # 深蓝工服
            (50, 80, 40),      # 深绿工服
            (100, 60, 30),     # 棕色
            (60, 60, 80),      # 灰蓝
            (80, 50, 50),      # 暗红
        ]

        # 反光衣颜色 (黄/橙)
        self.vest_colors = [
            (50, 200, 255),    # 亮黄
            (30, 160, 255),    # 橙黄
        ]

        # 安全帽颜色
        self.helmet_colors = [
            (200, 50, 50),     # 红色
            (50, 100, 200),    # 蓝色
            (255, 255, 255),   # 白色
            (50, 200, 100),    # 绿色
            (255, 200, 0),     # 黄色
        ]

    def _set_seed(self, seed: int):
        self.seed = seed
        random.seed(seed)
        np.random.seed(seed)

    def _draw_background(self, img: np.ndarray, bg_type: str = "ground"):
        """绘制背景"""
        h, w = img.shape[:2]
        bg = random.choice(self.bg_colors)

        # 渐变背景
        for y in range(h):
            ratio = y / h
            color = tuple(
                int(bg[c] * (1 - ratio * 0.3)) for c in range(3)
            )
            img[y, :, :] = color

        # 地面纹理 (水平线)
        if bg_type == "ground":
            for i in range(5):
                y = int(h * 0.5 + i * (h * 0.1))
                cv2.line(img, (0, y), (w, y), (bg[0] - 10, bg[1] - 10, bg[2] - 10), 1)

            # 添加随机斑点
            for _ in range(100):
                x = random.randint(0, w - 1)
                y = random.randint(int(h * 0.5), h - 1)
                size = random.randint(1, 3)
                noise = random.randint(-30, 30)
                c = (clamp(bg[0] + noise, 0, 255),
                     clamp(bg[1] + noise, 0, 255),
                     clamp(bg[2] + noise, 0, 255))
                cv2.circle(img, (x, y), size, c, -1)

        # 建筑物轮廓
        if bg_type == "building":
            for _ in range(3):
                bx1 = random.randint(0, w // 2)
                bw = random.randint(w // 5, w // 2)
                bh = random.randint(h // 4, h // 2)
                by2 = int(h * 0.6)
                by1 = by2 - bh
                color = (bg[0] - 20, bg[1] - 20, bg[2] - 20)
                cv2.rectangle(img, (bx1, by1), (bx1 + bw, by2), color, -1)

        # 天空线
        horizon = int(h * 0.45)
        cv2.line(img, (0, horizon), (w, horizon),
                 (180, 180, 200), 2)

    def _draw_person(self, img: np.ndarray, x: int, y: int, scale: float = 1.0,
                     with_helmet: bool = True, with_vest: bool = True,
                     is_rgb: bool = True) -> List[dict]:
        """
        绘制一个人 (剪影风格, 近似站立)

        Args:
            x, y: 脚底中心位置
            scale: 缩放比例

        Returns:
            标注列表 [{cls_id, bbox_yolo}, ...]
        """
        import cv2

        labels = []
        h, w = img.shape[:2]

        # 比例: 身高约 250 * scale px, 站在地面线
        body_h = int(250 * scale)
        head_r = int(25 * scale)
        body_w = int(70 * scale)
        shoulder_y = y - body_h + int(head_r * 2.5)
        waist_y = y - int(body_h * 0.5)
        hip_y = y - int(body_h * 0.25)

        # 确保在画面内
        if x - body_w < 0 or x + body_w >= w or y - body_h - head_r < 0:
            return []

        # 衣服颜色
        cloth_c = random.choice(self.cloth_colors)
        vest_c = random.choice(self.vest_colors) if with_vest else None

        # 腿
        leg_w = int(body_w * 0.25)
        cv2.rectangle(img,
                      (x - leg_w - int(leg_w * 0.3), waist_y),
                      (x - int(leg_w * 0.3), y),
                      cloth_c, -1)
        cv2.rectangle(img,
                      (x + int(leg_w * 0.3), waist_y),
                      (x + leg_w + int(leg_w * 0.3), y),
                      cloth_c, -1)

        # 身体 (躯干)
        body_p1 = (x - body_w // 2, shoulder_y)
        body_p2 = (x + body_w // 2, waist_y)
        cv2.rectangle(img, body_p1, body_p2, cloth_c, -1)

        # person 框 (包含头和脚)
        p_x1 = x - body_w // 2 - 5
        p_y1 = y - body_h - head_r
        p_x2 = x + body_w // 2 + 5
        p_y2 = y + 5

        # 反光衣 (如果有)
        if with_vest:
            vest_y1 = shoulder_y + 5
            vest_y2 = waist_y - 10
            cv2.rectangle(img,
                          (x - body_w // 2 + 5, vest_y1),
                          (x + body_w // 2 - 5, vest_y2),
                          vest_c, -1)
            # 反光条
            stripe1_y = shoulder_y + int(body_h * 0.25)
            stripe2_y = shoulder_y + int(body_h * 0.45)
            cv2.line(img,
                     (x - body_w // 2, stripe1_y),
                     (x + body_w // 2, stripe1_y),
                     (255, 255, 255), 2)
            cv2.line(img,
                     (x - body_w // 2, stripe2_y),
                     (x + body_w // 2, stripe2_y),
                     (255, 255, 255), 2)

            # vest 框
            labels.append({
                "cls_id": 3,
                "bbox": (x - body_w // 2 + 5, vest_y1,
                         x + body_w // 2 - 5, vest_y2),
            })
        else:
            # no_vest
            labels.append({
                "cls_id": 4,
                "bbox": (body_p1[0], shoulder_y, body_p2[0], waist_y),
            })

        # 胳膊
        arm_w = int(body_w * 0.25)
        cv2.rectangle(img,
                      (x - body_w // 2 - arm_w, shoulder_y + 5),
                      (x - body_w // 2, waist_y - int(body_h * 0.2)),
                      cloth_c, -1)
        cv2.rectangle(img,
                      (x + body_w // 2, shoulder_y + 5),
                      (x + body_w // 2 + arm_w, waist_y - int(body_h * 0.2)),
                      cloth_c, -1)

        # 头部 (椭圆/圆)
        head_cy = y - body_h - head_r // 2
        head_cx = x
        cv2.circle(img, (head_cx, head_cy), head_r,
                   (80, 60, 50), -1)  # 肤色

        # 安全帽/不戴安全帽 框 (头部区域)
        h_x1 = head_cx - head_r
        h_y1 = head_cy - head_r
        h_x2 = head_cx + head_r
        h_y2 = head_cy + head_r

        if with_helmet:
            # 安全帽: 帽子部分
            helmet_c = random.choice(self.helmet_colors)
            # 帽沿
            cv2.ellipse(img, (head_cx, head_cy - head_r // 3),
                        (int(head_r * 1.4), int(head_r * 0.6)),
                        0, 0, 360, helmet_c, -1)
            # 帽顶
            cv2.rectangle(img,
                          (head_cx - head_r, head_cy - head_r - int(head_r * 0.3)),
                          (head_cx + head_r, head_cy - head_r // 3),
                          helmet_c, -1)
            # 安全帽边框
            labels.append({
                "cls_id": 1,
                "bbox": (head_cx - int(head_r * 1.4),
                         head_cy - head_r - int(head_r * 0.5),
                         head_cx + int(head_r * 1.4),
                         head_cy + head_r // 2),
            })
        else:
            # no_helmet: 只有头部
            labels.append({
                "cls_id": 2,
                "bbox": (h_x1, h_y1, h_x2, h_y2),
            })

        # person: 最外层框
        labels.append({
            "cls_id": 0,
            "bbox": (max(0, p_x1), max(0, p_y1), min(w - 1, p_x2), min(h - 1, p_y2)),
        })

        return labels

    def _draw_vehicle(self, img: np.ndarray, x: int, y: int,
                      scale: float = 1.0) -> List[dict]:
        """绘制一辆工程车 (简化版卡车)"""
        import cv2
        h, w = img.shape[:2]

        labels = []
        truck_w = int(220 * scale)
        truck_h = int(120 * scale)

        x1 = x - truck_w // 2
        y1 = y - truck_h
        x2 = x + truck_w // 2
        y2 = y

        if x1 < 0 or x2 >= w or y1 < 0:
            return []

        # 车身
        body_c = (180, 120, 40)
        cab_c = (60, 80, 100)
        # 货箱
        cv2.rectangle(img, (x1, y1 + int(truck_h * 0.1)),
                      (x1 + int(truck_w * 0.7), y1 + int(truck_h * 0.6)),
                      body_c, -1)
        # 驾驶室
        cv2.rectangle(img,
                      (x1 + int(truck_w * 0.7), y1 + int(truck_h * 0.4)),
                      (x2, y2 - int(truck_h * 0.3)),
                      cab_c, -1)
        # 底盘
        cv2.rectangle(img, (x1, y2 - int(truck_h * 0.3)),
                      (x2, y2), (40, 40, 40), -1)
        # 轮子
        wheel_r = int(truck_h * 0.15)
        for wx in [x1 + int(truck_w * 0.2), x1 + int(truck_w * 0.5),
                   x1 + int(truck_w * 0.85)]:
            cv2.circle(img, (wx, y2 - wheel_r), wheel_r, (20, 20, 20), -1)
            cv2.circle(img, (wx, y2 - wheel_r), int(wheel_r * 0.5),
                       (100, 100, 100), -1)

        labels.append({
            "cls_id": 5,
            "bbox": (x1, y1, x2, y2),
        })
        return labels

    def _draw_smoke_fire(self, img: np.ndarray, x: int, y: int,
                         scale: float = 1.0) -> List[dict]:
        """绘制火焰/烟雾"""
        import cv2
        h, w = img.shape[:2]
        labels = []

        fw = int(80 * scale)
        fh = int(120 * scale)

        x1 = x - fw // 2
        y1 = y - fh
        x2 = x + fw // 2
        y2 = y

        if x1 < 0 or x2 >= w or y1 < 0:
            return []

        # 火焰颜色渐变
        for i in range(5):
            ratio = i / 5
            radius = int(fw * (0.2 + ratio * 0.6))
            cy = y - int(fh * (0.3 + ratio * 0.5))
            c = (30, int(80 + ratio * 120), int(200 + ratio * 55))
            cv2.circle(img, (x, cy), radius, c, -1)

        # 烟雾 (灰色)
        for i in range(3):
            sx = x + random.randint(-fw // 2, fw // 2)
            sy = y - fh - random.randint(0, fh // 2)
            sr = int(fw * 0.3 * (1 + i * 0.3))
            gray = random.randint(120, 200)
            cv2.circle(img, (sx, sy), sr, (gray, gray, gray), -1)

        labels.append({
            "cls_id": 6,
            "bbox": (x1 - fw // 2, y1 - fh // 2, x2 + fw // 2, y2),
        })
        return labels

    def generate_image(self, idx: int, num_people: int = None) -> Tuple[str, List[dict]]:
        """
        生成一张合成图片 + 标注

        Returns:
            (img_filename, labels)
        """
        self._set_seed(self.seed + idx)
        import cv2

        img = np.zeros((self.img_h, self.img_w, 3), dtype=np.uint8)

        # 背景
        bg_type = random.choice(["ground", "ground", "ground", "building"])
        self._draw_background(img, bg_type)

        # 随机决定场景: 人数 + 是否有车/火焰
        if num_people is None:
            num_people = random.choice([2, 3, 4, 5, 6, 8])
        has_vehicle = random.random() < 0.15
        has_fire = random.random() < 0.08

        ground_y_min = int(self.img_h * 0.55)
        ground_y_max = self.img_h - 30

        all_labels = []
        occupied_x = []

        # 放置人 (从远到近, 后面的人 scale 小)
        people_list = []
        for i in range(num_people):
            depth = (i + 1) / (num_people + 1)
            scale = 0.35 + depth * 0.55  # 远的人小
            # 避免重叠
            for attempt in range(30):
                px = random.randint(int(self.img_w * 0.1), int(self.img_w * 0.9))
                py = ground_y_min + int(depth * (ground_y_max - ground_y_min))
                person_w = int(70 * scale)
                # 检查 x 不重叠
                overlap = False
                for ox, ow in occupied_x:
                    if abs(px - ox) < max(ow, person_w):
                        overlap = True
                        break
                if not overlap:
                    occupied_x.append((px, person_w))
                    people_list.append((px, py, scale))
                    break

        # 绘制所有人
        for px, py, scale in people_list:
            # 随机决定合规性 (大部分合规, 少数违规)
            with_helmet = random.random() < 0.75   # 75% 戴
            with_vest = random.random() < 0.70     # 70% 穿

            person_labels = self._draw_person(
                img, px, py, scale, with_helmet, with_vest
            )
            all_labels.extend(person_labels)

        # 车辆
        if has_vehicle:
            for _ in range(random.randint(1, 2)):
                scale = 0.6 + random.random() * 0.4
                vx = random.randint(int(self.img_w * 0.2), int(self.img_w * 0.8))
                vy = ground_y_max - 10
                v_labels = self._draw_vehicle(img, vx, vy, scale)
                all_labels.extend(v_labels)

        # 火/烟
        if has_fire:
            fx = random.randint(int(self.img_w * 0.2), int(self.img_w * 0.8))
            fy = ground_y_min + random.randint(0, ground_y_max - ground_y_min)
            sf_labels = self._draw_smoke_fire(img, fx, fy, 0.8)
            all_labels.extend(sf_labels)

        # 转 YOLO 格式
        yolo_labels = []
        for lbl in all_labels:
            x1, y1, x2, y2 = lbl["bbox"]
            if x2 <= x1 or y2 <= y1:
                continue
            cx = (x1 + x2) / 2 / self.img_w
            cy = (y1 + y2) / 2 / self.img_h
            bw = (x2 - x1) / self.img_w
            bh = (y2 - y1) / self.img_h
            if cx < 0 or cx > 1 or cy < 0 or cy > 1 or bw <= 0 or bh <= 0:
                continue
            yolo_labels.append(f"{lbl['cls_id']} {cx:.6f} {cy:.6f} {bw:.6f} {bh:.6f}")

        return img, yolo_labels

    def generate(self, num_train: int = 200, num_val: int = 50,
                 seed: int = 42) -> dict:
        """生成完整数据集"""
        self.seed = seed
        stats = {
            "total_images": num_train + num_val,
            "num_train": num_train,
            "num_val": num_val,
            "total_labels": 0,
            "labels_per_class": {},
        }

        for split, count in [("train", num_train), ("val", num_val)]:
            img_dir = ensure_dir(self.output_dir / "images" / split)
            lbl_dir = ensure_dir(self.output_dir / "labels" / split)

            logger.info(f"生成 {split} 集: {count} 张")

            for i in range(count):
                img, yolo_labels = self.generate_image(
                    idx=seed + (0 if split == "train" else num_train) + i,
                )
                fname = f"syn_scene_{split}_{i:04d}"
                img_path = img_dir / f"{fname}.jpg"
                lbl_path = lbl_dir / f"{fname}.txt"

                import cv2
                cv2.imwrite(str(img_path), img, [cv2.IMWRITE_JPEG_QUALITY, 90])
                lbl_path.write_text("\n".join(yolo_labels) + ("\n" if yolo_labels else ""))

                stats["total_labels"] += len(yolo_labels)
                for line in yolo_labels:
                    cls_id = int(line.split()[0])
                    cls_name = CLASS_NAMES.get(cls_id, f"cls_{cls_id}")
                    stats["labels_per_class"][cls_name] = \
                        stats["labels_per_class"].get(cls_name, 0) + 1

                if (i + 1) % 50 == 0:
                    logger.info(f"  {i + 1}/{count} 完成")

        return stats


# ============================================================
# 公开数据集下载 (可选)
# ============================================================

def try_download_datasets(dest_dir: Path) -> dict:
    """
    尝试下载公开安全帽数据集
    无网络或失败时返回空 dict, 由调用者改用合成数据
    """
    import urllib.request
    import zipfile
    import io

    sources = [
        {
            "name": "Safety Helmet Dataset",
            "urls": [
                # Roboflow 常用公开集 (可能需要 API key, 尝试通用镜像)
                # 如失败则跳过
            ],
        },
    ]

    # 简单网络探测
    try:
        urllib.request.urlopen("https://www.google.com", timeout=5)
        logger.info("有网络, 但无预配置可直接下载的数据集, 将使用合成数据")
    except Exception:
        logger.info("无网络访问, 使用合成数据集")

    return {}  # 目前统一使用合成数据


# ============================================================
# 主函数
# ============================================================

def main():
    global cv2
    import cv2  # 延迟导入

    parser = argparse.ArgumentParser(description="智慧工地数据集引导脚本")
    parser.add_argument("--output", type=str, default="datasets",
                        help="数据集输出目录")
    parser.add_argument("--generate", action="store_true",
                        help="生成合成数据集")
    parser.add_argument("--download", action="store_true",
                        help="尝试下载公开数据集")
    parser.add_argument("--num-train", type=int, default=200,
                        help="训练集图片数")
    parser.add_argument("--num-val", type=int, default=50,
                        help="验证集图片数")
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument("--quality", action="store_true",
                        help="生成后运行质量检查")
    parser.add_argument("--augment", action="store_true",
                        help="生成后运行数据增强")

    args = parser.parse_args()

    output = Path(args.output)
    stats = {}

    if args.download:
        stats = try_download_datasets(output)

    if args.generate or (args.download and not stats):
        generator = SyntheticDatasetGenerator(str(output))
        stats = generator.generate(args.num_train, args.num_val, args.seed)
        print(f"\n合成数据集生成完成:")
        print(json.dumps(stats, indent=2, ensure_ascii=False))

    if args.quality:
        logger.info("运行数据质量检查...")
        subprocess.run([
            sys.executable, "scripts/data_quality_check.py",
            "--dataset-dir", str(output), "--split", "train", "--save",
        ], cwd=str(Path(__file__).resolve().parent.parent))
        subprocess.run([
            sys.executable, "scripts/data_quality_check.py",
            "--dataset-dir", str(output), "--split", "val", "--save",
        ], cwd=str(Path(__file__).resolve().parent.parent))

    if args.augment:
        logger.info("运行数据增强...")
        subprocess.run([
            sys.executable, "scripts/data_augment.py",
            "--input", str(output),
            "--output", str(output),
            "--augmentations", "flip_h,brightness,blur,gaussian_noise",
        ], cwd=str(Path(__file__).resolve().parent.parent))

    print("\n数据集引导完成 ✓")
    print(f"  图片: datasets/images/train (训练)")
    print(f"  图片: datasets/images/val   (验证)")
    print(f"  标注: datasets/labels/train")
    print(f"  标注: datasets/labels/val")
    print(f"  下一步: python scripts/train_pipeline.py --preset n --epochs 20")


import subprocess


if __name__ == "__main__":
    main()