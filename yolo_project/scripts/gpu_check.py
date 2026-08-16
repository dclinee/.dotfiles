#!/usr/bin/env python3
"""
GPU 环境检测 & 自动配置
检测可用 GPU, 推荐最佳训练配置
"""

import argparse
import subprocess
import sys
from pathlib import Path


def check_nvidia_smi():
    """检查 nvidia-smi"""
    try:
        result = subprocess.run(
            ["nvidia-smi", "--query-gpu=name,memory.total,memory.free",
             "--format=csv,noheader,nounits"],
            capture_output=True, text=True, timeout=10,
        )
        if result.returncode == 0:
            return result.stdout.strip().split("\n")
        return []
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return []


def check_pytorch_cuda():
    """检查 PyTorch CUDA"""
    try:
        import torch
        cuda_available = torch.cuda.is_available()
        cuda_version = torch.version.cuda if cuda_available else "N/A"
        gpu_count = torch.cuda.device_count() if cuda_available else 0
        gpu_names = []
        if cuda_available:
            for i in range(gpu_count):
                gpu_names.append(torch.cuda.get_device_name(i))
        return {
            "available": cuda_available,
            "cuda_version": cuda_version,
            "gpu_count": gpu_count,
            "gpu_names": gpu_names,
        }
    except ImportError:
        return {"available": False, "error": "PyTorch 未安装"}


def check_ram():
    """检查系统内存"""
    try:
        import psutil
        mem = psutil.virtual_memory()
        return {
            "total_gb": mem.total / (1024**3),
            "available_gb": mem.available / (1024**3),
        }
    except ImportError:
        return {"total_gb": 0, "available_gb": 0}


def detect_gpu_vram():
    """检测 GPU 显存 (MB)"""
    gpus = check_nvidia_smi()
    result = []
    for gpu_info in gpus:
        parts = [p.strip() for p in gpu_info.split(",")]
        if len(parts) >= 3:
            result.append({
                "name": parts[0],
                "total_mb": int(parts[1]),
                "free_mb": int(parts[2]),
            })
    return result


def recommend_preset(gpu_vram_mb, dataset_size=0):
    """根据 GPU 显存和数据集大小推荐训练配置"""
    if gpu_vram_mb == 0:
        return {
            "preset": "cpu",
            "model": "yolo11n.pt",
            "batch": 4,
            "epochs": 50,
            "imgsz": 320,
            "reason": "未检测到 GPU, 使用 CPU 模式验证流程",
        }

    if dataset_size > 0 and dataset_size < 500:
        return {
            "preset": "finetune",
            "model": "yolo11s.pt",
            "batch": 16,
            "epochs": 50,
            "imgsz": 640,
            "reason": f"小数据集({dataset_size}张), 推荐微调模式",
        }

    if gpu_vram_mb < 4000:
        return {
            "preset": "n",
            "model": "yolo11n.pt",
            "batch": 16,
            "epochs": 100,
            "imgsz": 640,
            "reason": "显存 < 4GB, 推荐 Nano 模型",
        }
    elif gpu_vram_mb < 8000:
        return {
            "preset": "s",
            "model": "yolo11s.pt",
            "batch": 24,
            "epochs": 150,
            "imgsz": 640,
            "reason": "显存 4-8GB, 推荐 Small 模型",
        }
    elif gpu_vram_mb < 12000:
        return {
            "preset": "m",
            "model": "yolo11m.pt",
            "batch": 16,
            "epochs": 200,
            "imgsz": 640,
            "reason": "显存 8-12GB, 推荐 Medium 模型",
        }
    elif gpu_vram_mb < 24000:
        return {
            "preset": "l",
            "model": "yolo11l.pt",
            "batch": 12,
            "epochs": 200,
            "imgsz": 640,
            "reason": "显存 12-24GB, 推荐 Large 模型",
        }
    else:
        return {
            "preset": "x",
            "model": "yolo11x.pt",
            "batch": 8,
            "epochs": 200,
            "imgsz": 640,
            "reason": "显存 > 24GB, 可用 XLarge 模型",
        }


def main():
    parser = argparse.ArgumentParser(description="GPU 环境检测")
    parser.add_argument("--dataset", type=str, default=None,
                        help="数据集目录 (用于统计图片数)")
    parser.add_argument("--json", action="store_true",
                        help="JSON 格式输出")
    args = parser.parse_args()

    # 检测
    cuda_info = check_pytorch_cuda()
    gpu_vrams = detect_gpu_vram()
    ram_info = check_ram()

    # 统计数据集
    dataset_size = 0
    if args.dataset:
        p = Path(args.dataset)
        if p.exists():
            dataset_size = len(list(p.rglob("*.jpg"))) + len(list(p.rglob("*.png")))

    # 推荐
    max_vram = max([g["total_mb"] for g in gpu_vrams]) if gpu_vrams else 0
    rec = recommend_preset(max_vram, dataset_size)

    if args.json:
        import json
        print(json.dumps({
            "cuda": cuda_info,
            "gpus": gpu_vrams,
            "ram": ram_info,
            "dataset_size": dataset_size,
            "recommendation": rec,
        }, indent=2, ensure_ascii=False))
        return

    # 打印报告
    print("=" * 60)
    print("  GPU 环境检测报告")
    print("=" * 60)

    print(f"\n  PyTorch CUDA: {'可用' if cuda_info['available'] else '不可用'}")
    if cuda_info["available"]:
        print(f"  CUDA 版本: {cuda_info['cuda_version']}")
        print(f"  GPU 数量: {cuda_info['gpu_count']}")
        for i, name in enumerate(cuda_info["gpu_names"]):
            print(f"    GPU {i}: {name}")

    if gpu_vrams:
        print(f"\n  GPU 显存:")
        for gpu in gpu_vrams:
            print(f"    {gpu['name']}")
            print(f"      总量: {gpu['total_mb']}MB ({gpu['total_mb']/1024:.1f}GB)")
            print(f"      空闲: {gpu['free_mb']}MB ({gpu['free_mb']/1024:.1f}GB)")
    else:
        print(f"\n  GPU 显存: 未检测到")

    if ram_info["total_gb"] > 0:
        print(f"\n  系统内存: {ram_info['total_gb']:.1f}GB "
              f"(可用: {ram_info['available_gb']:.1f}GB)")

    if dataset_size > 0:
        print(f"\n  数据集: {dataset_size} 张图片")

    print(f"\n  {'='*60}")
    print(f"  推荐配置")
    print(f"  {'='*60}")
    print(f"  预设:     {rec['preset']}")
    print(f"  模型:     {rec['model']}")
    print(f"  Batch:    {rec['batch']}")
    print(f"  Epochs:   {rec['epochs']}")
    print(f"  图片尺寸: {rec['imgsz']}")
    print(f"  原因:     {rec['reason']}")

    print(f"\n  训练命令:")
    print(f"  python scripts/train.py \\")
    print(f"    --config configs/smart_construction.yaml \\")
    print(f"    --model {rec['model']} \\")
    print(f"    --batch {rec['batch']} \\")
    print(f"    --epochs {rec['epochs']} \\")
    print(f"    --imgsz {rec['imgsz']} \\")
    print(f"    --project runs/train \\")
    print(f"    --name {rec['preset']}_exp")
    print("=" * 60)


if __name__ == "__main__":
    main()