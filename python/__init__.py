#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Dotfiles Python Module

This module provides a cross-platform Python development environment for dotfiles.
"""

import os
import sys
from pathlib import Path

# 版本信息
__version__ = '0.1.0'
__author__ = 'dclinee'
__email__ = 'dengchanglin8@outlook.com'
__url__ = 'https://github.com/dclinee/dotfiles'

# 模块路径
MODULE_PATH = Path(__file__).parent

# 配置文件路径
PIP_CONFIG_PATH = MODULE_PATH / 'pip.conf'
PYTHONRC_PATH = MODULE_PATH / 'pythonrc.py'
REQUIREMENTS_PATH = MODULE_PATH / 'requirements.txt'

# 初始化函数
def init():
    """
    初始化Python开发环境
    """
    print(f"初始化Dotfiles Python模块 v{__version__}...")
    print(f"模块路径: {MODULE_PATH}")
    print(f"配置文件路径: {PIP_CONFIG_PATH}")
    print(f"Pythonrc路径: {PYTHONRC_PATH}")
    print(f"依赖文件路径: {REQUIREMENTS_PATH}")
    
    # 检查配置文件是否存在
    for config_file in [PIP_CONFIG_PATH, PYTHONRC_PATH, REQUIREMENTS_PATH]:
        if config_file.exists():
            print(f"✓ {config_file.name} 存在")
        else:
            print(f"✗ {config_file.name} 不存在")

# 加载pythonrc配置
def load_pythonrc():
    """
    加载pythonrc.py配置
    """
    if PYTHONRC_PATH.exists():
        exec(open(PYTHONRC_PATH).read())
    else:
        print(f"警告: {PYTHONRC_PATH} 不存在")

# 获取配置路径
def get_config_path(config_name):
    """
    获取配置文件路径
    
    Args:
        config_name: 配置文件名称 ('pip.conf', 'pythonrc.py', 'requirements.txt')
        
    Returns:
        配置文件的绝对路径
    """
    config_map = {
        'pip.conf': PIP_CONFIG_PATH,
        'pythonrc.py': PYTHONRC_PATH,
        'requirements.txt': REQUIREMENTS_PATH
    }
    
    return config_map.get(config_name, None)

# 导出函数
__all__ = [
    '__version__',
    '__author__',
    '__email__',
    '__url__',
    'MODULE_PATH',
    'PIP_CONFIG_PATH',
    'PYTHONRC_PATH',
    'REQUIREMENTS_PATH',
    'init',
    'load_pythonrc',
    'get_config_path'
]
