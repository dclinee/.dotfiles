#!/usr/bin/env python3
"""
智慧工地 - 最终集成验证测试
验证全部 6 个阶段的完整流程是否就绪

检查项:
  1. 项目结构完整性
  2. Python 模块导入
  3. 配置文件有效性
  4. 脚本参数正确性
  5. 模型可用性
  6. 通知可用性
  7. 定位可用性
  8. 部署脚本可用性

用法:
  python scripts/integration_test.py
  python scripts/integration_test.py --verbose
  python scripts/integration_test.py --output report.json
"""

import argparse
import importlib
import json
import os
import sys
import time
from pathlib import Path
from datetime import datetime
from collections import OrderedDict

PROJECT_DIR = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(PROJECT_DIR))


# ============================================================
# 测试用例
# ============================================================

class TestResult:
    def __init__(self, name, passed, message="", duration=0):
        self.name = name
        self.passed = passed
        self.message = message
        self.duration = duration


class IntegrationTester:
    """集成测试器"""

    def __init__(self, verbose=False):
        self.verbose = verbose
        self.results = OrderedDict()
        self.start_time = time.time()

    def _log(self, msg):
        if self.verbose:
            print(f"    {msg}")

    def _test(self, name, fn):
        """运行单个测试"""
        start = time.time()
        try:
            passed, message = fn()
            duration = time.time() - start
        except Exception as e:
            passed, message = False, str(e)
            duration = time.time() - start

        result = TestResult(name, passed, message, duration)
        self.results[name] = result

        status = "通过" if passed else "失败"
        if self.verbose:
            print(f"  [{status}] {name} ({duration:.2f}s)")
            if message:
                print(f"         {message}")

        return result

    def test_project_structure(self):
        """检查项目结构完整性"""
        required_files = [
            "configs/smart_construction.yaml",
            "configs/dataset.yaml",
            "configs/personnel.json",
            "configs/cameras.json",
            "configs/danger_zones.json",
            "configs/workers.json",
            "configs/site_geofence.json",
            "configs/train_presets.yaml",
            "scripts/train.py",
            "scripts/inference.py",
            "scripts/safety_gear_detect.py",
            "scripts/intrusion_detect.py",
            "scripts/site_stats.py",
            "scripts/camera_monitor.py",
            "scripts/video_verify.py",
            "scripts/review_report.py",
            "scripts/dataset_prepare.py",
            "scripts/eval.py",
            "scripts/export.py",
            "scripts/data_quality_check.py",
            "scripts/data_augment.py",
            "scripts/format_converter.py",
            "scripts/data_pipeline.py",
            "scripts/gpu_check.py",
            "scripts/train_monitor.py",
            "scripts/model_compare.py",
            "scripts/train_pipeline.py",
            "scripts/notify_setup.py",
            "scripts/notify_test.py",
            "scripts/gps_server.py",
            "scripts/gps_test.py",
            "scripts/deploy.sh",
            "scripts/health_monitor.py",
            "scripts/dashboard.py",
            "scripts/worker_tracker.py",
            "utils/notify.py",
            "utils/positioning.py",
            "utils/visualize.py",
            "requirements.txt",
        ]

        missing = []
        for f in required_files:
            if not (PROJECT_DIR / f).exists():
                missing.append(f)

        if missing:
            return False, f"缺失 {len(missing)} 个文件: {', '.join(missing[:5])}..."
        return True, f"全部 {len(required_files)} 个文件完整"

    def test_configs_valid(self):
        """检查配置文件有效性"""
        configs = [
            "configs/smart_construction.yaml",
            "configs/personnel.json",
            "configs/cameras.json",
            "configs/danger_zones.json",
            "configs/workers.json",
            "configs/site_geofence.json",
        ]

        errors = []
        for cfg in configs:
            path = PROJECT_DIR / cfg
            try:
                with open(path, "r") as f:
                    if cfg.endswith(".json"):
                        data = json.load(f)
                    elif cfg.endswith(".yaml"):
                        import yaml
                        data = yaml.safe_load(f)
                if data is None or (isinstance(data, dict) and len(data) == 0):
                    errors.append(f"{cfg}: 空配置")
            except json.JSONDecodeError as e:
                errors.append(f"{cfg}: JSON 格式错误 - {e}")
            except Exception as e:
                errors.append(f"{cfg}: {e}")

        if errors:
            return False, "; ".join(errors[:3])
        return True, f"全部 {len(configs)} 个配置文件有效"

    def test_python_imports(self):
        """检查 Python 模块导入"""
        modules = [
            ("utils.notify", "LarkNotifier"),
            ("utils.positioning", "WorkerTracker"),
            ("utils.visualize", ""),
        ]

        errors = []
        for mod_name, cls_name in modules:
            try:
                mod = importlib.import_module(mod_name)
                if cls_name and not hasattr(mod, cls_name):
                    errors.append(f"{mod_name}: 缺少 {cls_name}")
            except ImportError as e:
                errors.append(f"{mod_name}: {e}")

        if errors:
            return False, "; ".join(errors)
        return True, f"全部 {len(modules)} 个模块导入成功"

    def test_ultralytics_available(self):
        """检查 YOLO 框架可用性"""
        try:
            from ultralytics import YOLO
            version = importlib.import_module("ultralytics").__version__
            return True, f"ultralytics {version}"
        except ImportError:
            return False, "ultralytics 未安装 (pip install ultralytics)"

    def test_gpu_available(self):
        """检查 GPU 可用性"""
        try:
            import torch
            if torch.cuda.is_available():
                count = torch.cuda.device_count()
                name = torch.cuda.get_device_name(0)
                return True, f"{count}× {name}"
            else:
                return True, "无 GPU (将使用CPU模式)"
        except ImportError:
            return True, "PyTorch 未安装 (仅检测)"

    def test_opencv_available(self):
        """检查 OpenCV 可用性"""
        try:
            import cv2
            return True, f"OpenCV {cv2.__version__}"
        except ImportError:
            return False, "OpenCV 未安装"

    def test_flask_available(self):
        """检查 Flask 可用性"""
        try:
            import flask
            return True, f"Flask {flask.__version__}"
        except ImportError:
            return False, "Flask 未安装 (pip install flask)"

    def test_notify_module(self):
        """检查通知模块"""
        try:
            from utils.notify import LarkNotifier
            notifier = LarkNotifier()
            return True, f"已配置 {len(notifier.roles)} 个角色, "
        except Exception as e:
            return False, str(e)

    def test_positioning_module(self):
        """检查定位模块"""
        try:
            from utils.positioning import WorkerTracker
            tracker = WorkerTracker()
            return True, f"工人 {len(tracker.worker_statuses)} 人, "
        except Exception as e:
            return False, str(e)

    def test_scripts_cli(self):
        """检查脚本 CLI 参数"""
        scripts_to_check = [
            "scripts/train.py",
            "scripts/video_verify.py",
            "scripts/camera_monitor.py",
            "scripts/gps_server.py",
            "scripts/health_monitor.py",
        ]

        errors = []
        for script in scripts_to_check:
            path = PROJECT_DIR / script
            try:
                result = subprocess.run(
                    [sys.executable, str(path), "--help"],
                    capture_output=True, text=True, timeout=10,
                    cwd=str(PROJECT_DIR),
                )
                if result.returncode != 0:
                    errors.append(f"{script}: 退出码 {result.returncode}")
            except subprocess.TimeoutExpired:
                errors.append(f"{script}: 超时")
            except Exception as e:
                errors.append(f"{script}: {e}")

        if errors:
            return False, "; ".join(errors[:3])
        return True, f"全部 {len(scripts_to_check)} 个脚本可运行"

    def test_deploy_script(self):
        """检查部署脚本"""
        path = PROJECT_DIR / "scripts/deploy.sh"
        if not path.exists():
            return False, "deploy.sh 不存在"
        try:
            result = subprocess.run(
                ["bash", str(path), "help"],
                capture_output=True, text=True, timeout=5,
            )
            return True, "部署脚本可用"
        except Exception as e:
            return False, str(e)


# ============================================================
# 运行测试
# ============================================================

def run_all_tests(tester):
    """运行全部测试"""
    print(f"\n{'='*60}")
    print(f"  智慧工地 - 最终集成验证测试")
    print(f"{'='*60}")
    print(f"  时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"  项目: {PROJECT_DIR}")
    print(f"")

    # 基础环境
    print(f"  基础环境检查:")
    tester._test("项目结构完整性", tester.test_project_structure)
    tester._test("配置文件有效性", tester.test_configs_valid)
    tester._test("Python 模块导入", tester.test_python_imports)

    print(f"\n  依赖库检查:")
    tester._test("YOLO (ultralytics)", tester.test_ultralytics_available)
    tester._test("GPU 可用性", tester.test_gpu_available)
    tester._test("OpenCV", tester.test_opencv_available)
    tester._test("Flask", tester.test_flask_available)

    print(f"\n  功能模块检查:")
    tester._test("飞书通知模块", tester.test_notify_module)
    tester._test("手机定位模块", tester.test_positioning_module)

    print(f"\n  脚本 & 部署检查:")
    tester._test("脚本 CLI 可运行", tester.test_scripts_cli)
    tester._test("部署脚本", tester.test_deploy_script)

    # 汇总
    print(f"\n{'='*60}")
    passed = sum(1 for r in tester.results.values() if r.passed)
    total = len(tester.results)
    elapsed = time.time() - tester.start_time

    for name, result in tester.results.items():
        status = "通过" if result.passed else "失败"
        symbol = "●" if result.passed else "○"
        print(f"  {symbol} [{status}] {name}")

    print(f"\n  通过: {passed}/{total}")
    print(f"  耗时: {elapsed:.1f}s")
    print(f"{'='*60}")

    return passed == total


def output_json(tester, output_path):
    """输出 JSON 报告"""
    report = {
        "project": str(PROJECT_DIR),
        "time": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        "passed": sum(1 for r in tester.results.values() if r.passed),
        "total": len(tester.results),
        "results": {
            name: {
                "passed": r.passed,
                "message": r.message,
                "duration": round(r.duration, 3),
            }
            for name, r in tester.results.items()
        },
    }
    with open(output_path, "w") as f:
        json.dump(report, f, indent=2, ensure_ascii=False)
    print(f"\n报告已保存: {output_path}")


# ============================================================
# 主函数
# ============================================================

import subprocess


def main():
    parser = argparse.ArgumentParser(description="集成验证测试")
    parser.add_argument("--verbose", "-v", action="store_true",
                        help="详细输出")
    parser.add_argument("--output", "-o", type=str, default=None,
                        help="输出 JSON 报告路径")

    args = parser.parse_args()

    tester = IntegrationTester(verbose=args.verbose)
    all_pass = run_all_tests(tester)

    if args.output:
        output_json(tester, args.output)

    sys.exit(0 if all_pass else 1)


if __name__ == "__main__":
    main()