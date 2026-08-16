#!/usr/bin/env python3
"""
YOLOv11 模型导出脚本
支持导出为: ONNX, TensorRT, OpenVINO, CoreML, TFLite 等格式
"""

import argparse
from pathlib import Path
from ultralytics import YOLO


def parse_args():
    parser = argparse.ArgumentParser(description="YOLOv11 模型导出")
    parser.add_argument(
        "--model", type=str, required=True,
        help="模型权重路径"
    )
    parser.add_argument(
        "--format", type=str, default="onnx",
        choices=["onnx", "engine", "openvino", "coreml", "tflite", "torchscript"],
        help="导出格式: onnx (通用) / engine (TensorRT) / openvino / tflite"
    )
    parser.add_argument(
        "--imgsz", type=int, default=640,
        help="导出图片尺寸"
    )
    parser.add_argument(
        "--half", action="store_true",
        help="FP16 半精度导出"
    )
    parser.add_argument(
        "--int8", action="store_true",
        help="INT8 量化导出 (需要校准数据)"
    )
    parser.add_argument(
        "--dynamic", action="store_true",
        help="导出动态尺寸 ONNX 模型"
    )
    parser.add_argument(
        "--simplify", action="store_true", default=True,
        help="简化 ONNX 模型"
    )
    parser.add_argument(
        "--opset", type=int, default=12,
        help="ONNX opset 版本"
    )
    parser.add_argument(
        "--workspace", type=float, default=4.0,
        help="TensorRT workspace (GB)"
    )
    return parser.parse_args()


def main():
    args = parse_args()

    model_path = Path(args.model)
    if not model_path.exists():
        raise FileNotFoundError(f"模型不存在: {model_path}")

    model = YOLO(str(model_path))

    export_kwargs = {
        "format": args.format,
        "imgsz": args.imgsz,
        "half": args.half,
        "int8": args.int8,
        "workspace": args.workspace,
    }

    if args.format == "onnx":
        export_kwargs["dynamic"] = args.dynamic
        export_kwargs["simplify"] = args.simplify
        export_kwargs["opset"] = args.opset

    print(f"正在导出模型到 {args.format} 格式...")
    export_path = model.export(**export_kwargs)

    print(f"\n导出成功: {export_path}")


if __name__ == "__main__":
    main()