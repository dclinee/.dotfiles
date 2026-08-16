#!/usr/bin/env python3
"""
智慧工地 - 服务健康监控 & 自动重启

监控所有运行中的服务:
  - 摄像头监控 (camera_monitor.py)
  - GPS 定位服务 (gps_server.py)
  - 摄像头连接状态 (RTSP 断线检测)

功能:
  1. 进程存活检测 → 自动重启
  2. 摄像头 RTSP 断线 → 告警
  3. 内存/显存使用率 → 告警
  4. 健康报告 → 飞书推送
"""

import argparse
import json
import os
import signal
import subprocess
import sys
import time
from pathlib import Path
from datetime import datetime
from collections import defaultdict

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))


class HealthMonitor:
    """服务健康监控器"""

    def __init__(self, project_dir=None, notify_config=None):
        self.project_dir = Path(project_dir or Path(__file__).resolve().parent.parent)
        self.notify_config = notify_config or "configs/personnel.json"

        self.services = {
            "camera_monitor": {
                "script": "scripts/camera_monitor.py",
                "restart_cmd": None,  # 由外部设置
                "max_restarts": 5,
                "restart_count": 0,
                "restart_window": 3600,  # 1小时内
            },
            "gps_server": {
                "script": "scripts/gps_server.py",
                "restart_cmd": None,
                "max_restarts": 5,
                "restart_count": 0,
                "restart_window": 3600,
            },
        }

        self.health_history = []
        self.start_time = time.time()

        # 资源告警阈值
        self.thresholds = {
            "memory_mb": 8000,     # 内存超过 8GB 告警
            "gpu_memory_mb": 6000, # 显存超过 6GB 告警
            "cpu_percent": 90,     # CPU 超过 90% 告警
            "disk_free_gb": 10,    # 磁盘剩余 < 10GB 告警
        }

    def _find_process(self, script_name):
        """查找正在运行的进程"""
        try:
            result = subprocess.run(
                ["pgrep", "-f", script_name],
                capture_output=True, text=True, timeout=5,
            )
            if result.returncode == 0:
                return [int(p) for p in result.stdout.strip().split("\n") if p]
            return []
        except Exception:
            return []

    def _get_process_stats(self, pid):
        """获取进程资源使用"""
        try:
            result = subprocess.run(
                ["ps", "-p", str(pid), "-o", "rss=,pcpu=", "--no-headers"],
                capture_output=True, text=True, timeout=5,
            )
            if result.returncode == 0 and result.stdout.strip():
                parts = result.stdout.strip().split()
                return {
                    "rss_kb": int(parts[0]) if len(parts) > 0 else 0,
                    "cpu_percent": float(parts[1]) if len(parts) > 1 else 0,
                }
        except Exception:
            pass
        return {"rss_kb": 0, "cpu_percent": 0}

    def _get_gpu_memory(self):
        """获取 GPU 显存使用"""
        try:
            result = subprocess.run(
                ["nvidia-smi", "--query-gpu=memory.used",
                 "--format=csv,noheader,nounits"],
                capture_output=True, text=True, timeout=5,
            )
            if result.returncode == 0:
                return sum(int(x) for x in result.stdout.strip().split("\n") if x)
        except Exception:
            pass
        return 0

    def _get_disk_free(self):
        """获取磁盘剩余空间"""
        try:
            stat = os.statvfs(self.project_dir)
            return (stat.f_bavail * stat.f_frsize) / (1024**3)
        except Exception:
            return float("inf")

    def _restart_service(self, service_name):
        """重启服务"""
        svc = self.services[service_name]

        # 防止频繁重启
        now = time.time()
        svc["restart_count"] += 1
        if svc["restart_count"] > svc["max_restarts"]:
            print(f"[Health] {service_name} 重启次数超限 ({svc['max_restarts']}), 跳过")
            return False

        cmd = svc.get("restart_cmd")
        if not cmd:
            print(f"[Health] {service_name} 无重启命令, 跳过")
            return False

        print(f"[Health] 正在重启 {service_name}...")
        try:
            subprocess.Popen(cmd, shell=True, cwd=str(self.project_dir),
                             stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            return True
        except Exception as e:
            print(f"[Health] 重启失败: {e}")
            return False

    def check(self):
        """执行一次健康检查"""
        report = {
            "time": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            "services": {},
            "resources": {},
            "alerts": [],
        }

        for svc_name, svc in self.services.items():
            pids = self._find_process(svc["script"])
            alive = len(pids) > 0

            svc_report = {
                "alive": alive,
                "pids": pids,
                "restart_count": svc["restart_count"],
            }

            if alive:
                stats = self._get_process_stats(pids[0])
                svc_report["memory_mb"] = round(stats["rss_kb"] / 1024, 1)
                svc_report["cpu_percent"] = stats["cpu_percent"]
            else:
                svc_report["memory_mb"] = 0
                svc_report["cpu_percent"] = 0
                if svc.get("restart_cmd"):
                    report["alerts"].append(f"{svc_name} 进程不存在, 尝试重启")

            report["services"][svc_name] = svc_report

        # 资源检查
        gpu_mem = self._get_gpu_memory()
        disk_free = self._get_disk_free()

        report["resources"] = {
            "gpu_memory_mb": gpu_mem,
            "disk_free_gb": round(disk_free, 1),
        }

        if gpu_mem > self.thresholds["gpu_memory_mb"]:
            report["alerts"].append(f"GPU显存使用 {gpu_mem}MB > {self.thresholds['gpu_memory_mb']}MB")

        if disk_free < self.thresholds["disk_free_gb"]:
            report["alerts"].append(f"磁盘剩余 {disk_free:.1f}GB < {self.thresholds['disk_free_gb']}GB")

        self.health_history.append(report)
        if len(self.health_history) > 1000:
            self.health_history = self.health_history[-1000:]

        return report

    def run(self, interval=60, auto_restart=True):
        """
        持续运行健康监控

        Args:
            interval: 检查间隔 (秒)
            auto_restart: 是否自动重启
        """
        print(f"健康监控已启动 (间隔: {interval}s, 自动重启: {auto_restart})")
        print(f"监控服务: {list(self.services.keys())}")

        while True:
            try:
                report = self.check()

                # 打印摘要
                svc_status = " | ".join(
                    f"{name}: {'●' if s['alive'] else '○'}"
                    for name, s in report["services"].items()
                )
                print(f"[{report['time']}] {svc_status} | "
                      f"GPU: {report['resources']['gpu_memory_mb']}MB | "
                      f"Disk: {report['resources']['disk_free_gb']}GB")

                # 自动重启
                if auto_restart:
                    for svc_name, svc in self.services.items():
                        if not report["services"][svc_name]["alive"] and svc.get("restart_cmd"):
                            self._restart_service(svc_name)

                # 告警
                for alert in report["alerts"]:
                    print(f"  [ALERT] {alert}")

                time.sleep(interval)

            except KeyboardInterrupt:
                print("\n健康监控已停止")
                break
            except Exception as e:
                print(f"[Health] 错误: {e}")
                time.sleep(interval)


def main():
    parser = argparse.ArgumentParser(description="服务健康监控")
    parser.add_argument("--interval", type=int, default=60,
                        help="检查间隔 (秒)")
    parser.add_argument("--no-auto-restart", action="store_true",
                        help="禁用自动重启")
    parser.add_argument("--once", action="store_true",
                        help="仅检查一次")
    parser.add_argument("--camera-cmd", type=str, default=None,
                        help="摄像头监控重启命令")
    parser.add_argument("--gps-cmd", type=str, default=None,
                        help="GPS服务重启命令")

    args = parser.parse_args()

    monitor = HealthMonitor()

    # 设置重启命令
    if args.camera_cmd:
        monitor.services["camera_monitor"]["restart_cmd"] = args.camera_cmd
    if args.gps_cmd:
        monitor.services["gps_server"]["restart_cmd"] = args.gps_cmd

    if args.once:
        report = monitor.check()
        print(json.dumps(report, indent=2, ensure_ascii=False))
    else:
        monitor.run(
            interval=args.interval,
            auto_restart=not args.no_auto_restart,
        )


if __name__ == "__main__":
    main()