# PowerShell 模块（pwsh）

跨平台 PowerShell 配置模块，支持 **Windows 原生 / Linux / macOS**，同时兼容
**PowerShell 7+（pwsh，推荐）** 与 **Windows PowerShell 5.1（系统自带，仅 Windows）**。

> 定位：zsh 模块的 PowerShell 平行实现，只负责 shell 基础体验（Profile、Git 别名、
> PSReadLine、Prompt、智能跳转），不镜像 zsh 的插件体系。在 Windows 原生环境下，
> 本模块也是 Git 配置的安装入口（无 bash 可用时）。

## 文件结构

| 文件 | 作用 |
|------|------|
| `install.ps1` | PowerShell 原生主安装器（Windows 上的独立入口） |
| `install.sh` | bash 侧封装，供 `bootstrap.sh --pwsh` / `make pwsh` 调度 |
| `check.ps1` | PowerShell 原生体检（版本/文件/Profile 链接/PSReadLine/加载冒烟测试） |
| `check.sh` | bash 侧体检封装，供 `make pwsh-check` / `make doctor` 调度 |
| `_common.ps1` | PS 公共函数库：输出、平台检测、`New-SafeLink` 三层降级 |
| `_common.sh` | bash 侧公共函数：`has_pwsh` / `select_pwsh_bin` |
| `profile.ps1` | Profile 主入口，被链接到 `$PROFILE.CurrentUserCurrentHost` |
| `modules/00_env.ps1` | UTF-8 编码、PATH、PSReadLine、EDITOR |
| `modules/01_aliases.ps1` | Git 快捷函数（g/ga/gd…）、ll/la、which、touch、mkcd |
| `modules/02_functions.ps1` | `check_ps` 体检、Git 分支探测、管理员检测 |
| `modules/03_prompt.ps1` | 双行彩色 prompt（失败码/venv/路径缩短/Git 聚合状态/任务数/耗时 + `❯` 箭头；重定向降级纯文本；starship 存在则覆盖；zoxide 智能跳转） |
| `modules/99_local.ps1` | 本地覆盖（**不入库**，需自行创建） |

## 安装

### Windows 原生（推荐 PowerShell 7）

```powershell
# 未安装 pwsh 时：
winget install Microsoft.PowerShell

# 在仓库根目录执行（ExecutionPolicy Bypass 仅对当前进程生效）
pwsh -ExecutionPolicy Bypass -File pwsh\install.ps1

# 预演（不改动任何文件）
pwsh -ExecutionPolicy Bypass -File pwsh\install.ps1 -DryRun
```

### Linux / macOS

```bash
# 通过统一入口（推荐）
./bootstrap.sh --pwsh
make pwsh

# 直接调用
pwsh -File pwsh/install.ps1
```

### WSL

WSL 中主力 shell 仍是 zsh。`bootstrap.sh --pwsh` 在 WSL 下只接受 **Linux 原生 pwsh**，
不会误用通过互操作找到的 `powershell.exe`（那属于 Windows 侧配置）。
如需配置 Windows 侧 Profile，请在 Windows 终端中运行 `install.ps1`。

## Windows 符号链接的三层降级

Windows 原生创建符号链接需要**管理员权限**或开启**开发者模式**。`New-SafeLink` 按以下顺序自动降级：

1. **SymbolicLink**（真正的符号链接，行为与 Linux/macOS 一致）
2. **Junction**（目录）/ **HardLink**（文件）—— 无需提权；硬链接不可跨卷、不随源文件独立更新
3. **Copy**（普通复制）—— 最终兜底，保证配置可用，并提示开启开发者模式

被替换的已有文件会备份到 `~/.cache/dotfiles_pwsh_backup_<时间戳>/`。

建议开启开发者模式：`设置 → 系统 → 开发者选项 → 开发人员模式`，然后重新运行安装器。

### 入口文件的伴生内容同步

Profile 入口 `profile.ps1` 依赖同目录的 `_common.ps1` 与 `modules/`，单独复制一个入口文件会导致加载失败。
因此 Profile 走 HardLink/Copy 兜底时，安装器会通过 `-CompanionPaths` 自动把依赖按相同相对结构同步到
Profile 所在目录：**伴生目录用 Junction**（支持跨卷、免提权，如 Documents 被重定向到 D 盘、仓库在 C 盘），
**伴生文件先尝试 HardLink，跨卷失败则 Copy**。同步是幂等的，重复运行安装器会跳过指向同源的链接。

### Profile 路径解析回退链

无论 Profile 以哪种方式落地，`profile.ps1` 按以下顺序定位真实模块目录，第一个含 `_common.ps1` 的生效：

1. 自身所在目录（伴生同步后的 HardLink/Copy，或直接运行仓库文件）
2. 符号链接 `.Target` 的真实目录
3. `$env:DOTFILES_ROOT\pwsh`
4. `$HOME\.dotfiles\pwsh`（跨盘符兜底，如仓库在 C 盘、Documents 在 D 盘）

全部找不到时会给出"请重新运行 install.ps1"的明确警告，而不是抛出一堆加载错误。


## Profile 路径差异

安装器自动选择当前运行时对应的 `$PROFILE.CurrentUserCurrentHost`：

| 运行时 | Windows 路径 |
|--------|-------------|
| PowerShell 7 | `%USERPROFILE%\Documents\PowerShell\Microsoft.PowerShell_profile.ps1` |
| Windows PowerShell 5.1 | `%USERPROFILE%\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1` |

Linux/macOS（PowerShell 7）：`~/.config/powershell/Microsoft.PowerShell_profile.ps1`

## Git 配置联动

`install.ps1` 默认同时链接 Git 三件套（`.gitconfig` / `.gitignore_global` / `.gitattributes`）
并创建 `~/.gitconfig.local` 模板。平台差异处理：

- 仓库主配置的 `credential.helper=cache` 依赖 Unix socket，**Git for Windows 不支持**；
  安装器自动把 `manager`（旧版 Git 为 `manager-core`）写入 `~/.gitconfig.local` 覆盖，
  不修改被链接的仓库文件
- 仅安装 Profile：`-SkipGit`

## 常用命令

```powershell
check_ps        # 环境体检（版本、Profile 链接、工具、符号链接权限）
Reload-Profile  # 修改配置后免重启重新加载
g / ga / gd / gst / gl / gp   # Git 快捷函数
ll / la         # eza 增强列表（缺失时回退 Get-ChildItem）
z <目录关键词>  # zoxide 智能跳转（需已安装）
```

Prompt 优先使用 starship（与 zsh 侧外观统一）；未安装时使用内置双行主题（无需 Nerd Font，Cascadia/Consolas 可渲染）：

```text
 ✗ 7 (myproj) ~/d/pwsh on main ↑1 +2 ~1 ?3  ⧗1.2s
 ❯
```

- 第一行：失败退出码 → 虚拟环境（venv/conda）→ 智能缩短路径（`$HOME` 缩写为 `~`，超 3 层中间目录只留首字母）→
  Git 段（分支、↑ahead/↓behind、`+`暂存/`~`改动/`?`未跟踪/`!!`冲突计数）→ 后台任务数 → 上条命令耗时（>300ms）
- 第二行：`❯` 成功绿色/失败红色；管理员会话前缀 `⚡`
- 终端不支持 ANSI 或输出被重定向时自动降级为纯文本
- 设置 `$env:DOTFILES_PROMPT_COMPACT = '1'` 可关闭命令间空行

## 本地自定义

创建 `pwsh/modules/99_local.ps1`（已被 .gitignore 忽略），内容会在 Profile 末尾自动加载。

## 兼容性说明

- 全部脚本以 PS 5.1 语法为基线（不使用 `??`、`?.`、三元表达式等 PS7 专有语法）
- `.ps1` 文件统一保存为 **UTF-8 with BOM**，确保 Windows PowerShell 5.1 正确解析中文与 Unicode 图标
