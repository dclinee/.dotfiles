#!/usr/bin/env bash
# 集成测试: 验证 Docker 容器内完整安装后的配置
set -euo pipefail

DOTFILES_DIR="${HOME}/.dotfiles"
PASS=0
FAIL=0

check() {
  local desc="$1"
  local condition="$2"
  if eval "$condition"; then
    printf '✓ %s\n' "$desc"
    PASS=$((PASS + 1))
  else
    printf '✗ %s\n' "$desc"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== 集成测试: 验证完整安装 ==="
echo ""

# 1. 符号链接验证
echo "--- 符号链接 ---"
check ".zshrc 链接存在" "[[ -L ${HOME}/.zshrc ]]"
check ".vimrc 链接存在" "[[ -L ${HOME}/.vimrc ]]"
check ".gitconfig 链接存在" "[[ -L ${HOME}/.gitconfig ]]"
check ".tmux.conf 链接存在" "[[ -L ${HOME}/.tmux.conf ]]"
check ".editorconfig 链接存在" "[[ -L ${HOME}/.editorconfig ]]"
check ".gitattributes 链接存在" "[[ -L ${HOME}/.gitattributes ]]"
check ".gitignore_global 链接存在" "[[ -L ${HOME}/.gitignore_global ]]"
check ".wezterm.lua 链接存在" "[[ -L ${HOME}/.wezterm.lua ]]"
check "init.el 链接存在" "[[ -L ${HOME}/.emacs.d/init.el ]]"

# 2. Zsh 配置验证
echo "--- Zsh 配置 ---"
check ".zshenv 可读取" "[[ -r ${HOME}/.zshenv ]]"
check "zsh 语法正确" "zsh -n ${HOME}/.zshrc 2>/dev/null"
check "zsh 可交互启动" "zsh -ic 'echo ok' 2>/dev/null | grep -q ok"
check "core 目录有配置文件" "[[ -d ${DOTFILES_DIR}/zsh/core ]]"
check "platform 目录有配置文件" "[[ -d ${DOTFILES_DIR}/zsh/platform ]]"
check "00_env.zsh 存在" "[[ -f ${DOTFILES_DIR}/zsh/core/00_env.zsh ]]"
check "02_aliases.zsh 存在" "[[ -f ${DOTFILES_DIR}/zsh/core/02_aliases.zsh ]]"
check "03_functions.zsh 存在" "[[ -f ${DOTFILES_DIR}/zsh/core/03_functions.zsh ]]"

# 3. Vim 配置验证
echo "--- Vim 配置 ---"
check ".vimrc 语法正确" "vim -es -c 'q' 2>/dev/null"
check "core 目录存在" "[[ -d ${DOTFILES_DIR}/vim/core ]]"
check "ftplugin 目录存在" "[[ -d ${DOTFILES_DIR}/vim/ftplugin ]]"
check "platform 目录存在" "[[ -d ${DOTFILES_DIR}/vim/platform ]]"
check "python ftplugin 存在" "[[ -f ${DOTFILES_DIR}/vim/ftplugin/python.vim ]]"
check "rust ftplugin 存在" "[[ -f ${DOTFILES_DIR}/vim/ftplugin/rust.vim ]]"

# 4. Git 配置验证
echo "--- Git 配置 ---"
check "git config 可读取" "git config --global user.name > /dev/null 2>&1"
check "hooksPath 配置正确" "git config --global core.hooksPath 2>/dev/null | grep -q 'dotfiles/git/hooks'"
if [[ "$(uname)" == "Darwin" ]]; then
  check "Git credential helper 使用 osxkeychain" "git config --global credential.helper 2>/dev/null | grep -q osxkeychain"
else
  check "Git credential helper 使用 libsecret" "git config --global credential.helper 2>/dev/null | grep -q libsecret"
fi
check "pre-commit hook 可执行" "[[ -x ${DOTFILES_DIR}/git/hooks/pre-commit ]]"
check "commit-msg hook 可执行" "[[ -x ${DOTFILES_DIR}/git/hooks/commit-msg ]]"
check "pre-push hook 可执行" "[[ -x ${DOTFILES_DIR}/git/hooks/pre-push ]]"
check ".gitconfig.local 模板存在" "[[ -f ${DOTFILES_DIR}/git/.gitconfig.local.example ]]"

# 5. Brew 配置验证
echo "--- Brew 配置 ---"
check "brew 命令可用" "command -v brew > /dev/null 2>&1"
check "Brewfile 存在" "[[ -f ${DOTFILES_DIR}/brew/Brewfile ]]"
check "Brewfile.linux 存在" "[[ -f ${DOTFILES_DIR}/brew/Brewfile.linux ]]"
check "install.sh 存在" "[[ -f ${DOTFILES_DIR}/brew/install.sh ]]"
check "brew 命令可用" "command -v brew > /dev/null 2>&1"

# 6. Python 配置验证
echo "--- Python 配置 ---"
check "python3 命令可用" "command -v python3 > /dev/null 2>&1"
check "pip.conf 链接存在" "[[ -L ${HOME}/.pip/pip.conf ]]"
check "requirements.txt 存在" "[[ -f ${DOTFILES_DIR}/python/requirements.txt ]]"
check "requirements-web.txt 存在" "[[ -f ${DOTFILES_DIR}/python/requirements-web.txt ]]"
check "install.sh 存在" "[[ -f ${DOTFILES_DIR}/python/install.sh ]]"

# 7. Rust 配置验证
echo "--- Rust 配置 ---"
check "cargo 命令可用" "command -v cargo > /dev/null 2>&1"
check "install.sh 存在" "[[ -f ${DOTFILES_DIR}/rust/install.sh ]]"
check "rustfmt.toml 存在" "[[ -f ${DOTFILES_DIR}/rust/rustfmt.toml ]]"
check "clippy.toml 存在" "[[ -f ${DOTFILES_DIR}/rust/clippy.toml ]]"

# 8. WezTerm 配置验证
echo "--- WezTerm 配置 ---"
check ".wezterm.lua 语法正确" "wezterm --version > /dev/null 2>&1"
check "core 目录存在" "[[ -d ${DOTFILES_DIR}/wezterm/core ]]"
check "platform 目录存在" "[[ -d ${DOTFILES_DIR}/wezterm/platform ]]"
check "00_basic.lua 存在" "[[ -f ${DOTFILES_DIR}/wezterm/core/00_basic.lua ]]"
check "01_keybindings.lua 存在" "[[ -f ${DOTFILES_DIR}/wezterm/core/01_keybindings.lua ]]"
check "linux.lua 存在" "[[ -f ${DOTFILES_DIR}/wezterm/platform/linux.lua ]]"

# 9. Tmux 配置验证
echo "--- Tmux 配置 ---"
check ".tmux.conf 存在" "[[ -f ${DOTFILES_DIR}/tmux/.tmux.conf ]]"
check "tmux 命令可用" "command -v tmux > /dev/null 2>&1"

# 10. Emacs 配置验证
echo "--- Emacs 配置 ---"
check "init.el 链接存在" "[[ -L ${HOME}/.emacs.d/init.el ]]"
check "early-init.el 存在" "[[ -f ${HOME}/.emacs.d/early-init.el ]]"
check "init.el 语法可编译" "emacs --batch -l ${HOME}/.emacs.d/init.el 2>/dev/null"

# 11. lib 库验证
echo "--- 公共库 ---"
check "lib/common.sh 存在" "[[ -f ${DOTFILES_DIR}/lib/common.sh ]]"
check "lib/output.sh 存在" "[[ -f ${DOTFILES_DIR}/lib/output.sh ]]"
check "lib/symlink.sh 存在" "[[ -f ${DOTFILES_DIR}/lib/symlink.sh ]]"
check "bootstrap.sh 存在" "[[ -f ${DOTFILES_DIR}/bootstrap.sh ]]"
check "validate.sh 存在" "[[ -f ${DOTFILES_DIR}/validate.sh ]]"
check "test_install.sh 存在" "[[ -f ${DOTFILES_DIR}/test_install.sh ]]"

# 12. CI/CD 验证
echo "--- CI/CD ---"
check "ci.yml 存在" "[[ -f ${DOTFILES_DIR}/.github/workflows/ci.yml ]]"
check "Makefile 存在" "[[ -f ${DOTFILES_DIR}/Makefile ]]"
check ".editorconfig 存在" "[[ -f ${DOTFILES_DIR}/.editorconfig ]]"
check ".gitattributes 存在" "[[ -f ${DOTFILES_DIR}/.gitattributes ]]"
check ".shellcheckrc 存在" "[[ -f ${DOTFILES_DIR}/.shellcheckrc ]]"
check ".tool-versions 存在" "[[ -f ${DOTFILES_DIR}/.tool-versions ]]"

# 13. Makefile 验证
echo "--- Makefile ---"
check "make help 可执行" "make -C ${DOTFILES_DIR} help > /dev/null 2>&1"
check "make install 可执行" "make -C ${DOTFILES_DIR} -n install > /dev/null 2>&1"
check "make update 可执行" "make -C ${DOTFILES_DIR} -n update > /dev/null 2>&1"

# 14. 环境变量验证
echo "--- 环境变量 ---"
check "DOTFILES_ROOT 在 .zshenv 中设置" "grep -q 'DOTFILES_ROOT' ${HOME}/.zshenv"
check "PATH 包含 .local/bin" "zsh -c 'echo \$PATH' 2>/dev/null | grep -q '.local/bin' || true"
check "EDITOR 已设置" "zsh -ic 'echo \$EDITOR' 2>/dev/null | grep -q '.' || true"

echo ""
printf '=== 测试结果 ===\n'
printf '✓ 通过: %s\n' "$PASS"
printf '✗ 失败: %s\n' "$FAIL"
printf '总计: %s\n' "$((PASS + FAIL))"

if [[ $FAIL -gt 0 ]]; then
  echo ""
  printf '❌ 有 %s 个测试失败\n' "$FAIL"
  exit 1
else
  echo ""
  printf '✅ 所有测试通过\n'
  exit 0
fi
