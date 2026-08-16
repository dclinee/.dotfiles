#!/usr/bin/env python3
"""
一键数据准备流程
整合: 格式转换 → 数据划分 → 质量检查 → 数据增强 → 生成配置

用法:
  python scripts/data_pipeline.py --raw-images ./raw_photos --raw-labels ./raw_labels
"""

import argparse
import os
import sys
import subprocess
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
PROJECT_DIR = SCRIPT_DIR.parent


def run_step(step_name, cmd):
    """运行单个步骤"""
    print(f"\n{'='*60}")
    print(f"  [{step_name}]")
    print(f"{'='*60}")
    result = subprocess.run(cmd, shell=True, cwd=str(PROJECT_DIR))
    if result.returncode != 0:
        print(f"  [失败] {step_name} (exit={result.returncode})")
        return False
    print(f"  [完成] {step_name}")
    return True


def main():
    parser = argparse.ArgumentParser(
        description="一键数据准备流程",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
示例:
  # 基础流程: 原始数据 → YOLO 数据集
  python scripts/data_pipeline.py --raw-images ./raw_photos --raw-labels ./raw_labels

  # 含格式转换: Label Studio JSON → YOLO
  python scripts/data_pipeline.py --convert --format labelstudio --input annotation.json

  # 含数据增强: 训练集扩充 3 倍
  python scripts/data_pipeline.py --raw-images ./raw --raw-labels ./labels --augment

  # 完整流程
  python scripts/data_pipeline.py --raw-images ./raw --raw-labels ./labels --augment --quality-check
        """,
    )

    # 数据源
    parser.add_argument("--raw-images", type=str, default=None,
                        help="原始图片目录")
    parser.add_argument("--raw-labels", type=str, default=None,
                        help="原始标注目录 (YOLO 格式)")

    # 格式转换
    parser.add_argument("--convert", action="store_true",
                        help="启用格式转换")
    parser.add_argument("--format", type=str, default="labelstudio",
                        choices=["labelstudio", "voc", "coco"],
                        help="源格式")
    parser.add_argument("--input", type=str, default=None,
                        help="转换输入文件")
    parser.add_argument("--class-map", type=str,
                        default="configs/class_map.json",
                        help="类别映射文件")

    # 数据集划分
    parser.add_argument("--output", type=str, default="datasets",
                        help="输出数据集目录")
    parser.add_argument("--ratio", type=float, default=0.8,
                        help="训练集比例")

    # 增强 & 检查
    parser.add_argument("--augment", action="store_true",
                        help="启用数据增强")
    parser.add_argument("--augmentations", type=str, nargs="+",
                        default=["flip_h", "brightness", "blur"],
                        help="数据增强方法")
    parser.add_argument("--quality-check", action="store_true",
                        help="启用质量检查")
    parser.add_argument("--skip-split", action="store_true",
                        help="跳过数据划分 (数据已划分好)")

    args = parser.parse_args()

    steps = []
    success = True

    # Step 1: 格式转换
    if args.convert:
        if not args.input:
            print("[错误] 格式转换需要 --input 参数")
            sys.exit(1)

        steps.append((
            "格式转换",
            f"python scripts/format_converter.py "
            f"--format {args.format} "
            f"--input {args.input} "
            f"--output {args.output}/labels/train "
            f"--class-map {args.class_map}"
        ))

    # Step 2: 数据划分
    if not args.skip_split and args.raw_images and args.raw_labels:
        steps.append((
            "数据划分",
            f"python scripts/dataset_prepare.py split "
            f"--images {args.raw_images} "
            f"--labels {args.raw_labels} "
            f"--output {args.output} "
            f"--ratio {args.ratio}"
        ))
    elif args.skip_split:
        print("跳过数据划分 (数据已就绪)")

    # Step 3: 质量检查
    if args.quality_check:
        steps.append((
            "质量检查 (训练集)",
            f"python scripts/data_quality_check.py "
            f"--split train --save"
        ))
        steps.append((
            "质量检查 (验证集)",
            f"python scripts/data_quality_check.py "
            f"--split val --save"
        ))

    # Step 4: 数据增强
    if args.augment:
        augs = " ".join(args.augmentations)
        aug_output = f"{args.output}_augmented"
        steps.append((
            "数据增强",
            f"python scripts/data_augment.py "
            f"--input {args.output} "
            f"--output {aug_output} "
            f"--augmentations {augs} "
            f"--workers 4"
        ))

    # Step 5: 统计
    steps.append((
        "数据集统计",
        f"python scripts/dataset_prepare.py stats "
        f"--labels {args.output}/labels/train "
        f"--names configs/smart_construction.yaml"
    ))

    # 执行步骤
    print(f"\n{'#'*60}")
    print(f"  智慧工地 - 数据准备流程")
    print(f"{'#'*60}")
    print(f"  共 {len(steps)} 个步骤\n")

    for step_name, cmd in steps:
        if not run_step(step_name, cmd):
            success = False
            break

    # 最终汇总
    print(f"\n{'#'*60}")
    if success:
        print(f"  数据准备流程完成!")
        print(f"  数据集目录: {Path(args.output).resolve()}")
        if args.augment:
            print(f"  增强数据集: {Path(args.output + '_augmented').resolve()}")
        print(f"\n  下一步:")
        print(f"    python scripts/train.py --config configs/smart_construction.yaml --model yolo11n.pt --epochs 100")
    else:
        print(f"  流程中断, 请检查上面的错误信息")
    print(f"{'#'*60}")


if __name__ == "__main__":
    main()