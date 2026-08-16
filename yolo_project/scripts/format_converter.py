#!/usr/bin/env python3
"""
LabelStudio / LabelMe / COCO → YOLO 格式转换工具

支持的源格式:
  - Label Studio (JSON)
  - LabelMe (JSON)
  - COCO (JSON)
  - Pascal VOC (XML)

输出: YOLO 格式 (class_id cx cy w h, 归一化)
"""

import argparse
import json
import os
import sys
from pathlib import Path
from xml.etree import ElementTree as ET


class LabelStudioConverter:
    """Label Studio JSON → YOLO"""

    def __init__(self, class_map):
        self.class_map = class_map  # {label_name: class_id}

    def convert(self, json_path, output_dir):
        """转换 Label Studio 导出文件"""
        with open(json_path, "r") as f:
            data = json.load(f)

        output_dir = Path(output_dir)
        output_dir.mkdir(parents=True, exist_ok=True)

        count = 0
        skipped = 0

        for item in data:
            # 图片文件名
            img_name = Path(item.get("data", {}).get("image", "")).name
            if not img_name:
                # 尝试其他字段名
                img_name = Path(item.get("image", "")).name
            if not img_name:
                skipped += 1
                continue

            # 获取标注
            annotations = item.get("annotations", [])
            if not annotations:
                # 无标注的图片也复制 (作为负样本)
                skipped += 1
                continue

            # 获取图片尺寸
            # Label Studio 可能不直接提供尺寸, 需要从标注中推断
            boxes = []
            for ann in annotations:
                result = ann.get("result", [])
                for r in result:
                    if r.get("type") == "rectanglelabels":
                        label_name = r.get("value", {}).get("rectanglelabels", [""])[0]
                        if label_name not in self.class_map:
                            continue

                        cls_id = self.class_map[label_name]
                        # Label Studio 坐标: x, y, width, height (百分比 0-100)
                        x = r["value"]["x"] / 100.0
                        y = r["value"]["y"] / 100.0
                        w = r["value"]["width"] / 100.0
                        h = r["value"]["height"] / 100.0

                        cx = x + w / 2
                        cy = y + h / 2

                        boxes.append((cls_id, cx, cy, w, h))

            if boxes:
                # 保存 YOLO 标注
                stem = Path(img_name).stem
                lbl_path = output_dir / f"{stem}.txt"
                with open(lbl_path, "w") as f:
                    for cls_id, cx, cy, w, h in boxes:
                        f.write(f"{cls_id} {cx:.6f} {cy:.6f} {w:.6f} {h:.6f}\n")
                count += 1

        print(f"Label Studio 转换完成: {count} 个标注文件, 跳过 {skipped}")


class VOCConverter:
    """Pascal VOC XML → YOLO"""

    def __init__(self, class_map):
        self.class_map = class_map

    def convert(self, xml_dir, output_dir):
        xml_dir = Path(xml_dir)
        output_dir = Path(output_dir)
        output_dir.mkdir(parents=True, exist_ok=True)

        count = 0
        for xml_path in xml_dir.glob("*.xml"):
            tree = ET.parse(xml_path)
            root = tree.getroot()

            # 图片尺寸
            size = root.find("size")
            img_w = int(size.find("width").text)
            img_h = int(size.find("height").text)

            boxes = []
            for obj in root.findall("object"):
                name = obj.find("name").text
                if name not in self.class_map:
                    continue

                cls_id = self.class_map[name]
                bbox = obj.find("bndbox")
                xmin = int(bbox.find("xmin").text)
                ymin = int(bbox.find("ymin").text)
                xmax = int(bbox.find("xmax").text)
                ymax = int(bbox.find("ymax").text)

                w = xmax - xmin
                h = ymax - ymin
                cx = xmin + w / 2
                cy = ymin + h / 2

                boxes.append((
                    cls_id,
                    cx / img_w, cy / img_h,
                    w / img_w, h / img_h,
                ))

            if boxes:
                lbl_path = output_dir / f"{xml_path.stem}.txt"
                with open(lbl_path, "w") as f:
                    for cls_id, cx, cy, w, h in boxes:
                        f.write(f"{cls_id} {cx:.6f} {cy:.6f} {w:.6f} {h:.6f}\n")
                count += 1

        print(f"Pascal VOC 转换完成: {count} 个标注文件")


class COCOConverter:
    """COCO JSON → YOLO"""

    def __init__(self, class_map):
        # COCO 的 class_map: {coco_category_id: yolo_class_id}
        self.class_map = class_map

    def convert(self, json_path, output_dir):
        with open(json_path, "r") as f:
            data = json.load(f)

        output_dir = Path(output_dir)
        output_dir.mkdir(parents=True, exist_ok=True)

        # 构建 image_id -> (filename, width, height)
        images = {}
        for img in data["images"]:
            images[img["id"]] = (img["file_name"], img["width"], img["height"])

        # 构建 image_id -> [annotations]
        ann_by_image = {}
        for ann in data["annotations"]:
            img_id = ann["image_id"]
            if img_id not in ann_by_image:
                ann_by_image[img_id] = []
            ann_by_image[img_id].append(ann)

        count = 0
        for img_id, anns in ann_by_image.items():
            if img_id not in images:
                continue

            file_name, img_w, img_h = images[img_id]
            boxes = []

            for ann in anns:
                coco_cat_id = ann["category_id"]
                if coco_cat_id not in self.class_map:
                    continue

                cls_id = self.class_map[coco_cat_id]
                x, y, w, h = ann["bbox"]  # COCO: x,y,w,h (像素)

                cx = (x + w / 2) / img_w
                cy = (y + h / 2) / img_h
                nw = w / img_w
                nh = h / img_h

                boxes.append((cls_id, cx, cy, nw, nh))

            if boxes:
                stem = Path(file_name).stem
                lbl_path = output_dir / f"{stem}.txt"
                with open(lbl_path, "w") as f:
                    for cls_id, cx, cy, nw, nh in boxes:
                        f.write(f"{cls_id} {cx:.6f} {cy:.6f} {nw:.6f} {nh:.6f}\n")
                count += 1

        print(f"COCO 转换完成: {count} 个标注文件")


def main():
    parser = argparse.ArgumentParser(description="标注格式转换 → YOLO")
    parser.add_argument("--format", type=str, required=True,
                        choices=["labelstudio", "voc", "coco"],
                        help="源格式")
    parser.add_argument("--input", type=str, required=True,
                        help="输入文件/目录")
    parser.add_argument("--output", type=str, required=True,
                        help="YOLO 标注输出目录")
    parser.add_argument("--class-map", type=str, required=True,
                        help="类别映射 JSON: {'label_name': class_id}")

    args = parser.parse_args()

    with open(args.class_map, "r") as f:
        class_map = json.load(f)

    if args.format == "labelstudio":
        converter = LabelStudioConverter(class_map)
    elif args.format == "voc":
        converter = VOCConverter(class_map)
    elif args.format == "coco":
        converter = COCOConverter(class_map)

    converter.convert(args.input, args.output)


if __name__ == "__main__":
    main()