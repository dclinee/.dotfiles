"""
智慧工地 - 统一日志系统
基于 logging 模块, 提供规范的日志接口

用法:
  from utils.logger import get_logger

  logger = get_logger("module_name")
  logger.info("正常信息")
  logger.warning("警告信息")
  logger.error("错误信息")
  logger.debug("调试信息")

日志输出:
  - 控制台: INFO 级别及以上
  - 文件: runs/logs/app.log (DEBUG 级别)
  - 文件: runs/logs/alarm.log (仅告警)
  - 自动轮转: 每 10MB / 保留 5 个备份
"""

import logging
import logging.handlers
import sys
from pathlib import Path
from datetime import datetime
from typing import Optional


# 日志目录
LOG_DIR = Path("runs/logs")

# 日志格式
CONSOLE_FORMAT = "%(asctime)s [%(levelname)s] %(name)s: %(message)s"
FILE_FORMAT = "%(asctime)s [%(levelname)-7s] %(name)-15s | %(message)s"
DATE_FORMAT = "%Y-%m-%d %H:%M:%S"

# 是否已初始化
_initialized = False


def _init_logging():
    """初始化全局日志配置 (仅执行一次)"""
    global _initialized
    if _initialized:
        return
    _initialized = True

    LOG_DIR.mkdir(parents=True, exist_ok=True)

    # 根 logger
    root = logging.getLogger()
    root.setLevel(logging.DEBUG)

    # 控制台 handler (INFO 及以上)
    console = logging.StreamHandler(sys.stdout)
    console.setLevel(logging.INFO)
    console.setFormatter(logging.Formatter(CONSOLE_FORMAT, DATE_FORMAT))
    root.addHandler(console)

    # 文件 handler (所有级别)
    app_file = logging.handlers.RotatingFileHandler(
        LOG_DIR / "app.log",
        maxBytes=10 * 1024 * 1024,  # 10MB
        backupCount=5,
        encoding="utf-8",
    )
    app_file.setLevel(logging.DEBUG)
    app_file.setFormatter(logging.Formatter(FILE_FORMAT, DATE_FORMAT))
    root.addHandler(app_file)

    # 告警专用 handler
    alarm_file = logging.handlers.RotatingFileHandler(
        LOG_DIR / "alarm.log",
        maxBytes=5 * 1024 * 1024,
        backupCount=3,
        encoding="utf-8",
    )
    alarm_file.setLevel(logging.WARNING)
    alarm_file.setFormatter(logging.Formatter(FILE_FORMAT, DATE_FORMAT))
    root.addHandler(alarm_file)


def get_logger(name: str) -> logging.Logger:
    """
    获取模块日志器

    Args:
        name: 模块名 (如 "camera_monitor", "gps_server")

    Returns:
        logging.Logger 实例
    """
    _init_logging()
    logger = logging.getLogger(name)
    if not logger.handlers:
        # 确保每个 logger 有 handler (避免重复)
        pass  # 已由根 logger handler 处理
    return logger


def set_level(level: str):
    """
    设置日志级别

    Args:
        level: "DEBUG" / "INFO" / "WARNING" / "ERROR"
    """
    _init_logging()
    lvl = getattr(logging, level.upper(), logging.INFO)
    for handler in logging.getLogger().handlers:
        if isinstance(handler, logging.StreamHandler):
            handler.setLevel(lvl)


def get_log_file_path(log_type: str = "app") -> Path:
    """获取日志文件路径"""
    return LOG_DIR / f"{log_type}.log"


class AlarmLogger:
    """告警专用日志器"""

    def __init__(self):
        self.logger = get_logger("alarm")

    def log_alert(self, alarm_type: str, camera_id: str,
                  details: dict = None, level: str = "warning"):
        """记录告警"""
        msg = f"[{camera_id}] {alarm_type}"
        if details:
            msg += f" | {details}"
        getattr(self.logger, level)(msg)

    def log_violation(self, violation_type: str, count: int,
                      camera_id: str, frame: int = 0):
        """记录违规"""
        self.logger.warning(
            f"[{camera_id}] 违规: {violation_type} x{count} "
            f"(frame={frame})"
        )

    def log_intrusion(self, zone_name: str, camera_id: str,
                      frame: int = 0):
        """记录入侵"""
        self.logger.warning(
            f"[{camera_id}] 入侵: {zone_name} (frame={frame})"
        )

    def log_compliance(self, helmet_rate: float, vest_rate: float,
                       camera_id: str = ""):
        """记录合规率"""
        label = f"[{camera_id}] " if camera_id else ""
        level = "warning" if helmet_rate < 80 or vest_rate < 80 else "info"
        self.logger.log(
            getattr(logging, level.upper()),
            f"{label}合规率: 安全帽={helmet_rate:.1f}%, 反光衣={vest_rate:.1f}%"
        )