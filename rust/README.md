# Rust 模块

Rust 开发环境配置：rustup 工具链、cargo 镜像、常用工具、代码质量工具。

## 目录结构

```
rust/
├── install.sh                 # Rust 模块安装主脚本
├── _common.sh                 # 公共函数
├── check.sh                   # 环境检查脚本
├── clean.sh                   # 清理 registry/缓存
├── uninstall.sh               # 卸载 Rust 工具链
├── upgrade.sh                 # 升级 rustup 和所有 cargo 工具
├── pin.sh                     # 固定工具链版本 (rust-toolchain.toml)
├── cargo_config.toml.template # cargo 配置模板（含国内镜像源）
├── rust-toolchain.toml        # 默认工具链 (stable)
├── rustfmt.toml               # 代码格式化规则
├── clippy.toml                # Clippy Lint 规则
└── tools.list                 # cargo install 工具列表
```

## 工具链管理

默认工具链（`rust-toolchain.toml`）：

```toml
[toolchain]
channel = "stable"
components = [
  "rustfmt",      # 代码格式化
  "clippy",       # Lint 检查
  "rust-analysis",# IDE 分析数据
  "rust-docs",    # 本地文档
  "rust-src"      # 标准库源码（IDE 跳转）
]
targets = []
```

### Homebrew Rust 兼容

Homebrew 安装的 Rust 不创建 `~/.cargo/env` 文件，Zsh 配置中条件性添加：

```zsh
if [[ -f "${HOME}/.cargo/env" ]]; then
  source "${HOME}/.cargo/env"
fi
```

不影响 brew 安装的 Rust（已在 PATH 中）。

## Cargo 国内镜像配置 (`cargo_config.toml.template`)

安装后复制到 `~/.cargo/config.toml`：

```toml
[source.crates-io]
replace-with = 'rsproxy-sparse'

[source.rsproxy]
registry = "https://rsproxy.cn/crates.io-index"

[source.rsproxy-sparse]
registry = "sparse+https://rsproxy.cn/index/"

[registries.rsproxy]
index = "https://rsproxy.cn/crates.io-index"

[net]
git-fetch-with-cli = true
```

## 代码质量工具

### rustfmt.toml 格式化规则

```toml
max_width = 100
use_small_heuristics = "Max"
fn_args_layout = "Vertical"
struct_variant_width = 100
struct_field_align_threshold = 30
enum_discrim_align_threshold = 30
match_block_trailing_comma = true
reorder_impl_items = true
group_imports = "StdExternalCrate"
imports_layout = "HorizontalVertical"
wrap_comments = true
condense_wildcard_suffixes = true
format_code_in_doc_comments = true
format_macro_matchers = true
format_strings = true
normalize_doc_attributes = true
```

### clippy.toml Lint 规则

```toml
msrv = "1.75.0"  # 最低支持 Rust 版本

# 严格模式
too-many-arguments-threshold = 5
too-many-lines-threshold = 120
type-complexity-threshold = 500
cognitive-complexity-threshold = 25
```

## cargo 工具列表 (tools.list)

安装时自动 `cargo install` 以下工具：

| 工具 | 功能 | 替代 |
|------|------|------|
| `cargo-edit` | `cargo add/rm/upgrade` | 编辑 Cargo.toml |
| `cargo-watch` | 文件变更自动编译/测试 | `cargo watch -x check` |
| `cargo-audit` | 检查依赖漏洞 | `cargo audit` |
| `cargo-outdated` | 检查过时依赖 | `cargo outdated` |
| `cargo-tree` | 依赖树（duplicate 分析）| `cargo tree -d` |
| `bat` | 带语法高亮的 `cat` | `cat` 替代 |
| `fd-find` | 并行文件查找 | `find` 替代 |
| `ripgrep` | 并行文本搜索 | `grep` 替代 |
| `tokei` | 代码统计 | `cloc` 替代 |

## 安装

```bash
cd ~/.dotfiles
./rust/install.sh
```

安装脚本功能：
1. 检测 rustup 是否安装，未安装时用 rustup.rs 脚本安装（国内镜像加速）
2. 设置默认工具链 stable + components
3. 写入 `cargo_config.toml.template` → `~/.cargo/config.toml`（国内镜像）
4. 安装 tools.list 中的 cargo 工具
5. 写入 `rustfmt.toml` / `clippy.toml` → `~/.config/`
6. 设置环境变量（条件性加载 `~/.cargo/env`）

## 常用命令速查

| 功能 | 命令 |
|------|------|
| 新建项目 | `cargo new myproj` |
| 编译 | `cargo build --release` |
| 运行 | `cargo run` |
| 测试 | `cargo test` |
| 添加依赖 | `cargo add <crate>` / `cargo add --dev <crate>` |
| 格式化 | `cargo fmt` |
| Lint | `cargo clippy -- -D warnings` |
| 检查漏洞 | `cargo audit` |
| 检查过时依赖 | `cargo outdated` |
| 依赖树 | `cargo tree` / `cargo tree -d` (重复) |
| 升级工具链 | `rustup update` |
| 自动编译测试 | `cargo watch -x test` |
