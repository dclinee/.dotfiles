# lib/ — 共享函数库

本目录提供所有模块脚本复用的共享函数库，通过 `_module_loader.sh` 统一加载。

## 库文件

| 文件 | 职责 | 关键函数 |
|------|------|---------|
| `_module_loader.sh` | 模块统一加载器 | （内部）解析 `DOTFILES_ROOT` + 注入模块目录变量 |
| `output.sh` | 终端输出美化 | `echo_step`/`echo_success`/`echo_warning`/`echo_error`/`echo_skip`/`echo_detail`/`echo_separator`/`echo_title` |
| `make-output.sh` | Makefile install 输出美化 | `make_banner`/`make_step`/`make_ok`/`make_fail`/`make_summary` |
| `symlink.sh` | 符号链接管理 | `safe_symlink`/`_resolve_link` |
| `net.sh` | 网络下载 + 镜像回退 | `dotfiles_curl`/`dotfiles_clone`/`dotfiles_install_script`/`dotfiles_gh_proxies` |
| `common.sh` | 通用工具 + 体检统计 + 批量操作 | `has_cmd`/`is_dry_run`/`read_tools_list`/`check_init`/`check_ok`/`check_warn`/`check_fail`/`check_summary`/`check_symlinks`/`remove_symlinks`/`clean_dirs` |

## 依赖加载顺序

```
output.sh → symlink.sh → common.sh
                 ↑
             net.sh（独立）
```

`common.sh` 自动加载 `output.sh` + `symlink.sh` + `net.sh`（fail-fast）。

## 使用方法

模块内 `_common.sh` 只需 3 行：

```bash
#!/usr/bin/env bash
# module/_common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/_module_loader.sh" "MODULE_DIR"
```

之后即可使用所有共享函数。