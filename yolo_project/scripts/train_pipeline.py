#!/usr/bin/env python3
"""
一键训练-评估-导出流程
整合: GPU检测 → 训练 → 评估 → 导出

用法:
  python scripts/train_pipeline.py                    # 自动检测GPU并训练
  python scripts/train_pipeline.py --preset s          # 指定预设
  python scripts/train_pipeline.py --preset n --epochs 50 --finetune  # 微调
"""

import argparse
import os
import sys
import subprocess
import yaml
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
PROJECT_DIR = SCRIPT_DIR.parent


def run(cmd, desc=""):
    """运行命令"""
    if desc:
        print(f"\n  [{desc}]")
    result = subprocess.run(cmd, shell=True, cwd=str(PROJECT_DIR))
    if result.returncode != 0:
        print(f"  失败 (exit={result.returncode})")
        sys.exit(1)
    return True


def main():
    parser = argparse.ArgumentParser(
        description="一键训练-评估-导出流程",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
示例:
  # 自动检测 GPU 并训练
  python scripts/train_pipeline.py

  # 指定 Small 模型训练
  python scripts/train_pipeline.py --preset s --epochs 150

  # 微调模式
  python scripts/train_pipeline.py --preset finetune --epochs 50

  # 多模型对比训练
  python scripts/train_pipeline.py --preset n,s,m --epochs 100 --compare
        """,
    )

    # 训练参数
    parser.add_argument("--preset", type=str, default="auto",
                        help="训练预设: auto/n/s/m/l/x/finetune/cpu, 或逗号分隔多个")
    parser.add_argument("--config", type=str, default="configs/smart_construction.yaml",
                        help="数据集配置")
    parser.add_argument("--epochs", type=int, default=None,
                        help="训练轮数 (覆盖预设)")
    parser.add_argument("--batch", type=int, default=None,
                        help="批次大小 (覆盖预设)")
    parser.add_argument("--imgsz", type=int, default=None,
                        help="图片尺寸 (覆盖预设)")
    parser.add_argument("--device", type=str, default=None,
                        help="设备 (覆盖预设)")
    parser.add_argument("--finetune", action="store_true",
                        help="强制使用微调模式")
    parser.add_argument("--freeze", type=int, default=None,
                        help="冻结层数")

    # 流程控制
    parser.add_argument("--skip-eval", action="store_true",
                        help="跳过评估")
    parser.add_argument("--skip-export", action="store_true",
                        help="跳过导出")
    parser.add_argument("--compare", action="store_true",
                        help="多模型对比")
    parser.add_argument("--project", type=str, default="runs/train",
                        help="训练结果目录")
    parser.add_argument("--name", type=str, default=None,
                        help="实验名称")

    args = parser.parse_args()

    # 加载预设
    with open("configs/train_presets.yaml", "r") as f:
        presets_cfg = yaml.safe_load(f)

    # 处理多预设
    presets = args.preset.split(",") if args.preset != "auto" else ["auto"]

    print(f"{'#'*60}")
    print(f"  智慧工地 - 训练流程")
    print(f"{'#'*60}")
    print(f"  预设: {args.preset}")
    print(f"  数据集: {args.config}")
    print(f"{'#'*60}")

    trained_models = []

    for preset in presets:
        preset = preset.strip()

        if preset == "auto":
            # 自动检测 GPU
            print("\n自动检测 GPU 环境...")
            result = subprocess.run(
                ["python", "scripts/gpu_check.py", "--json"],
                capture_output=True, text=True, cwd=str(PROJECT_DIR),
            )
            try:
                gpu_info = json.loads(result.stdout)
                rec = gpu_info.get("recommendation", {})
                preset = rec.get("preset", "cpu")
                print(f"  自动选择预设: {preset} ({rec.get('reason', '')})")
            except Exception:
                print("  无法检测 GPU, 使用默认 nano 预设")
                preset = "n"

        if preset not in presets_cfg["presets"]:
            print(f"  未知预设: {preset}, 可用: {list(presets_cfg['presets'].keys())}")
            continue

        preset_cfg = presets_cfg["presets"][preset]

        if args.finetune:
            preset_cfg = presets_cfg["presets"]["finetune"]

        # 构建训练命令
        model = preset_cfg["model"]
        batch = args.batch or preset_cfg.get("batch", 16)
        epochs = args.epochs or preset_cfg.get("epochs", 100)
        imgsz = args.imgsz or preset_cfg.get("imgsz", 640)
        device = args.device or preset_cfg.get("device", "0")
        lr0 = preset_cfg.get("lr0", 0.01)
        lrf = preset_cfg.get("lrf", 0.01)
        patience = preset_cfg.get("patience", 50)

        exp_name = args.name or f"{preset}_exp"

        train_cmd = (
            f"python scripts/train.py "
            f"--config {args.config} "
            f"--model {model} "
            f"--batch {batch} "
            f"--epochs {epochs} "
            f"--imgsz {imgsz} "
            f"--device {device} "
            f"--lr0 {lr0} "
            f"--lrf {lrf} "
            f"--patience {patience} "
            f"--project {args.project} "
            f"--name {exp_name}"
        )

        if args.freeze is not None:
            train_cmd += f" --freeze {args.freeze}"
        elif preset_cfg.get("freeze"):
            train_cmd += f" --freeze {preset_cfg['freeze']}"
        if preset_cfg.get("augment"):
            train_cmd += " --augment"

        # Step 1: 训练
        print(f"\n{'='*60}")
        print(f"  训练: {preset} ({model})")
        print(f"  Batch={batch}, Epochs={epochs}, ImgSz={imgsz}")
        print(f"{'='*60}")
        run(train_cmd, f"训练 {preset}")

        # 找到最佳模型
        exp_dir = Path(args.project) / exp_name
        best_model = exp_dir / "weights" / "best.pt"
        if not best_model.exists():
            # 尝试找 last.pt
            best_model = exp_dir / "weights" / "last.pt"

        if best_model.exists():
            trained_models.append(str(best_model))

            # Step 2: 评估
            if not args.skip_eval:
                run(f"python scripts/eval.py "
                    f"--model {best_model} "
                    f"--data {args.config}",
                    f"评估 {preset}")

            # Step 3: 导出 ONNX
            if not args.skip_export:
                run(f"python scripts/export.py "
                    f"--model {best_model} "
                    f"--format onnx",
                    f"导出 ONNX {preset}")

    # 多模型对比
    if args.compare and len(trained_models) > 1:
        models_str = " ".join(trained_models)
        run(f"python scripts/model_compare.py "
            f"--models {models_str} "
            f"--data {args.config} "
            f"--save model_comparison.json",
            "模型对比")

    # 最终汇总
    print(f"\n{'#'*60}")
    print(f"  训练流程完成!")
    print(f"{'#'*60}")
    for mp in trained_models:
        print(f"  模型: {mp}")
    print(f"\n  下一步:")
    print(f"    python scripts/inference.py --model {trained_models[0] if trained_models else 'best.pt'} --source your_video.mp4")
    print(f"{'#'*60}")


if __name__ == "__main__":
    main()