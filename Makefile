# ======================
# Dotfiles Makefile
# ======================
# 统一命令入口，简化操作

.PHONY: install update backup test check clean help zsh vim emacs wezterm brew python rust tmux git

# 默认目标
.DEFAULT_GOAL := help

# 颜色定义
CYAN  := \033[36m
GREEN := \033[32m
YELLOW := \033[33m
RESET := \033[0m
BOLD  := \033[1m

##@ 通用

help: ## 显示帮助信息
	@echo -e "$(BOLD)Dotfiles 管理命令$(RESET)"
	@echo ""
	@echo -e "$(CYAN)用法:$(RESET) make [target]"
	@echo ""
	@echo -e "$(CYAN)目标:$(RESET)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-15s$(RESET) %s\n", $$1, $$2}'
	@echo ""
	@echo -e "$(CYAN)示例:$(RESET)"
	@echo "  make install      # 一键安装所有配置"
	@echo "  make check        # 检查环境状态"
	@echo "  make update       # 更新配置和插件"

install: zsh vim emacs wezterm brew python rust tmux git ## 一键安装所有配置（推荐）
	@echo ""
	@echo -e "$(GREEN)✅ 所有配置安装完成！$(RESET)"
	@echo -e "$(YELLOW)请执行: source ~/.zshrc 或重启终端$(RESET)"

##@ 安装

zsh: ## 安装 Zsh 配置
	@echo -e "$(CYAN)→ 安装 Zsh 配置...$(RESET)"
	@bash zsh/install.sh

vim: ## 安装 Vim 配置
	@echo -e "$(CYAN)→ 安装 Vim 配置...$(RESET)"
	@bash vim/install.sh

emacs: ## 安装 Emacs 配置
	@echo -e "$(CYAN)→ 安装 Emacs 配置...$(RESET)"
	@if [ -f emacs/install.sh ]; then \
		bash emacs/install.sh || \
			echo -e "$(YELLOW)⚠️  Emacs 安装出现警告，请查看日志$(RESET)"; \
	else \
		echo -e "$(YELLOW)⚠️  emacs/install.sh 不存在$(RESET)"; \
	fi

wezterm: ## 安装 WezTerm 配置
	@echo -e "$(CYAN)→ 安装 WezTerm 配置...$(RESET)"
	@bash wezterm/install.sh

brew: ## 安装 Homebrew 包
	@echo -e "$(CYAN)→ 安装 Homebrew 包...$(RESET)"
	@if command -v brew > /dev/null 2>&1; then \
		brew bundle --file brew/Brewfile; \
		case "$$(uname -s)" in \
			Linux)  [ -f brew/Brewfile.linux ]  && brew bundle --file brew/Brewfile.linux  || true ;; \
			Darwin) [ -f brew/Brewfile.macos ]  && brew bundle --file brew/Brewfile.macos  || true ;; \
		esac; \
	else \
		echo -e "$(YELLOW)⚠️  Homebrew 未安装，请先运行: make zsh$(RESET)"; \
	fi

python: ## 配置 Python 环境
	@echo -e "$(CYAN)→ 配置 Python 环境...$(RESET)"
	@if [ -f python/requirements.txt ]; then \
		pip_args="--user"; \
		if pip3 install --dry-run "pip" 2>&1 | grep -qi "externally-managed"; then \
			pip_args="--user --break-system-packages"; \
			echo -e "$(YELLOW)⚠️  检测到外部管理环境，使用 --break-system-packages$(RESET)"; \
		fi; \
		pip3 install $${pip_args} -r python/requirements.txt || \
			echo -e "$(YELLOW)⚠️  部分 Python 依赖安装失败$(RESET)"; \
	fi

rust: ## 配置 Rust 环境
	@echo -e "$(CYAN)→ 配置 Rust 环境...$(RESET)"
	@if [ -f rust/install.sh ]; then \
		bash rust/install.sh || \
			echo -e "$(YELLOW)⚠️  Rust 安装出现警告，请查看日志$(RESET)"; \
	else \
		echo -e "$(YELLOW)⚠️  rust/install.sh 不存在$(RESET)"; \
	fi

tmux: ## 安装 Tmux 配置
	@echo -e "$(CYAN)→ 安装 Tmux 配置...$(RESET)"
	@ln -sf $(PWD)/tmux/.tmux.conf $(HOME)/.tmux.conf
	@echo -e "$(GREEN)✅ Tmux 配置已链接$(RESET)"

git: ## 安装 Git 配置
	@echo -e "$(CYAN)→ 安装 Git 配置...$(RESET)"
	@ln -sf $(PWD)/git/.gitconfig $(HOME)/.gitconfig
	@ln -sf $(PWD)/git/.gitignore_global $(HOME)/.gitignore_global
	@echo -e "$(GREEN)✅ Git 配置已链接$(RESET)"
	@echo -e "$(YELLOW)请在 ~/.gitconfig.local 中设置你的 name 和 email$(RESET)"

##@ 维护

update: ## 更新配置和插件
	@echo -e "$(CYAN)→ 更新 Dotfiles...$(RESET)"
	@git pull
	@echo -e "$(CYAN)→ 更新 Zinit 插件...$(RESET)"
	@zsh -ic 'zinit update' 2>/dev/null || true
	@echo -e "$(CYAN)→ 更新 Homebrew...$(RESET)"
	@brew update && brew upgrade 2>/dev/null || true
	@echo -e "$(GREEN)✅ 更新完成！$(RESET)"

backup: ## 备份当前配置
	@echo -e "$(CYAN)→ 备份配置到 ~/.dotfiles_backup...$(RESET)"
	@backup_dir="$$HOME/.dotfiles_backup_$$(date +%Y%m%d_%H%M%S)"; \
	mkdir -p "$$backup_dir"; \
	[ -f "$$HOME/.zshrc" ] && cp "$$HOME/.zshrc" "$$backup_dir/" 2>/dev/null; \
	[ -f "$$HOME/.vimrc" ] && cp "$$HOME/.vimrc" "$$backup_dir/" 2>/dev/null; \
	[ -f "$$HOME/.tmux.conf" ] && cp "$$HOME/.tmux.conf" "$$backup_dir/" 2>/dev/null; \
	[ -f "$$HOME/.gitconfig" ] && cp "$$HOME/.gitconfig" "$$backup_dir/" 2>/dev/null; \
	command -v brew >/dev/null 2>&1 && brew bundle dump --force --file="$$backup_dir/Brewfile.backup" 2>/dev/null; \
	echo -e "$(GREEN)✅ 备份完成：$$backup_dir$(RESET)"

##@ 诊断

test: ## 运行测试
	@bash test_install.sh static

check: ## 环境检查
	@zsh -ic 'check_env' 2>/dev/null || echo "请先安装配置: make install"

perf: ## 性能分析
	@zsh zsh/profile_performance.sh

validate: ## 验证配置语法
	@bash validate.sh

clean: ## 清理缓存
	@echo -e "$(CYAN)→ 清理缓存...$(RESET)"
	@rm -rf ~/.cache/zsh/zcompdump* 2>/dev/null; true
	@brew cleanup 2>/dev/null || true
	@zsh -ic 'zinit delete --all' 2>/dev/null || true
	@echo -e "$(GREEN)✅ 清理完成！$(RESET)"
