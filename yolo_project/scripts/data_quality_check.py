#!/usr/bin/env python3
"""
数据质量检查脚本
检查标注数据的问题:
  1. 标注框越界 (坐标超出0-1范围)
  2. 类别 ID 超出范围
  3. 标注框面积过小/过大
  4. 图片-标注文件不配对
  5. 空标注文件
  6. 图片损坏
  7. 标注重复/重叠异常
"""

import argparse
import os
import sys
from pathlib import Path
from collections import defaultdict, Counter
import cv2
import numpy as np
import yaml

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))


class DataQualityChecker:
    """数据质量检查器"""

    def __init__(self, dataset_config="configs/smart_construction.yaml"):
        with open(dataset_config, "r") as f:
            cfg = yaml.safe_load(f)

        self.nc = cfg["nc"]
        self.names = cfg["names"]
        self.dataset_path = Path(dataset_config).parent.parent / \
            Path(cfg.get("path", "datasets"))

        self.issues = []
        self.stats = {
            "total_images": 0,
            "total_labels": 0,
            "total_boxes": 0,
            "empty_labels": 0,
            "issues_found": 0,
            "by_class": defaultdict(int),
        }

    def check(self, split="train"):
        """执行全面质量检查"""
        img_dir = self.dataset_path / "images" / split
        lbl_dir = self.dataset_path / "labels" / split

        if not img_dir.exists():
            print(f"[错误] 图片目录不存在: {img_dir}")
            return
        if not lbl_dir.exists():
            print(f"[错误] 标注目录不存在: {lbl_dir}")
            return

        # 收集所有图片
        images = {}
        for ext in ["*.jpg", "*.jpeg", "*.png", "*.bmp"]:
            for p in img_dir.glob(ext):
                images[p.stem] = p

        labels = {}
        for p in lbl_dir.glob("*.txt"):
            labels[p.stem] = p

        self.stats["total_images"] = len(images)
        self.stats["total_labels"] = len(labels)

        print(f"检查 {split} 集: {len(images)} 张图片, {len(labels)} 个标注文件\n")

        # 1. 检查图片-标注配对
        orphan_images = set(images.keys()) - set(labels.keys())
        orphan_labels = set(labels.keys()) - set(images.keys())

        for stem in orphan_images:
            self._issue("no_label", f"图片 {stem} 缺少标注文件", stem)

        for stem in orphan_labels:
            self._issue("no_image", f"标注 {stem} 缺少对应图片", stem)

        # 2. 逐文件检查
        for stem in sorted(set(images.keys()) & set(labels.keys())):
            self._check_file(images[stem], labels[stem])

        self._print_report()

    def _check_file(self, img_path, lbl_path):
        """检查单个图片-标注对"""
        stem = img_path.stem

        # 检查图片是否可读
        img = cv2.imread(str(img_path))
        if img is None:
            self._issue("corrupt_image", f"图片损坏无法读取: {img_path.name}", stem)
            return
        h, w = img.shape[:2]

        # 检查图片尺寸
        if w < 100 or h < 100:
            self._issue("small_image", f"图片尺寸过小: {w}x{h}", stem, w=w, h=h)
        if w > 8000 or h > 8000:
            self._issue("large_image", f"图片尺寸过大: {w}x{h} (建议缩放到640-1280)", stem)

        # 读取标注
        try:
            with open(lbl_path, "r") as f:
                lines = f.readlines()
        except Exception as e:
            self._issue("read_error", f"标注文件读取失败: {e}", stem)
            return

        if not lines:
            self.stats["empty_labels"] += 1
            self._issue("empty_label", f"图片 {stem} 无标注框 (如果是负样本请忽略)", stem)
            return

        boxes = []
        for line_num, line in enumerate(lines):
            line = line.strip()
            if not line:
                continue

            parts = line.split()
            if len(parts) < 5:
                self._issue("bad_format",
                            f"标注格式错误 (第{line_num+1}行): 期望5个字段, 实际{len(parts)}个",
                            stem, line=line_num + 1)
                continue

            try:
                cls_id = int(parts[0])
                cx, cy, bw, bh = map(float, parts[1:5])
            except ValueError:
                self._issue("bad_value",
                            f"标注值解析失败 (第{line_num+1}行): {line}",
                            stem, line=line_num + 1)
                continue

            # 检查类别 ID
            if cls_id < 0 or cls_id >= self.nc:
                self._issue("bad_class",
                            f"类别 ID 超出范围: {cls_id} (有效范围 0-{self.nc - 1})",
                            stem, cls_id=cls_id, line=line_num + 1)

            # 检查坐标范围
            if cx < 0 or cx > 1 or cy < 0 or cy > 1:
                self._issue("coord_oob",
                            f"中心坐标越界: cx={cx:.3f}, cy={cy:.3f}",
                            stem, cx=cx, cy=cy)
            if bw <= 0 or bw > 1 or bh <= 0 or bh > 1:
                self._issue("size_oob",
                            f"框尺寸异常: bw={bw:.3f}, bh={bh:.3f}",
                            stem, bw=bw, bh=bh)

            # 检查框面积
            area = bw * bh * w * h
            if area < 16:  # 小于 4x4 像素
                self._issue("tiny_box",
                            f"标注框面积过小: {area:.0f}px² ({bw:.3f}x{bh:.3f})",
                            stem, area=area)
            if area > 0.9 * w * h:
                self._issue("huge_box",
                            f"标注框面积过大: {area:.0f}px² (占图片 {area/(w*h)*100:.0f}%)",
                            stem, area=area)

            boxes.append((cls_id, cx, cy, bw, bh))
            self.stats["total_boxes"] += 1
            self.stats["by_class"][cls_id] += 1

        # 检查标注框重叠 (同一类别)
        if len(boxes) > 1:
            self._check_overlap(boxes, w, h, stem)

    def _check_overlap(self, boxes, w, h, stem):
        """检查同一类别标注框的过度重叠"""
        from itertools import combinations

        for (i, b1), (j, b2) in combinations(enumerate(boxes), 2):
            cls1, cx1, cy1, bw1, bh1 = b1
            cls2, cx2, cy2, bw2, bh2 = b2

            if cls1 != cls2:
                continue

            # 计算 IoU
            x1_1 = (cx1 - bw1 / 2) * w
            y1_1 = (cy1 - bh1 / 2) * h
            x2_1 = (cx1 + bw1 / 2) * w
            y2_1 = (cy1 + bh1 / 2) * h

            x1_2 = (cx2 - bw2 / 2) * w
            y1_2 = (cy2 - bh2 / 2) * h
            x2_2 = (cx2 + bw2 / 2) * w
            y2_2 = (cy2 + bh2 / 2) * h

            inter_x1 = max(x1_1, x1_2)
            inter_y1 = max(y1_1, y1_2)
            inter_x2 = min(x2_1, x2_2)
            inter_y2 = min(y2_1, y2_2)

            if inter_x1 < inter_x2 and inter_y1 < inter_y2:
                inter_area = (inter_x2 - inter_x1) * (inter_y2 - inter_y1)
                area1 = (x2_1 - x1_1) * (y2_1 - y1_1)
                area2 = (x2_2 - x1_2) * (y2_2 - y1_2)
                iou = inter_area / (area1 + area2 - inter_area)

                if iou > 0.9:
                    cls_name = self.names.get(cls1, f"cls_{cls1}")
                    self._issue("high_overlap",
                                f"同类框 #{i+1} 和 #{j+1} ({cls_name}) IoU={iou:.2f}, "
                                f"可能重复标注",
                                stem, iou=iou)

    def _issue(self, issue_type, message, stem, **kwargs):
        self.issues.append({
            "type": issue_type,
            "message": message,
            "file": stem,
            **kwargs,
        })
        self.stats["issues_found"] += 1

    def _print_report(self):
        """打印质量报告"""
        s = self.stats
        print("\n" + "=" * 60)
        print("  数据质量检查报告")
        print("=" * 60)
        print(f"  图片: {s['total_images']} | 标注: {s['total_labels']}")
        print(f"  总标注框: {s['total_boxes']}")
        print(f"  空标注: {s['empty_labels']} (可能是负样本)")
        print(f"  问题数: {s['issues_found']}")

        if s["issues_found"] > 0:
            print(f"\n  问题分布:")
            by_type = Counter(i["type"] for i in self.issues)
            for t, c in by_type.most_common():
                desc = {
                    "no_label": "缺少标注文件",
                    "no_image": "缺少对应图片",
                    "corrupt_image": "图片损坏",
                    "empty_label": "空标注",
                    "bad_format": "格式错误",
                    "bad_value": "数值解析失败",
                    "bad_class": "类别ID越界",
                    "coord_oob": "坐标越界",
                    "size_oob": "框尺寸异常",
                    "tiny_box": "框面积过小",
                    "huge_box": "框面积过大",
                    "high_overlap": "重复标注",
                    "small_image": "图片尺寸过小",
                    "large_image": "图片尺寸过大",
                }.get(t, t)
                print(f"    [{t}] {desc}: {c} 处")

        # 类别分布
        print(f"\n  类别分布:")
        for cls_id in range(self.nc):
            name = self.names.get(cls_id, f"cls_{cls_id}")
            count = s["by_class"].get(cls_id, 0)
            pct = count / s["total_boxes"] * 100 if s["total_boxes"] > 0 else 0
            bar = "█" * int(pct / 5) + "░" * (20 - int(pct / 5))
            print(f"    [{cls_id}] {name:15s}: {count:5d} ({pct:5.1f}%) |{bar}|")

        # 判定
        if s["issues_found"] == 0:
            print(f"\n  [判定] 数据质量: 优秀")
        elif s["issues_found"] < s["total_images"] * 0.05:
            print(f"\n  [判定] 数据质量: 良好 (少量问题, 建议修复)")
        else:
            print(f"\n  [判定] 数据质量: 需修复 (问题较多, 训练前请清理)")

        print("=" * 60)

    def save_report(self, path="runs/data_quality/report.txt"):
        """保存报告到文件"""
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w") as f:
            f.write(f"数据质量检查报告\n")
            f.write(f"{'='*60}\n")
            f.write(f"总图片: {self.stats['total_images']}\n")
            f.write(f"总标注框: {self.stats['total_boxes']}\n")
            f.write(f"问题数: {self.stats['issues_found']}\n\n")
            for issue in self.issues:
                f.write(f"[{issue['type']}] {issue['file']}: {issue['message']}\n")
        print(f"\n报告已保存: {path}")


def main():
    parser = argparse.ArgumentParser(description="数据质量检查")
    parser.add_argument("--config", type=str, default="configs/smart_construction.yaml",
                        help="数据集配置文件")
    parser.add_argument("--split", type=str, default="train",
                        choices=["train", "val", "test"],
                        help="检查哪个数据集划分")
    parser.add_argument("--save", action="store_true", help="保存报告到文件")
    args = parser.parse_args()

    checker = DataQualityChecker(args.config)
    checker.check(args.split)

    if args.save:
        checker.save_report()


if __name__ == "__main__":
    main()