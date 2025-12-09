#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Python 交互式 shell 配置文件
"""

# 导入常用模块
import os
import sys
import re
import datetime
import time
from pathlib import Path

# 启用自动补全
try:
    import readline
    import rlcompleter
    if 'libedit' in readline.__doc__:
        readline.parse_and_bind("bind ^I rl_complete")
    else:
        readline.parse_and_bind("tab: complete")
except ImportError:
    pass

# 启用历史记录
try:
    import readline
    histfile = os.path.join(os.path.expanduser("~"), ".python_history")
    try:
        readline.read_history_file(histfile)
    except FileNotFoundError:
        pass
    readline.set_history_length(1000)
    import atexit
    atexit.register(readline.write_history_file, histfile)
except ImportError:
    pass

# 彩色输出
try:
    from rich import print
    from rich.console import Console
    from rich.table import Table
    console = Console()
except ImportError:
    pass

# 自定义函数
def cls():
    """清屏"""
    os.system('cls' if os.name == 'nt' else 'clear')

def ls(path='.'):
    """列出目录内容"""
    files = os.listdir(path)
    for f in sorted(files):
        full_path = os.path.join(path, f)
        if os.path.isdir(full_path):
            print(f"[bold blue]{f}/[/bold blue]")
        else:
            print(f)

def cat(file_path):
    """查看文件内容"""
    try:
        with open(file_path, 'r') as f:
            print(f.read())
    except Exception as e:
        print(f"Error: {e}")

def pwd():
    """显示当前目录"""
    print(os.getcwd())

def cd(path):
    """切换目录"""
    try:
        os.chdir(path)
        print(f"Changed to: {os.getcwd()}")
    except Exception as e:
        print(f"Error: {e}")

def mkd(path):
    """创建目录"""
    try:
        os.makedirs(path, exist_ok=True)
        print(f"Created directory: {path}")
    except Exception as e:
        print(f"Error: {e}")

def rmf(path):
    """删除文件或目录"""
    try:
        if os.path.isfile(path):
            os.remove(path)
            print(f"Deleted file: {path}")
        elif os.path.isdir(path):
            import shutil
            shutil.rmtree(path)
            print(f"Deleted directory: {path}")
    except Exception as e:
        print(f"Error: {e}")

def ll(path='.'):
    """详细列出目录内容"""
    try:
        from rich.columns import Columns
        from rich.text import Text
        from rich.style import Style
        
        files = []
        for f in sorted(os.listdir(path)):
            full_path = os.path.join(path, f)
            stat = os.stat(full_path)
            size = stat.st_size
            mtime = time.ctime(stat.st_mtime)
            
            if os.path.isdir(full_path):
                style = Style(color="blue", bold=True)
                f = f + "/"
            else:
                style = Style()
            
            text = Text(f, style=style)
            text.append(f" {size:10d} {mtime}")
            files.append(text)
        
        console.print(Columns(files))
    except ImportError:
        os.system('ls -la' if os.name != 'nt' else 'dir')

def size(path='.'):
    """显示文件或目录大小"""
    if os.path.isfile(path):
        print(f"{os.path.getsize(path)} bytes")
    elif os.path.isdir(path):
        total = 0
        for root, dirs, files in os.walk(path):
            for f in files:
                full_path = os.path.join(root, f)
                total += os.path.getsize(full_path)
        print(f"{total} bytes")

def now():
    """显示当前时间"""
    print(datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S"))

def today():
    """显示今天的日期"""
    print(datetime.date.today().strftime("%Y-%m-%d"))

def jsonf(file_path):
    """格式化显示JSON文件"""
    import json
    try:
        with open(file_path, 'r') as f:
            data = json.load(f)
        print(json.dumps(data, indent=2, ensure_ascii=False))
    except Exception as e:
        print(f"Error: {e}")

def yamlf(file_path):
    """格式化显示YAML文件"""
    try:
        import yaml
        with open(file_path, 'r') as f:
            data = yaml.safe_load(f)
        print(yaml.dump(data, default_flow_style=False))
    except ImportError:
        print("PyYAML not installed")
    except Exception as e:
        print(f"Error: {e}")

# 自动导入常用模块
def __import_common_modules():
    """自动导入常用模块"""
    global np, pd, plt, sns
    try:
        import numpy as np
        print("✓ numpy imported as np")
    except ImportError:
        pass
    
    try:
        import pandas as pd
        print("✓ pandas imported as pd")
    except ImportError:
        pass
    
    try:
        import matplotlib.pyplot as plt
        print("✓ matplotlib.pyplot imported as plt")
    except ImportError:
        pass
    
    try:
        import seaborn as sns
        print("✓ seaborn imported as sns")
    except ImportError:
        pass

# 主程序
if __name__ == '__main__':
    print("Python interactive shell enhanced!")
    print("Available commands: cls, ls, cat, pwd, cd, mkd, rmf, ll, size, now, today, jsonf, yamlf")
    print()
    __import_common_modules()
    print()
