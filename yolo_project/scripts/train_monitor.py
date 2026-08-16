#!/usr/bin/env python3
"""
训练监控 & 可视化
实时监控训练进度, 检测过拟合, 生成训练报告

功能:
  1. 实时读取 results.csv 监控 loss 和 mAP
  2. 过拟合预警 (train loss 下降但 val loss 上升)
  3. 训练完成后自动生成综合报告
  4. 支持多实验对比
"""

import argparse
import os
import sys
import time
from pathlib import Path
from datetime import datetime
import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))


class TrainingMonitor:
    """训练监控器"""

    def __init__(self, results_dir):
        self.results_dir = Path(results_dir)
        self.csv_path = self.results_dir / "results.csv"
        self.overfit_warnings = []
        self.best_epoch = None

    def watch(self, interval=10):
        """实时监控训练 (在训练过程中运行)"""
        print(f"监控训练: {self.results_dir}")
        print(f"等待 results.csv 生成...")

        # 等待 CSV 文件生成
        while not self.csv_path.exists():
            time.sleep(5)
            print(".", end="", flush=True)

        print("\n训练已开始, 实时监控中...\n")
        last_epoch = -1

        try:
            while True:
                if not self.csv_path.exists():
                    time.sleep(interval)
                    continue

                lines = self._read_csv_lines()
                if len(lines) < 2:
                    time.sleep(interval)
                    continue

                current_epoch = len(lines) - 1
                if current_epoch == last_epoch:
                    time.sleep(interval)
                    continue

                last_epoch = current_epoch

                # 解析最新一行
                metrics = self._parse_line(lines[-1])
                if metrics:
                    self._print_epoch(current_epoch, metrics, lines)

                # 检查过拟合
                if current_epoch > 10:
                    self._check_overfit(lines)

                # 检查是否结束
                if current_epoch >= 200:
                    break

                time.sleep(interval)

        except KeyboardInterrupt:
            print("\n监控已停止")

    def _read_csv_lines(self):
        try:
            with open(self.csv_path, "r") as f:
                return [l.strip() for l in f.readlines() if l.strip()]
        except Exception:
            return []

    def _parse_line(self, line):
        parts = line.split(",")
        if len(parts) < 10:
            return None
        try:
            return {
                "epoch": int(float(parts[0].strip())),
                "train_box": float(parts[1].strip()),
                "train_cls": float(parts[2].strip()),
                "train_dfl": float(parts[3].strip()),
                "val_box": float(parts[5].strip()) if len(parts) > 5 else 0,
                "val_cls": float(parts[6].strip()) if len(parts) > 6 else 0,
                "val_dfl": float(parts[7].strip()) if len(parts) > 7 else 0,
                "mAP50": float(parts[8].strip()) if len(parts) > 8 else 0,
                "mAP50_95": float(parts[9].strip()) if len(parts) > 9 else 0,
            }
        except (ValueError, IndexError):
            return None

    def _print_epoch(self, epoch, metrics, lines):
        """打印当前 epoch 状态"""
        progress = f"Epoch {epoch:3d}"

        # Loss
        loss_str = (f"train_loss: box={metrics['train_box']:.4f} "
                    f"cls={metrics['train_cls']:.4f} "
                    f"dfl={metrics['train_dfl']:.4f}")

        # Val
        val_str = (f"val_loss: box={metrics['val_box']:.4f} "
                   f"cls={metrics['val_cls']:.4f}")

        # mAP
        map_str = (f"mAP@50={metrics['mAP50']:.4f} "
                   f"mAP@50-95={metrics['mAP50_95']:.4f}")

        print(f"  {progress} | {loss_str} | {val_str} | {map_str}")

        # 跟踪最佳 epoch
        if self.best_epoch is None or metrics["mAP50_95"] > self.best_epoch[1]:
            self.best_epoch = (epoch, metrics["mAP50_95"])

    def _check_overfit(self, lines):
        """检测过拟合"""
        if len(lines) < 15:
            return

        # 取最近 10 个 epoch
        recent = lines[-10:]
        train_losses = []
        val_losses = []

        for line in recent:
            m = self._parse_line(line)
            if m:
                train_losses.append(m["train_box"] + m["train_cls"] + m["train_dfl"])
                val_losses.append(m["val_box"] + m["val_cls"] + m["val_dfl"])

        if len(train_losses) < 5:
            return

        # 判断: train loss 下降但 val loss 上升
        train_trend = np.polyfit(range(5), train_losses[-5:], 1)[0]
        val_trend = np.polyfit(range(5), val_losses[-5:], 1)[0]

        if train_trend < -0.001 and val_trend > 0.001:
            epoch = len(lines) - 1
            warning = (f"  过拟合预警 Epoch {epoch}: "
                       f"train_loss↓({train_trend:.4f}) val_loss↑({val_trend:.4f})")
            if warning not in self.overfit_warnings:
                self.overfit_warnings.append(warning)
                print(f"\n  *** {warning} ***\n")
                print(f"  建议: 增大数据增强, 降低学习率, 或增加数据量")

    def generate_report(self, output_path=None):
        """生成训练报告"""
        if not self.csv_path.exists():
            print("未找到 results.csv")
            return

        lines = self._read_csv_lines()
        if len(lines) < 2:
            print("训练数据不足")
            return

        metrics_list = [self._parse_line(l) for l in lines[1:]]
        metrics_list = [m for m in metrics_list if m]

        if not metrics_list:
            return

        best_idx = max(range(len(metrics_list)),
                       key=lambda i: metrics_list[i]["mAP50_95"])
        best = metrics_list[best_idx]

        final = metrics_list[-1]

        report = []
        report.append("=" * 60)
        report.append("  训练报告")
        report.append("=" * 60)
        report.append(f"  总 Epochs: {len(metrics_list)}")
        report.append(f"  最佳 Epoch: {best['epoch']}")
        report.append(f"")
        report.append(f"  最佳 mAP@50:     {best['mAP50']:.4f}")
        report.append(f"  最佳 mAP@50-95:  {best['mAP50_95']:.4f}")
        report.append(f"")
        report.append(f"  最终 Train Loss: {final['train_box']:.4f} "
                      f"(box) {final['train_cls']:.4f} (cls)")
        report.append(f"  最终 Val Loss:   {final['val_box']:.4f} "
                      f"(box) {final['val_cls']:.4f} (cls)")
        report.append(f"")

        # 收敛性
        if metrics_list[-1]["mAP50_95"] > 0.3:
            report.append(f"  模型状态: 已收敛")
        else:
            report.append(f"  模型状态: 可能未充分收敛, 建议增加 epochs")
        report.append("=" * 60)

        report_str = "\n".join(report)
        print(report_str)

        if output_path:
            with open(output_path, "w") as f:
                f.write(report_str)
            print(f"报告已保存: {output_path}")

        return report_str


def compare_experiments(exp_dirs):
    """
    对比多个实验的结果

    Args:
        exp_dirs: 实验目录列表
    """
    print("\n" + "=" * 70)
    print("  多实验对比")
    print("=" * 70)
    print(f"  {'实验':20s} {'mAP@50':>10s} {'mAP@50-95':>10s} "
          f"{'Epochs':>8s} {'Best Epoch':>10s}")
    print("-" * 70)

    for exp_dir in exp_dirs:
        csv_path = Path(exp_dir) / "results.csv"
        if not csv_path.exists():
            print(f"  {Path(exp_dir).name:20s} {'N/A':>10s}")
            continue

        monitor = TrainingMonitor(exp_dir)
        lines = monitor._read_csv_lines()
        metrics_list = [monitor._parse_line(l) for l in lines[1:]]
        metrics_list = [m for m in metrics_list if m]

        if not metrics_list:
            continue

        best_idx = max(range(len(metrics_list)),
                       key=lambda i: metrics_list[i]["mAP50_95"])
        best = metrics_list[best_idx]

        print(f"  {Path(exp_dir).name:20s} "
              f"{best['mAP50']:>10.4f} {best['mAP50_95']:>10.4f} "
              f"{len(metrics_list):>8d} {best['epoch']:>10d}")

    print("=" * 70)


def main():
    parser = argparse.ArgumentParser(description="训练监控 & 报告")
    parser.add_argument("--results", type=str, required=True,
                        help="训练结果目录")
    parser.add_argument("--watch", action="store_true",
                        help="实时监控训练过程")
    parser.add_argument("--report", action="store_true",
                        help="生成训练报告")
    parser.add_argument("--compare", type=str, nargs="+",
                        help="对比多个实验目录")
    parser.add_argument("--interval", type=int, default=10,
                        help="监控间隔 (秒)")

    args = parser.parse_args()

    if args.compare:
        compare_experiments(args.compare)
        return

    monitor = TrainingMonitor(args.results)

    if args.watch:
        monitor.watch(interval=args.interval)

    if args.report:
        report_path = Path(args.results) / "training_report.txt"
        monitor.generate_report(str(report_path))


if __name__ == "__main__":
    main()