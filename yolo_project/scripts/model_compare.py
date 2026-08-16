#!/usr/bin/env python3
"""
模型对比评测
训练多个模型后, 横向对比精度/速度/模型大小, 选出最佳模型
"""

import argparse
import json
import os
import sys
import time
from pathlib import Path
from collections import defaultdict

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))


class ModelComparator:
    """模型对比评测器"""

    def __init__(self, model_paths, data_config="configs/smart_construction.yaml"):
        self.model_paths = [Path(p) for p in model_paths]
        self.data_config = data_config
        self.results = []

    def evaluate_all(self):
        """评估所有模型"""
        from ultralytics import YOLO

        print(f"对比 {len(self.model_paths)} 个模型\n")

        for mp in self.model_paths:
            if not mp.exists():
                print(f"  [跳过] 文件不存在: {mp}")
                continue

            print(f"  评估: {mp.name}")
            model = YOLO(str(mp))

            # 验证集评估
            val_results = model.val(
                data=self.data_config,
                split="val",
                verbose=False,
            )

            # 推理速度测试
            speed_info = self._benchmark_speed(model)

            # 模型大小
            size_mb = mp.stat().st_size / (1024 * 1024)

            self.results.append({
                "name": mp.name,
                "path": str(mp),
                "size_mb": round(size_mb, 2),
                "mAP50": round(val_results.box.map50, 4),
                "mAP50_95": round(val_results.box.map, 4),
                "precision": round(val_results.box.mp, 4),
                "recall": round(val_results.box.mr, 4),
                "inference_ms": round(speed_info.get("avg_ms", 0), 2),
                "fps": round(speed_info.get("fps", 0), 1),
            })

            print(f"    mAP@50={self.results[-1]['mAP50']:.4f} "
                  f"mAP@50-95={self.results[-1]['mAP50_95']:.4f} "
                  f"FPS={self.results[-1]['fps']:.1f} "
                  f"大小={self.results[-1]['size_mb']:.1f}MB")

    def _benchmark_speed(self, model):
        """测试推理速度"""
        try:
            # 预热
            results = model.predict(
                source="ultralytics/assets/bus.jpg",
                verbose=False,
            )

            # 计时
            times = []
            for _ in range(50):
                t0 = time.time()
                results = model.predict(
                    source="ultralytics/assets/bus.jpg",
                    verbose=False,
                    imgsz=640,
                )
                times.append((time.time() - t0) * 1000)

            avg_ms = sum(times) / len(times)
            return {"avg_ms": avg_ms, "fps": 1000 / avg_ms}
        except Exception:
            return {"avg_ms": 0, "fps": 0}

    def print_comparison(self):
        """打印对比结果"""
        if not self.results:
            print("无评估结果")
            return

        print("\n" + "=" * 80)
        print("  模型对比评测")
        print("=" * 80)

        # 表头
        header = (f"  {'模型':25s} {'大小':>8s} {'mAP@50':>10s} "
                  f"{'mAP@50-95':>10s} {'Precision':>10s} {'Recall':>10s} "
                  f"{'FPS':>8s} {'推理ms':>8s}")
        print(header)
        print("-" * 80)

        for r in sorted(self.results, key=lambda x: x["mAP50_95"], reverse=True):
            print(f"  {r['name']:25s} {r['size_mb']:>6.1f}MB "
                  f"{r['mAP50']:>10.4f} {r['mAP50_95']:>10.4f} "
                  f"{r['precision']:>10.4f} {r['recall']:>10.4f} "
                  f"{r['fps']:>8.1f} {r['inference_ms']:>6.1f}ms")

        print("=" * 80)

        # 选出最佳
        best_map = max(self.results, key=lambda x: x["mAP50_95"])
        best_fps = max(self.results, key=lambda x: x["fps"])
        best_balanced = max(self.results,
                            key=lambda x: x["mAP50_95"] * x["fps"])

        print(f"\n  推荐:")
        print(f"    最高精度: {best_map['name']} (mAP@50-95={best_map['mAP50_95']:.4f})")
        print(f"    最快推理: {best_fps['name']} (FPS={best_fps['fps']:.1f})")
        print(f"    最佳平衡: {best_balanced['name']} "
              f"(精度×速度={best_balanced['mAP50_95'] * best_balanced['fps']:.1f})")

    def save_json(self, path="model_comparison.json"):
        """保存 JSON"""
        with open(path, "w") as f:
            json.dump(self.results, f, indent=2, ensure_ascii=False)
        print(f"\n结果已保存: {path}")


def main():
    parser = argparse.ArgumentParser(description="模型对比评测")
    parser.add_argument("--models", type=str, nargs="+", required=True,
                        help="模型权重路径列表")
    parser.add_argument("--data", type=str, default="configs/smart_construction.yaml",
                        help="数据集配置")
    parser.add_argument("--save", type=str, default=None,
                        help="保存 JSON 路径")

    args = parser.parse_args()

    comparator = ModelComparator(args.models, args.data)
    comparator.evaluate_all()
    comparator.print_comparison()

    if args.save:
        comparator.save_json(args.save)


if __name__ == "__main__":
    main()