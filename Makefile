# ======================
# Dotfiles Makefile
# ======================
# 统一命令入口，简化操作
# 设计原则：所有 target 都委托给 per-component install.sh，避免与 bootstrap.sh 逻辑漂移

.PHONY: install update backup test check clean help zsh vim emacs wezterm brew python rust tmux git editorconfig rust-check rust-upgrade rust-clean rust-uninstall rust-pin

# 默认目标
.DEFAULT_GOAL := help

# 颜色定义（printf 格式串使用，避免 echo -e 跨 shell 不一致）
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
	@printf "  make check        # 检查环境状态\n"
	@printf "  make update       # 更新配置和插件\n"

install: zsh vim emacs wezterm brew python rust tmux git editorconfig ## 一键安装所有配置（推荐）
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

brew: ## 安装 Homebrew 包
	@printf "$(CYAN)→ 安装 Homebrew 包...$(RESET)\n"
	@bash bootstrap.sh --brew

python: ## 配置 Python 环境（PEP 668 兼容）
	@printf "$(CYAN)→ 配置 Python 环境...$(RESET)\n"
	@if [ -f python/requirements.txt ]; then \
		if pip3 install --dry-run "pip" 2>&1 | grep -qi "externally-managed"; then \
			if command -v pipx > /dev/null 2>&1; then \
				printf "$(YELLOW)ℹ️  检测到 PEP 668 外部管理环境，改用 pipx$(RESET)\n"; \
				pipx install --include-deps -r python/requirements.txt || \
					printf "$(YELLOW)⚠️  部分 Python 依赖安装失败$(RESET)\n"; \
			else \
				printf "$(YELLOW)⚠️  检测到 PEP 668 外部管理环境$(RESET)\n"; \
				printf "$(YELLOW)   建议安装 pipx:  brew install pipx  或  apt install pipx$(RESET)\n"; \
				printf "$(YELLOW)   或在虚拟环境中安装:  python3 -m venv ~/.venv && pip install -r python/requirements.txt$(RESET)\n"; \
			fi; \
		else \
			pip3 install --user -r python/requirements.txt || \
				printf "$(YELLOW)⚠️  部分 Python 依赖安装失败$(RESET)\n"; \
		fi; \
	fi

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

##@ 维护

update: ## 更新配置和插件
	@printf "$(CYAN)→ 更新 Dotfiles...$(RESET)\n"
	@git pull
	@printf "$(CYAN)→ 更新 Zinit 插件...$(RESET)\n"
	@zsh -ic 'zinit update' 2>/dev/null || true
	@printf "$(CYAN)→ 更新 Homebrew...$(RESET)\n"
	@brew update && brew upgrade 2>/dev/null || true
	@printf "$(GREEN)✅ 更新完成！$(RESET)\n"

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

test: ## 运行测试
	@bash test_install.sh static

check: ## 环境检查
	@zsh -ic 'check_env' 2>/dev/null || printf "请先安装配置: make install\n"

perf: ## 性能分析
	@zsh zsh/profile_performance.sh

validate: ## 验证配置语法
	@bash validate.sh

clean: ## 清理缓存
	@printf "$(CYAN)→ 清理缓存...$(RESET)\n"
	@rm -rf ~/.cache/zsh/zcompdump* 2>/dev/null; true
	@brew cleanup 2>/dev/null || true
	@zsh -ic 'zinit delete --all' 2>/dev/null || true
	@printf "$(GREEN)✅ 清理完成！$(RESET)\n"
