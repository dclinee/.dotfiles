# Dotfiles Python Module

这是一个用于跨平台Python开发环境的模块，包含了常用的Python配置、工具和依赖管理。

## 功能特性

### 🎯 核心功能
- **跨平台支持**：完美兼容Linux、macOS和Windows
- **现代打包支持**：符合PEP 517/518标准的pyproject.toml配置
- **统一的pip配置**：使用国内镜像源加速下载
- **增强的Python交互式体验**：丰富的内置函数和自动导入
- **模块化设计**：易于扩展和维护
- **统一的依赖管理**：集中管理Python依赖
- **虚拟环境自动激活**：检测当前目录的.venv目录并自动激活

### 📦 内置配置

1. **`pip.conf`** - Pip配置文件
   - 超时设置
   - 缓存配置
   - 国内镜像源配置
   - 自动信任国内源

2. **`pythonrc.py`** - Python交互式增强
   - 自动补全和历史记录
   - 彩色输出支持
   - 内置常用命令（cls, ls, cat, pwd, cd等）
   - 自动导入常用模块（numpy, pandas, matplotlib等）
   - 目录和文件操作功能

3. **`requirements.txt`** - Python依赖列表
   - 基础开发工具
   - 数据分析库
   - Web开发框架
   - 实用工具库

4. **`setup.py`** - 简化的安装脚本
   - 主要配置已迁移到pyproject.toml
   - 支持pip安装
   - 跨平台兼容

5. **`pyproject.toml`** - 现代Python打包配置
   - 符合PEP 517/518标准
   - 统一的项目配置
   - 支持setuptools构建后端
   - 模块化的配置结构
   - 支持依赖管理

## 快速开始

### 安装依赖

```bash
# 使用requirements.txt安装依赖
pip3 install --upgrade -r requirements.txt

# 或使用现代打包方式（推荐）
pip3 install -e .

# 或使用build模块构建
pip3 install build
python -m build
```

### 使用Python交互式增强

```bash
# 直接运行python，会自动加载pythonrc.py
python

# 或显式指定
python -c "exec(open('pythonrc.py').read())"
```

### 常用命令

| 命令 | 功能 |
|------|------|
| `cls()` | 清屏 |
| `ls(path='.')` | 列出目录内容 |
| `cat(file_path)` | 查看文件内容 |
| `pwd()` | 显示当前目录 |
| `cd(path)` | 切换目录 |
| `mkd(path)` | 创建目录 |
| `rmf(path)` | 删除文件或目录 |
| `ll(path='.')` | 详细列出目录内容 |
| `size(path='.')` | 显示文件或目录大小 |
| `now()` | 显示当前时间 |
| `today()` | 显示今天的日期 |
| `jsonf(file_path)` | 格式化显示JSON文件 |
| `yamlf(file_path)` | 格式化显示YAML文件 |

## 跨平台配置

### Linux/macOS

```bash
# 设置环境变量
export PYTHONSTARTUP="$HOME/.dotfiles/python/pythonrc.py"
export PIP_CONFIG_FILE="$HOME/.dotfiles/python/pip.conf"
```

### Windows

```powershell
# 设置环境变量
setx PYTHONSTARTUP "%USERPROFILE%\.dotfiles\python\pythonrc.py"
setx PIP_CONFIG_FILE "%USERPROFILE%\.dotfiles\python\pip.conf"
```

## 自定义配置

### 添加新依赖

```bash
# 修改requirements.txt文件，添加新依赖
# 然后运行
pip3 install --upgrade -r requirements.txt
```

### 扩展pythonrc.py

1. 在`pythonrc.py`中添加新的自定义函数
2. 扩展自动导入的模块列表
3. 修改或添加新的快捷键和别名

## 最佳实践

1. **使用虚拟环境**：
   ```bash
   python3 -m venv venv
   source venv/bin/activate  # Linux/macOS
   venv\Scripts\activate     # Windows
   ```

2. **定期更新依赖**：
   ```bash
   pip3 install --upgrade pip
   pip3 install --upgrade -r requirements.txt
   ```

3. **使用国内镜像源**：
   - 配置已经包含在`pip.conf`中，无需额外设置

4. **结合pyenv使用**：
   ```bash
   # 安装pyenv
   curl https://pyenv.run | bash
   
   # 安装指定Python版本
   pyenv install 3.11.0
   
   # 设置全局Python版本
   pyenv global 3.11.0
   
   # 设置局部Python版本（当前目录）
   pyenv local 3.11.0
   
   # 查看已安装的Python版本
   pyenv versions
   
   # 使用pyenv virtualenv创建虚拟环境
   pyenv virtualenv 3.11.0 myenv
   
   # 激活虚拟环境
   pyenv activate myenv
   
   # 退出虚拟环境
   pyenv deactivate
   
   # 设置当前目录使用的虚拟环境
   pyenv local myenv
   ```

5. **pyenv配置说明**：
   - **自动集成**：我们的配置会自动检测pyenv并进行初始化
   - **完整支持**：包括pyenv init --path、pyenv init -s和pyenv virtualenv-init
   - **无缝切换**：支持全局、局部和shell级别的Python版本切换
   - **虚拟环境管理**：方便创建和管理多个虚拟环境

6. **pyenv最佳实践**：
   - **为每个项目设置局部Python版本**：使用`pyenv local <version>`
   - **使用虚拟环境隔离依赖**：为每个项目创建独立的虚拟环境
   - **定期更新pyenv**：使用`pyenv update`命令更新pyenv和插件
   - **使用python-version文件**：将项目的Python版本信息添加到版本控制

## 许可证

MIT License

## 贡献

欢迎提交Issue和Pull Request！
