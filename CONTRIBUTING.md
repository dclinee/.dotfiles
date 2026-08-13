# 贡献指南

感谢你对本项目的兴趣！欢迎提交 Issue 和 Pull Request。

## 🐛 提交 Issue

提交 Issue 前请先搜索是否已有相同问题。Issue 类型包括：

- **Bug 报告**：描述复现步骤、期望行为、实际行为、环境信息（OS / Shell 版本）
- **功能建议**：说明使用场景和期望效果
- **文档问题**：指出文档中的错误或不清晰之处

## 🔧 提交 Pull Request

### 1. 准备环境

```bash
# Fork 仓库后克隆到本地
git clone https://github.com/<your-username>/.dotfiles.git ~/.dotfiles
cd ~/.dotfiles

# 或者用环境变量指定你的 fork
DOTFILES_REPO_URL=https://github.com/<your-username>/.dotfiles.git ./bootstrap.sh
```

### 2. 创建分支

```bash
git checkout -b fix/描述性名称    # 修复
git checkout -b feat/描述性名称   # 新功能
git checkout -b docs/描述性名称   # 文档
```

### 3. 开发与测试

修改代码后，**必须**通过以下验证：

```bash
# 静态语法检查（CI 会跑同一套）
bash test_install.sh static

# 配置语法验证
bash validate.sh

# 完整测试（含动态模拟，CI 不跑）
bash test_install.sh all
```

确保所有测试通过后再提交。

### 4. 提交规范

使用清晰的提交信息，建议格式：

```text
<类型>: <简短描述>

<详细说明（可选）>
```

类型包括：`fix`（修复）、`feat`（新功能）、`docs`（文档）、`refactor`（重构）、`test`（测试）、`chore`（杂项）。

示例：

```text
fix: Nerd Font detection cache mtime check on macOS

feat: add pipx fallback for PEP 668 environments

docs: clarify cross-platform brew path detection
```

### 5. 创建 PR

- PR 标题遵循与提交信息相同的格式
- 描述中说明：改了什么、为什么改、如何测试
- 如果是破坏性变更，请在描述中明确标注 `BREAKING CHANGE`

## 📐 代码风格

### Shell 脚本

- **严格模式**：所有脚本开头使用 `set -euo pipefail`
- **输出函数**：使用 `printf` 而非 `echo -e`（跨 shell 兼容性更好）
  - 颜色常量（含 `\033`）放在 printf 格式串中
  - 动态内容用 `%s` 参数传递，防止格式串注入
  - 字面 `%` 字符转义为 `%%`
- **shebang**：可执行脚本用 `#!/usr/bin/env bash`，zsh 配置片段用 `#!/usr/bin/env zsh`
- **扩展名**：可执行脚本用 `.sh`，zsh 配置片段用 `.zsh`（不要混用）
- **错误处理**：关键操作检查返回值，失败时给出明确提示
- **跨平台**：Linux 和 macOS 都要支持，用 `command -v` 检测命令存在性

### Zsh 配置

- 配置文件按编号顺序加载：`00_env` → `01_options` → `02_aliases` → `03_functions` → `04_plugins` → `05_starship`
- 平台特定配置放 `platform/` 目录（`linux.zsh` / `macos.zsh`）
- 避免在配置中硬编码个人路径或凭证
- 个人配置应放在 `~/.zshrc.local`（不纳入仓库）

### Git 配置

- 不要在 `.gitconfig` 中硬编码用户名/邮箱（使用 `YOUR_NAME` / `YOUR_EMAIL` 占位符）
- 个人信息由 `~/.gitconfig.local` 覆盖

## 🌐 跨平台注意事项

- **路径**：Linux 用 `/home/linuxbrew/.linuxbrew`，macOS 用 `/opt/homebrew`（Apple Silicon）或 `/usr/local`（Intel）
- **包管理器**：检测顺序为 brew → apt → dnf → pacman
- **字体**：未安装 Nerd Font 时必须有降级方案
- **镜像**：外部下载支持国内镜像降级（GitHub → ghproxy.net → gh-proxy.com）

## ✅ Review Checklist

提交 PR 前请自检：

- [ ] `bash test_install.sh static` 通过
- [ ] `bash validate.sh` 通过
- [ ] 没有硬编码个人信息（邮箱、用户名、密钥）
- [ ] 没有引入新的外部依赖（或已在文档中说明）
- [ ] 新增功能有对应的测试用例
- [ ] 文档已同步更新

## 📄 许可证

提交的代码将遵循 [MIT License](LICENSE)。
