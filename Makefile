# ======================
# Dotfiles Makefile
# ======================
# 统一命令入口，简化操作
# 设计原则：所有 target 都委托给 per-component install.sh，避免与 bootstrap.sh 逻辑漂移

.PHONY: install update backup test check doctor clean help pwsh pwsh-check zsh zsh-check vim vim-check emacs wezterm wezterm-check wezterm-uninstall brew brew-check python rust tmux tmux-check git git-check ssh ssh-check ssh-uninstall editorconfig rust-check rust-upgrade rust-clean rust-uninstall rust-pin python-check python-install python-venv python-clean python-upgrade python-uninstall python-pin perf validate

# 默认目标
.DEFAULT_GOAL := help

# 颜色定义（printf 格式串使用，避免 echo -e 跨 shell 不一致）
RED    := \033[31m
CYAN   := \033[36m
GREEN  := \033[32m
YELLOW := \033[33m
RESET  := \033[0m
BOLD   := \033[1m

##@ 通用

help: ## 显示帮助信息
	@printf "$(BOLD)Dotfiles 管理命令$(RESET)\n"
	@printf "\n"
	@printf "$(CYAN)用法:$(RESET) make [target]\n"
	@printf "\n"
	@printf "$(CYAN)目标:$(RESET)\n"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-15s$(RESET) %s\n", $$1, $$2}'
	@printf "\n"
	@printf "$(CYAN)示例:$(RESET)\n"
	@printf "  make install      # 一键安装所有配置\n"
	@printf "  make doctor       # 全模块环境体检（汇总）\n"
	@printf "  make check        # 快速环境检查\n"
	@printf "  make update       # 更新配置和插件\n"

install: editorconfig git ssh brew zsh vim emacs wezterm python rust tmux pwsh ## 一键安装所有配置（推荐）
	@printf "\n"
	@printf "$(GREEN)✅ 所有配置安装完成！$(RESET)\n"
	@printf "$(YELLOW)请执行: source ~/.zshrc 或重启终端$(RESET)\n"

##@ 安装

zsh: ## 安装 Zsh 配置
	@printf "$(CYAN)→ 安装 Zsh 配置...$(RESET)\n"
	@bash zsh/install.sh

vim: ## 安装 Vim 配置
	@printf "$(CYAN)→ 安装 Vim 配置...$(RESET)\n"
	@bash vim/install.sh

emacs: ## 安装 Emacs 配置
	@printf "$(CYAN)→ 安装 Emacs 配置...$(RESET)\n"
	@if [ -f emacs/install.sh ]; then \
		bash emacs/install.sh || \
			printf "$(YELLOW)⚠️  Emacs 安装出现警告，请查看日志$(RESET)\n"; \
	else \
		printf "$(YELLOW)⚠️  emacs/install.sh 不存在$(RESET)\n"; \
	fi

wezterm: ## 安装 WezTerm 配置
	@printf "$(CYAN)→ 安装 WezTerm 配置...$(RESET)\n"
	@bash wezterm/install.sh

wezterm-check: ## WezTerm 环境体检
	@printf "$(CYAN)→ WezTerm 环境体检...$(RESET)\n"
	@if [ -f wezterm/check.sh ]; then bash wezterm/check.sh; \
	else printf "$(YELLOW)⚠️  wezterm/check.sh 不存在$(RESET)\n"; fi

wezterm-uninstall: ## 卸载 WezTerm 配置（不含本体）
	@printf "$(CYAN)→ 卸载 WezTerm 配置...$(RESET)\n"
	@if [ -f wezterm/uninstall.sh ]; then bash wezterm/uninstall.sh; \
	else printf "$(YELLOW)⚠️  wezterm/uninstall.sh 不存在$(RESET)\n"; fi

brew: ## 安装 Homebrew 包
	@printf "$(CYAN)→ 安装 Homebrew 包...$(RESET)\n"
	@bash bootstrap.sh --brew

python: ## 配置 Python 环境（uv 优先）
	@printf "$(CYAN)→ 配置 Python 环境...$(RESET)\n"
	@if [ -f python/install.sh ]; then \
		bash python/install.sh || \
			printf "$(YELLOW)⚠️  Python 安装出现警告，请查看日志$(RESET)\n"; \
	else \
		printf "$(YELLOW)⚠️  python/install.sh 不存在$(RESET)\n"; \
	fi

python-check: ## Python 环境体检
	@printf "$(CYAN)→ Python 环境体检...$(RESET)\n"
	@if [ -f python/check.sh ]; then bash python/check.sh; \
	else printf "$(YELLOW)⚠️  python/check.sh 不存在$(RESET)\n"; fi

python-install: ## 仅安装 uv（--uv-only 模式）
	@printf "$(CYAN)→ 安装 uv...$(RESET)\n"
	@if [ -f python/install.sh ]; then bash python/install.sh --uv-only; \
	else printf "$(YELLOW)⚠️  python/install.sh 不存在$(RESET)\n"; fi

python-venv: ## 创建 Python 虚拟环境并安装依赖
	@printf "$(CYAN)→ 创建虚拟环境...$(RESET)\n"
	@if command -v uv > /dev/null 2>&1; then \
		uv venv ~/.venv-dotfiles 2>/dev/null || \
		uv venv --clear ~/.venv-dotfiles 2>/dev/null || \
		uv venv --force ~/.venv-dotfiles 2>/dev/null || \
		python3 -m venv ~/.venv-dotfiles; \
		uv pip install --python ~/.venv-dotfiles/bin/python -r python/requirements.txt && \
		printf "$(GREEN)✅ 虚拟环境创建完成: ~/.venv-dotfiles$(RESET)\n" && \
		printf "$(YELLOW)   激活: source ~/.venv-dotfiles/bin/activate$(RESET)\n"; \
	else \
		python3 -m venv ~/.venv-dotfiles && \
		~/.venv-dotfiles/bin/pip install -r python/requirements.txt && \
		printf "$(GREEN)✅ 虚拟环境创建完成: ~/.venv-dotfiles$(RESET)\n" && \
		printf "$(YELLOW)   激活: source ~/.venv-dotfiles/bin/activate$(RESET)\n"; \
	fi

python-clean: ## 清理 Python 缓存
	@printf "$(CYAN)→ 清理 Python 缓存...$(RESET)\n"
	@if [ -f python/clean.sh ]; then bash python/clean.sh; \
	else printf "$(YELLOW)⚠️  python/clean.sh 不存在$(RESET)\n"; fi

python-upgrade: ## 一键升级 Python 工具链和 CLI 工具
	@printf "$(CYAN)→ 升级 Python 环境...$(RESET)\n"
	@if [ -f python/upgrade.sh ]; then bash python/upgrade.sh; \
	else printf "$(YELLOW)⚠️  python/upgrade.sh 不存在$(RESET)\n"; fi

python-uninstall: ## 卸载 Python 配置（不含 uv 本体）
	@printf "$(CYAN)→ 卸载 Python 配置...$(RESET)\n"
	@if [ -f python/uninstall.sh ]; then bash python/uninstall.sh; \
	else printf "$(YELLOW)⚠️  python/uninstall.sh 不存在$(RESET)\n"; fi

python-pin: ## 固化当前 Python 版本到 versions.lock
	@printf "$(CYAN)→ 固化 Python 版本...$(RESET)\n"
	@if [ -f python/pin.sh ]; then bash python/pin.sh; \
	else printf "$(YELLOW)⚠️  python/pin.sh 不存在$(RESET)\n"; fi

rust: ## 配置 Rust 环境
	@printf "$(CYAN)→ 配置 Rust 环境...$(RESET)\n"
	@if [ -f rust/install.sh ]; then \
		bash rust/install.sh || \
			printf "$(YELLOW)⚠️  Rust 安装出现警告，请查看日志$(RESET)\n"; \
	else \
		printf "$(YELLOW)⚠️  rust/install.sh 不存在$(RESET)\n"; \
	fi

rust-check: ## Rust 环境体检
	@printf "$(CYAN)→ Rust 环境体检...$(RESET)\n"
	@if [ -f rust/check.sh ]; then bash rust/check.sh; \
	else printf "$(YELLOW)⚠️  rust/check.sh 不存在$(RESET)\n"; fi

rust-upgrade: ## 一键升级 Rust 工具链和 cargo 工具
	@printf "$(CYAN)→ 升级 Rust 环境...$(RESET)\n"
	@if [ -f rust/upgrade.sh ]; then bash rust/upgrade.sh; \
	else printf "$(YELLOW)⚠️  rust/upgrade.sh 不存在$(RESET)\n"; fi

rust-clean: ## 清理 Rust 编译缓存
	@printf "$(CYAN)→ 清理 Rust 缓存...$(RESET)\n"
	@if [ -f rust/clean.sh ]; then bash rust/clean.sh; \
	else printf "$(YELLOW)⚠️  rust/clean.sh 不存在$(RESET)\n"; fi

rust-uninstall: ## 卸载 Rust 配置（不含工具链本体）
	@printf "$(CYAN)→ 卸载 Rust 配置...$(RESET)\n"
	@if [ -f rust/uninstall.sh ]; then bash rust/uninstall.sh; \
	else printf "$(YELLOW)⚠️  rust/uninstall.sh 不存在$(RESET)\n"; fi

rust-pin: ## 固化当前 Rust 版本到 versions.lock
	@printf "$(CYAN)→ 固化 Rust 版本...$(RESET)\n"
	@if [ -f rust/pin.sh ]; then bash rust/pin.sh; \
	else printf "$(YELLOW)⚠️  rust/pin.sh 不存在$(RESET)\n"; fi

tmux: ## 安装 Tmux 配置
	@printf "$(CYAN)→ 安装 Tmux 配置...$(RESET)\n"
	@bash bootstrap.sh --tmux

git: ## 安装 Git 配置
	@printf "$(CYAN)→ 安装 Git 配置...$(RESET)\n"
	@bash bootstrap.sh --git

editorconfig: ## 安装 EditorConfig
	@printf "$(CYAN)→ 安装 EditorConfig...$(RESET)\n"
	@bash bootstrap.sh --editorconfig

pwsh: ## 安装 PowerShell 配置（跨平台；无 pwsh 运行时时自动跳过）
	@printf "$(CYAN)→ 安装 PowerShell 配置...$(RESET)\n"
	@bash pwsh/install.sh

pwsh-check: ## PowerShell 环境体检
	@printf "$(CYAN)→ PowerShell 环境体检...$(RESET)\n"
	@if [ -f pwsh/check.sh ]; then bash pwsh/check.sh; \
	else printf "$(YELLOW)⚠️  pwsh/check.sh 不存在$(RESET)\n"; fi

ssh: ## 安装 SSH 配置
	@printf "$(CYAN)→ 安装 SSH 配置...$(RESET)\n"
	@bash ssh/install.sh

ssh-check: ## SSH 环境体检
	@printf "$(CYAN)→ SSH 环境体检...$(RESET)\n"
	@if [ -f ssh/check.sh ]; then bash ssh/check.sh; \
	else printf "$(YELLOW)⚠️  ssh/check.sh 不存在$(RESET)\n"; fi

ssh-uninstall: ## 卸载 SSH 配置（保留密钥与 config.local）
	@printf "$(CYAN)→ 卸载 SSH 配置...$(RESET)\n"
	@if [ -f ssh/uninstall.sh ]; then bash ssh/uninstall.sh; \
	else printf "$(YELLOW)⚠️  ssh/uninstall.sh 不存在$(RESET)\n"; fi

##@ 维护

update: ## 更新配置和插件
	@printf "$(CYAN)→ 更新 Dotfiles...$(RESET)\n"
	@git pull || { printf "$(RED)✗ git pull 失败，请检查网络或手动解决冲突$(RESET)\n"; exit 1; }
	@printf "$(CYAN)→ 更新 Zinit 插件...$(RESET)\n"
	@zsh -ic 'zinit update' 2>/dev/null || printf "$(YELLOW)⚠  Zinit 更新失败，请手动执行: zinit update$(RESET)\n"
	@printf "$(CYAN)→ 更新 Homebrew...$(RESET)\n"
	@brew update && brew upgrade 2>/dev/null || printf "$(YELLOW)⚠  Homebrew 更新失败，请手动执行: brew update && brew upgrade$(RESET)\n"
	@printf "$(GREEN)✓ 更新完成！$(RESET)\n"

backup: ## 备份当前配置
	@printf "$(CYAN)→ 备份配置到 ~/.dotfiles_backup...$(RESET)\n"
	@backup_dir="$$HOME/.dotfiles_backup_$$(date +%Y%m%d_%H%M%S)"; \
	mkdir -p "$$backup_dir"; \
	for f in .zshrc .vimrc .tmux.conf .gitconfig .gitignore_global .editorconfig .wezterm.lua; do \
		[ -e "$$HOME/$$f" ] && cp -L "$$HOME/$$f" "$$backup_dir/" 2>/dev/null; \
	done; \
	command -v brew >/dev/null 2>&1 && brew bundle dump --force --file="$$backup_dir/Brewfile.backup" 2>/dev/null; \
	printf "$(GREEN)✅ 备份完成：$$backup_dir$(RESET)\n"

##@ 诊断

test: ## 运行静态测试
	@bash tests/test_install.sh static

check: ## 快速环境检查
	@zsh -ic 'check_env' 2>/dev/null || printf "请先安装配置: make install\n"

# 各模块环境体检（委托模块 check.sh；check.sh 设计为 warn 不 fail）
brew-check: ## Homebrew 模块体检
	@bash brew/check.sh

git-check: ## Git 模块体检
	@bash git/check.sh

tmux-check: ## Tmux 模块体检
	@bash tmux/check.sh

vim-check: ## Vim 模块体检
	@bash vim/check.sh

zsh-check: ## Zsh 模块体检
	@bash zsh/check.sh

doctor: ## 全模块环境体检（汇总报告，单模块失败不中断）
	@printf "$(BOLD)=== Dotfiles 全模块体检 ===$(RESET)\n"; \
	fail=0; \
	for m in brew zsh vim git tmux ssh wezterm python rust pwsh; do \
		printf "\n$(CYAN)── %s ──$(RESET)\n" "$$m"; \
		bash "$$m/check.sh" || fail=$$((fail + 1)); \
	done; \
	printf "\n$(BOLD)==========================$(RESET)\n"; \
	if [ $$fail -gt 0 ]; then \
		printf "$(YELLOW)⚠  $$fail 个模块存在失败项（多为当前机器未安装该工具）$(RESET)\n"; \
	else \
		printf "$(GREEN)✓ 全部模块体检通过$(RESET)\n"; \
	fi; \
	printf "$(BOLD)另请运行:$(RESET) make validate（配置语法）与 make test（静态断言）\n"

perf: ## 性能分析
	@zsh zsh/profile_performance.sh

validate: ## 验证配置语法
	@bash validate.sh

##@ Docker

docker-build: ## 构建 Docker dev 镜像
	@bash docker/build.sh build dev

docker-up: ## 启动 Docker dev 容器（交互式 shell）
	@bash docker/build.sh shell dev

docker-test: ## 运行 Docker 集成测试
	@bash docker/build.sh test

docker-validate: ## 运行 Docker 静态验证
	@bash docker/build.sh validate

docker-clean: ## 清理所有 Docker 资源
	@bash docker/build.sh clean

clean: ## 清理缓存
	@printf "$(CYAN)→ 清理缓存...$(RESET)\n"
	@rm -rf ~/.cache/zsh/zcompdump* 2>/dev/null; true
	@brew cleanup 2>/dev/null || true
	@zsh -ic 'zinit delete --all' 2>/dev/null || true
	@printf "$(GREEN)✅ 清理完成！$(RESET)\n"
