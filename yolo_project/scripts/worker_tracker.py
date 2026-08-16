#!/usr/bin/env python3
"""
智慧工地 - GPS 定位模拟器
模拟工人手机 GPS 位置上报，用于测试电子栅栏和工人追踪系统

支持模式:
  - random_walk: 随机游走 (在工地内/外随机移动)
  - daily_routine: 模拟日常作息 (上班进入→工作→午休→下班离开)
  - static: 固定位置
  - replay: 回放预设轨迹
"""

import argparse
import json
import math
import os
import random
import sys
import time
from pathlib import Path
from datetime import datetime, timedelta
from threading import Thread

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from utils.positioning import (
    WorkerTracker, haversine_distance, point_in_polygon
)


class GPSSimulator:
    """GPS 模拟器 - 模拟工人手机定位数据"""

    def __init__(self,
                 workers_config="configs/workers.json",
                 geofence_config="configs/site_geofence.json"):
        self.tracker = WorkerTracker(workers_config, geofence_config)
        self.site_center = self.tracker.geofence.site_center
        self.site_boundary = self.tracker.geofence.site_boundary

        # 工地边界范围
        lats = [p[0] for p in self.site_boundary]
        lons = [p[1] for p in self.site_boundary]
        self.lat_range = (min(lats), max(lats))
        self.lon_range = (min(lons), max(lons))

        # 工人状态
        self.worker_positions = {}  # phone -> (lat, lon)
        self.worker_velocities = {}  # phone -> (v_lat, v_lon)
        self.running = False

    def _init_worker_position(self, phone, mode="random"):
        """初始化工人位置"""
        worker = self.tracker.get_worker_by_phone(phone)
        if not worker:
            return

        if mode == "onsite":
            # 在工地内随机位置
            while True:
                lat = random.uniform(*self.lat_range)
                lon = random.uniform(*self.lon_range)
                if point_in_polygon(lat, lon, self.site_boundary):
                    break
        elif mode == "offsite":
            # 在工地外 500m-1000m
            angle = random.uniform(0, 2 * math.pi)
            dist = random.uniform(500, 1000)
            lat_offset = (dist / 111320) * math.cos(angle)
            lon_offset = (dist / (111320 * math.cos(
                math.radians(self.site_center[0])))) * math.sin(angle)
            lat = self.site_center[0] + lat_offset
            lon = self.site_center[1] + lon_offset
        else:
            lat = random.uniform(*self.lat_range)
            lon = random.uniform(*self.lon_range)

        self.worker_positions[phone] = (lat, lon)
        self.worker_velocities[phone] = (
            random.uniform(-0.00003, 0.00003),
            random.uniform(-0.00003, 0.00003),
        )

    def random_walk(self, phone, step_size=0.00005, stay_onsite=True):
        """
        随机游走模式

        Args:
            phone: 手机号
            step_size: 每步移动量 (度)
            stay_onsite: 是否约束在工地内
        """
        lat, lon = self.worker_positions[phone]
        v_lat, v_lon = self.worker_velocities[phone]

        # 随机改变方向
        v_lat += random.uniform(-0.00001, 0.00001)
        v_lon += random.uniform(-0.00001, 0.00001)

        # 限速
        v_lat = max(-0.00005, min(0.00005, v_lat))
        v_lon = max(-0.00005, min(0.00005, v_lon))

        new_lat = lat + v_lat
        new_lon = lon + v_lon

        if stay_onsite:
            # 边界反弹
            if not point_in_polygon(new_lat, new_lon, self.site_boundary):
                v_lat = -v_lat
                v_lon = -v_lon
                new_lat = lat + v_lat
                new_lon = lon + v_lon

        self.worker_positions[phone] = (new_lat, new_lon)
        self.worker_velocities[phone] = (v_lat, v_lon)

        return new_lat, new_lon

    def daily_routine(self, phone, sim_time: datetime):
        """
        模拟日常作息

        08:00 前: 在工地外
        08:00: 进入工地
        08:00-12:00: 在工作区
        12:00-13:00: 去办公区/休息
        13:00-17:00: 返回工作区
        17:00: 离开工地
        """
        hour = sim_time.hour + sim_time.minute / 60
        center = self.site_center

        if hour < 7.5:
            # 在家
            return (center[0] + 0.015, center[1] + 0.015)
        elif hour < 8.0:
            # 通勤中
            progress = (hour - 7.5) / 0.5
            return (
                center[0] + 0.015 * (1 - progress),
                center[1] + 0.015 * (1 - progress),
            )
        elif hour < 12.0:
            # 工作中 - 在工作区随机微动
            lat = center[0] + random.uniform(-0.001, 0.001)
            lon = center[1] + random.uniform(-0.001, 0.001)
            return (lat, lon)
        elif hour < 13.0:
            # 午休
            lat = center[0] + 0.0002 + random.uniform(-0.0002, 0.0002)
            lon = center[1] + 0.0002 + random.uniform(-0.0002, 0.0002)
            return (lat, lon)
        elif hour < 17.0:
            # 下午工作
            lat = center[0] + random.uniform(-0.001, 0.001)
            lon = center[1] + random.uniform(-0.001, 0.001)
            return (lat, lon)
        elif hour < 17.5:
            # 下班通勤
            progress = (hour - 17.0) / 0.5
            return (
                center[0] + 0.015 * progress,
                center[1] + 0.015 * progress,
            )
        else:
            return (center[0] + 0.015, center[1] + 0.015)

    def run(self, mode="random_walk", interval=5, duration=0,
            sim_speed=1, verbose=True):
        """
        运行模拟器

        Args:
            mode: 模拟模式
            interval: 定位上报间隔 (秒)
            duration: 运行时长 (秒), 0 = 无限
            sim_speed: 时间加速倍数 (daily_routine 模式)
            verbose: 是否打印日志
        """
        self.running = True
        phones = self.tracker.get_all_phones()

        # 初始化位置
        for phone in phones:
            if mode == "daily_routine":
                self._init_worker_position(phone, "offsite")
            else:
                self._init_worker_position(phone, "onsite")

        print(f"GPS 模拟器启动: {len(phones)} 个工人, 模式={mode}, 间隔={interval}s")
        print(f"工地中心: {self.site_center}")
        print("-" * 60)

        start_time = time.time()
        sim_start = datetime.now().replace(
            hour=7, minute=0, second=0, microsecond=0
        )
        update_count = 0

        try:
            while self.running:
                now = time.time()
                if duration > 0 and now - start_time > duration:
                    break

                sim_time = sim_start + timedelta(
                    seconds=(now - start_time) * sim_speed
                )

                for phone in phones:
                    if mode == "daily_routine":
                        lat, lon = self.daily_routine(phone, sim_time)
                    else:
                        lat, lon = self.random_walk(phone)

                    status = self.tracker.update_location(
                        phone, lat, lon,
                        accuracy=random.uniform(3, 15),
                        speed=random.uniform(0, 2),
                        battery=random.randint(60, 100),
                    )

                update_count += 1

                if verbose and update_count % 10 == 0:
                    stats = self.tracker.get_team_stats()
                    sim_str = sim_time.strftime("%H:%M")
                    print(f"[{sim_str}] 在场: {stats['on_site']}/{stats['total_workers']}"
                          f" | 更新: {update_count}")

                time.sleep(interval)

        except KeyboardInterrupt:
            print("\n模拟器已停止")

        self.running = False
        self._print_final_stats()

    def _print_final_stats(self):
        """打印最终统计"""
        stats = self.tracker.get_team_stats()
        print(f"\n{'='*60}")
        print(f"模拟结束 - 最终统计")
        print(f"{'='*60}")
        print(f"总工人: {stats['total_workers']} | "
              f"在场: {stats['on_site']} | 离场: {stats['off_site']}")
        print(f"\n各班详情:")
        for team_name, team_data in stats["teams"].items():
            print(f"  [{team_name}] {team_data.get('type', '')}")
            print(f"    组长: {team_data.get('leader', 'N/A')}")
            print(f"    在场: {team_data['on_site']}/{team_data['total']}")
            for w in team_data["workers"]:
                status_icon = "●" if w["on_site"] else "○"
                danger_icon = "⚠" if w["in_danger"] else " "
                print(f"    {status_icon} {danger_icon} {w['name']} "
                      f"({w['role']}) - {w['zone'] or '未定位'} "
                      f"| {w['on_site_duration']}")


def main():
    parser = argparse.ArgumentParser(description="智慧工地 - GPS 定位模拟器")
    parser.add_argument("--mode", type=str, default="random_walk",
                        choices=["random_walk", "daily_routine", "static"],
                        help="模拟模式")
    parser.add_argument("--interval", type=int, default=5,
                        help="定位上报间隔 (秒)")
    parser.add_argument("--duration", type=int, default=0,
                        help="运行时长 (秒), 0=无限")
    parser.add_argument("--sim-speed", type=int, default=60,
                        help="时间加速倍数 (daily_routine 模式)")
    parser.add_argument("--quiet", action="store_true",
                        help="静默模式")
    parser.add_argument("--workers-config", type=str,
                        default="configs/workers.json",
                        help="工人配置文件")
    parser.add_argument("--geofence-config", type=str,
                        default="configs/site_geofence.json",
                        help="电子栅栏配置文件")

    args = parser.parse_args()

    sim = GPSSimulator(
        workers_config=args.workers_config,
        geofence_config=args.geofence_config,
    )

    sim.run(
        mode=args.mode,
        interval=args.interval,
        duration=args.duration,
        sim_speed=args.sim_speed,
        verbose=not args.quiet,
    )


if __name__ == "__main__":
    main()