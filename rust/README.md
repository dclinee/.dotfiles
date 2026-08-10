# Rust 模块

Rust 开发环境配置与维护工具集。

## 文件结构

```
rust/
├── install.sh                   # 部署主入口：安装 rustup、配置镜像、环境变量、全局工具
├── uninstall.sh                 # 卸载：移除配置软链、清理环境变量，可选卸载 rust 本体
├── check.sh                     # 环境体检：版本校验、源检测、权限排查
├── upgrade.sh                   # 一键升级：rust 编译器 + 全局工具
├── clean.sh                     # 清理：编译缓存、卸载冗余组件
├── pin.sh                       # 版本固化：记录当前版本，支持恢复和对比
├── _common.sh                   # 内部公共加载器（加载 lib/ 库 + 工具函数）
├── cargo_config.toml.template   # Cargo 全局配置模板（镜像、编译参数、代理适配）
├── tools.list                   # Rust 全局二进制工具清单（包名|版本）
├── rustfmt.toml                 # rustfmt 格式化配置
├── clippy.toml                  # clippy 代码检查配置
├── rust-toolchain.toml          # 项目级工具链配置模板
└── README.md                    # 本文件
```

## 快速使用

### 安装

```bash
# 通过 Makefile
make rust

# 直接执行
./rust/install.sh

# 通过 bootstrap.sh
./bootstrap.sh --rust
```

### 日常维护

```bash
make rust-check      # 环境体检
make rust-upgrade    # 一键升级
make rust-clean      # 清理缓存
make rust-uninstall  # 卸载配置
```

或直接执行脚本：

```bash
./rust/check.sh
./rust/upgrade.sh
./rust/clean.sh
./rust/uninstall.sh
```

## 脚本说明

### install.sh

部署主入口，执行以下操作：
1. 检测 Rust 安装方式（rustup 优先，Homebrew 兼容支持）
2. rustup 模式：安装 stable 工具链及组件（rustfmt、clippy、rust-src）
3. 链接 Cargo 配置（镜像源、编译参数、sparse 协议）
4. 链接 rustfmt / clippy 配置
5. 从 `tools.list` 安装 cargo 扩展工具
6. 配置环境变量（条件性加载 `~/.cargo/env`）

### uninstall.sh

| 选项 | 说明 |
|------|------|
| （默认） | 移除配置软链 + 清理环境变量 |
| `--tools` | 额外卸载 cargo 扩展工具 |
| `--purge` | 彻底卸载 rustup + 工具链（需确认） |

### check.sh

环境体检，检查以下项目：
- 核心工具版本（rustup / rustc / cargo）
- 安装方式检测（rustup / Homebrew 均支持）
- 工具链与组件状态（仅 rustup 模式）
- 镜像源配置
- 配置文件软链正确性
- cargo 工具安装状态
- 目录权限排查

### upgrade.sh

| 选项 | 说明 |
|------|------|
| （默认） | 升级工具链 + cargo 工具 |
| `--toolchain` | 仅升级 Rust 工具链 |
| `--tools` | 仅升级 cargo 扩展工具 |

### clean.sh

| 选项 | 说明 |
|------|------|
| （默认） | 清理 cargo 缓存 + registry |
| `--deep` | 深度清理（含卸载冗余工具） |
| `--dry-run` | 预览将清理的内容 |

### pin.sh

| 选项 | 说明 |
|------|------|
| （默认） | 固化当前版本到 `versions.lock` |
| `--restore` | 从 `versions.lock` 恢复版本 |
| `--diff` | 对比当前版本与锁定版本 |

## tools.list 格式

```
# 格式: 包名|版本
#   版本留空 = 安装最新稳定版
#   版本指定 = cargo install --version <ver>
#   以 # 开头的行为注释，自动跳过
#
# 工具分类:
#   文件监控: cargo-watch
#   过期检查: cargo-outdated
#   安全审计: cargo-audit
#   代码展开: cargo-expand
#   预编译: cargo-binstall
```

## 配置文件说明

| 文件 | 链接目标 | 说明 |
|------|----------|------|
| `cargo_config.toml.template` | `~/.cargo/config.toml` | 镜像源、编译 profile、网络配置 |
| `rustfmt.toml` | `~/.rustfmt.toml` | 代码格式化规则 |
| `clippy.toml` | `~/.clippy.toml` | clippy 检查阈值 |
| `rust-toolchain.toml` | （项目级复制） | 项目工具链覆盖模板 |

## 镜像源

默认使用清华大学 TUNA 镜像（sparse 协议），备选：
- USTC: `sparse+https://mirrors.ustc.edu.cn/crates.io-index/`
- SJTU: `sparse+https://mirrors.sjtug.sjtu.edu.cn/git/crates.io-index`

切换镜像：编辑 `cargo_config.toml.template` 中的 `replace-with` 字段。
