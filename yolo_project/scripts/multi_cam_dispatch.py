# -*- coding: utf-8 -*-
"""
scripts/multi_cam_dispatch.py — 多路摄像头调度 & 自动重启 supervisor

用法:
  python scripts/multi_cam_dispatch.py --cameras configs/cameras.json \
      --db runs/data/site.db --python-path .
  # 单路调试
  python scripts/multi_cam_dispatch.py --only cam_entrance --cameras configs/cameras.json

机制:
  - 读 JSON 配置, 对每个 camera 启动一路 `python scripts/video_verify.py ...` 子进程
  - 对每路独立写 log 到 runs/logs/cam_xxx.log
  - 监控子进程: 退出码非 0 时按指数退避 (min_backoff, min*2, ... max_backoff) 重启
  - 主进程收到 SIGINT/SIGTERM 时, SIGTERM 所有子进程并等待退出
"""

from __future__ import annotations

import argparse
import json
import logging
import os
import signal
import subprocess
import sys
import threading
import time
from dataclasses import dataclass, field
from pathlib import Path
from typing import Dict, List, Optional


@dataclass
class WorkerState:
    cam_id: str
    cmd: List[str]
    log_path: Path
    record_dir: Path
    min_backoff: float = 5.0
    max_backoff: float = 300.0
    max_restart: int = 1000
    proc: Optional[subprocess.Popen] = None
    retries: int = 0
    current_backoff: float = 0
    next_retry_at: float = 0.0
    last_exit_code: Optional[int] = None
    last_started_at: float = 0.0
    stop_requested: bool = False
    lock: threading.Lock = field(default_factory=threading.Lock)


logger = logging.getLogger("multi_cam")


# =========================================================================
# 1) 配置 → 每路 worker 的命令行
# =========================================================================
def build_command(cam: dict, project_root: Path, db_path: Path) -> list:
    python = sys.executable
    script = str(project_root / "scripts" / "video_verify.py")
    model = cam.get("model") or "runs/syn_train/syn_exp1/weights/best.pt"
    source = cam.get("source")
    if not source:
        raise ValueError(f"camera {cam.get('id')} 缺少 source 字段")
    zone_config = cam.get("zone_config") or "configs/site_geofence.json"
    alarms = cam.get("alarms") or {}
    show = bool(cam.get("show_window", False))
    record = bool(cam.get("record_video", False))

    cmd = [python, script,
           "--source", str(source),
           "--model", str(model),
           "--zones", str(zone_config),
           "--camera-id", str(cam.get("id")),
           "--device", str(cam.get("device", "cpu")),
           "--conf", str(cam.get("conf", 0.35)),
           "--mode", "all",
           "--output", f"runs/video_verify/{cam.get('id')}",
           "--skip-frames", str(cam.get("frame_interval", 2)),
           "--storage",
           "--db", str(db_path),
           ]
    try:
        float(cam.get("iou", 0.45))
        # video_verify 暂未暴露 iou CLI; 保留到将来, 不报错
    except Exception:
        pass
    if not show:
        cmd.append("--no-display")
    if not record:
        cmd.append("--no-video")
    if alarms.get("notify_lark", False):
        cmd.append("--notify")
    if alarms.get("personnel_config"):
        cmd += ["--personnel-config", alarms["personnel_config"]]
    if alarms.get("alarm_cooldown_seconds"):
        # 复用 video_verify 现有 ALERT_COOLDOWN 环境变量传递
        pass
    return cmd


# =========================================================================
# 2) Worker 启停/重启循环
# =========================================================================
def worker_loop(state: WorkerState):
    state.log_path.parent.mkdir(parents=True, exist_ok=True)
    state.record_dir.mkdir(parents=True, exist_ok=True)
    while not state.stop_requested:
        # 退避等待
        now_ts = time.time()
        if state.next_retry_at > now_ts:
            time.sleep(min(1.0, state.next_retry_at - now_ts))
            continue
        if state.stop_requested:
            break
        # 超过最大重启次数? 挂起, 不再重启
        if state.retries >= state.max_restart:
            logger.error("[%s] 已达到最大重启次数 %d, 本路停摆 (人工介入)",
                         state.cam_id, state.max_restart)
            time.sleep(10)
            continue

        # 启动子进程 (日志写到单独文件)
        logger.info("[%s] 启动: %s", state.cam_id, " ".join(state.cmd))
        state.last_started_at = time.time()
        state.retries += 1
        try:
            log_fp = open(state.log_path, "ab")
        except OSError as e:
            logger.exception("[%s] 打开日志失败: %s", state.cam_id, e)
            time.sleep(5)
            continue

        try:
            with state.lock:
                if state.stop_requested:
                    log_fp.close()
                    break
                state.proc = subprocess.Popen(
                    state.cmd, stdout=log_fp, stderr=subprocess.STDOUT,
                    cwd=str(Path.cwd()),
                    env={**os.environ,
                         "PYTHONUNBUFFERED": "1",
                         "ALERT_COOLDOWN_DEFAULT": "30"},
                    preexec_fn=os.setsid if hasattr(os, "setsid") else None,
                )
                pid = state.proc.pid
        except Exception as e:
            logger.exception("[%s] 子进程启动失败: %s", state.cam_id, e)
            log_fp.close()
            state.last_exit_code = -1
            _bump_backoff(state)
            continue

        logger.info("[%s] pid=%d  log=%s", state.cam_id, pid, state.log_path)
        # 等待退出 (阻塞)
        try:
            code = state.proc.wait()
        finally:
            log_fp.close()
            with state.lock:
                state.proc = None
        state.last_exit_code = code
        if state.stop_requested:
            logger.info("[%s] 子进程 %d 已退出 (code=%s), 结束本路",
                        state.cam_id, pid, code)
            break
        if code == 0:
            # 正常退出 (比如本地视频播放完毕), 直接停止, 不做无限重启死循环
            logger.info("[%s] 子进程正常退出 code=0, 认为任务已结束, 不重启",
                        state.cam_id)
            break
        logger.warning("[%s] 子进程 %d 异常退出 code=%s (第 %d 次异常)  "
                       "%.0fs 后重试",
                       state.cam_id, pid, code, state.retries, state.current_backoff)
        _bump_backoff(state)
    logger.info("[%s] worker_loop 已结束", state.cam_id)


def _bump_backoff(state: WorkerState):
    if state.current_backoff <= 0:
        state.current_backoff = state.min_backoff
    else:
        state.current_backoff = min(state.max_backoff, state.current_backoff * 2)
    state.next_retry_at = time.time() + state.current_backoff


# =========================================================================
# 3) 主进程
# =========================================================================
def _stop_all(states: Dict[str, WorkerState]):
    # 先置标志位, 再 SIGTERM 所有 proc
    running_procs = []
    for s in states.values():
        s.stop_requested = True
        with s.lock:
            if s.proc and s.proc.returncode is None:
                running_procs.append(s.proc)
                try:
                    # Linux 支持 pid/killpg
                    if hasattr(os, "killpg") and s.proc.pid:
                        try: os.killpg(os.getpgid(s.proc.pid), signal.SIGTERM)
                        except Exception: s.proc.terminate()
                    else:
                        s.proc.terminate()
                except Exception as e:
                    logger.debug("terminate 失败 pid=%s: %s", s.proc.pid, e)
    # 等待最多 20s, 硬杀残余
    deadline = time.time() + 20
    while time.time() < deadline and any(p.poll() is None for p in running_procs):
        time.sleep(0.3)
    for p in running_procs:
        if p.poll() is None:
            try: p.kill()
            except Exception: pass
            try: p.wait(timeout=3)
            except Exception: pass


def main():
    ap = argparse.ArgumentParser(description="多路摄像头视频检测调度器 (supervisor)")
    ap.add_argument("--cameras", default="configs/cameras.json", help="摄像头配置 JSON")
    ap.add_argument("--db", default="runs/data/site.db", help="共享 SQLite 路径")
    ap.add_argument("--only", default=None, help="只跑指定 camera_id (调试用)")
    ap.add_argument("--python-path", default=".", help="video_verify.py 的 PYTHONPATH 根")
    ap.add_argument("--log-dir", default="runs/logs", help="每路子进程日志目录")
    ap.add_argument("--record-dir", default="runs/recordings", help="录像根目录")
    ap.add_argument("--verbose", action="store_true")
    args = ap.parse_args()

    logging.basicConfig(
        level=logging.DEBUG if args.verbose else logging.INFO,
        format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    )

    project_root = Path(args.python_path).resolve()
    cameras_cfg = Path(args.cameras)
    if not cameras_cfg.exists():
        raise SystemExit(f"找不到摄像头配置: {cameras_cfg}")
    with open(cameras_cfg, "r", encoding="utf-8") as f:
        cfg = json.load(f)
    cameras = cfg.get("cameras") or []
    if args.only:
        cameras = [c for c in cameras if c.get("id") == args.only]
        if not cameras:
            raise SystemExit(f"--only={args.only} 没匹配到任何摄像头")
    if not cameras:
        raise SystemExit("cameras.json 中 cameras 列表为空")

    db_path = Path(args.db).resolve()
    db_path.parent.mkdir(parents=True, exist_ok=True)
    log_dir = Path(args.log_dir).resolve()
    record_dir_base = Path(args.record_dir).resolve()

    states: Dict[str, WorkerState] = {}
    for cam in cameras:
        cid = str(cam.get("id"))
        cmd = build_command(cam, project_root, db_path)
        state = WorkerState(
            cam_id=cid,
            cmd=cmd,
            log_path=log_dir / f"{cid}.log",
            record_dir=record_dir_base / cid,
        )
        states[cid] = state

    logger.info("调度 %d 路摄像头 → DB=%s", len(states), db_path)
    for cid, s in states.items():
        logger.info("  • %-24s → %s", cid, " ".join(s.cmd[2:5]) + " ...")

    threads = []
    for cid, s in states.items():
        t = threading.Thread(target=worker_loop, args=(s,),
                             name=f"worker-{cid}", daemon=False)
        t.start()
        threads.append(t)

    def sighandler(signum, frame):
        logger.warning("收到信号 %s, 关闭所有子进程...", signum)
        _stop_all(states)

    signal.signal(signal.SIGINT, sighandler)
    signal.signal(signal.SIGTERM, sighandler)
    if hasattr(signal, "SIGHUP"):
        signal.signal(signal.SIGHUP, signal.SIG_IGN)

    try:
        for t in threads:
            t.join()
    finally:
        _stop_all(states)
    logger.info("全部 worker 已结束, 主进程退出.")


if __name__ == "__main__":
    main()
