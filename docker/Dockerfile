# ============================================================
# Dotfiles 开发环境 Dockerfile
# ============================================================
#
# 多阶段构建，产出一个预装完整 dotfiles 配置的开发容器：
#   Stage 1 (base)  — 安装所有工具链（zsh/vim/emacs/tmux/python/rust 等）
#   Stage 2 (final) — 复制 dotfiles 仓库 + 运行 bootstrap.sh --all
#
# 使用方法：
#   # 本地构建（默认启用 USTC 镜像加速）
#   docker build -f docker/Dockerfile -t dotfiles-dev .
#
#   # 官方源构建
#   NO_MIRROR=1 docker build -f docker/Dockerfile -t dotfiles-dev .
#
#   # 运行
#   docker run --rm -it dotfiles-dev
#
# 环境变量（构建时 --build-arg 传入）：
#   BASE_IMAGE    基础镜像 (默认 ubuntu:24.04)
#   APT_MIRROR    apt 镜像前缀 (默认 USTC，空则用官方源)
#   DOTFILES_USER 容器内用户名 (默认 dotfiles-dev)
#   NO_MIRROR     设为 1 禁用所有镜像源

# ============================================================
# Stage 1: 工具链基础镜像
# ============================================================
ARG BASE_IMAGE=ubuntu:24.04
FROM ${BASE_IMAGE} AS base

ARG APT_MIRROR=https://mirrors.ustc.edu.cn/ubuntu
ARG NO_MIRROR=0

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Asia/Shanghai

# 换 apt 镜像源（仅当 APT_MIRROR 非空且 NO_MIRROR!=1 时执行）
RUN if [[ "${APT_MIRROR}" != "" && "${NO_MIRROR}" != "1" ]]; then \
      sed -i "s|http://archive.ubuntu.com/ubuntu|${APT_MIRROR}|g" /etc/apt/sources.list.d/ubuntu.sources 2>/dev/null \
      || sed -i "s|http://archive.ubuntu.com/ubuntu|${APT_MIRROR}|g" /etc/apt/sources.list 2>/dev/null \
      || true; \
    fi

# 安装基础依赖 + dotfiles 需要的所有工具
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        # 基础
        ca-certificates curl wget git locales tzdata \
        procps lsof unzip zip jq tree \
        # Shell / 编辑器
        zsh zsh-syntax-highlighting zsh-autosuggestions \
        vim neovim \
        tmux \
        # Python
        python3 python3-pip python3-venv python3-dev \
        # 构建工具（用于 emacs / rust 等编译）
        build-essential cmake pkg-config \
        libssl-dev libreadline-dev libffi-dev libsqlite3-dev \
        libjansson-dev libjpeg-dev libpng-dev librsvg2-dev \
        libxml2-dev libxslt1-dev libtool-bin \
        # Emacs 依赖
        emacs-nox \
        # Rust（通过 rustup 安装在 final stage，这里只装 curl）
        # SSH
        openssh-client \
        # Tmux 插件
        xclip \
    && rm -rf /var/lib/apt/lists/*

# 生成中文 UTF-8 语言环境
RUN locale-gen zh_CN.UTF-8
ENV LANG=zh_CN.UTF-8 \
    LC_ALL=zh_CN.UTF-8 \
    LANGUAGE=zh_CN:zh

# 创建非 root 用户
ARG DOTFILES_USER=dotfiles-dev
ARG DOTFILES_UID=1000
RUN useradd -m -s /usr/bin/zsh -u "${DOTFILES_UID}" "${DOTFILES_USER}" \
    && echo "${DOTFILES_USER} ALL=(ALL) NOPASSWD: /usr/bin/apt-get, /usr/bin/apt, /usr/bin/dpkg" > /etc/sudoers.d/dotfiles \
    && chmod 440 /etc/sudoers.d/dotfiles

# ============================================================
# Stage 2: 安装 dotfiles 配置
# ============================================================
FROM base AS final

ARG DOTFILES_USER=dotfiles-dev
ARG NO_MIRROR=0

USER root
WORKDIR /tmp

# 复制整个 dotfiles 仓库（.dockerignore 排除 node_modules / elpa-* 等）
COPY --chown="${DOTFILES_USER}:${DOTFILES_USER}" . /home/"${DOTFILES_USER}"/.dotfiles

# 确保 install.sh 可执行
RUN find /home/"${DOTFILES_USER}"/.dotfiles -name 'install.sh' -exec chmod +x {} \;

USER "${DOTFILES_USER}"
WORKDIR /home/"${DOTFILES_USER}"

# 运行 dotfiles 安装（brew 安装会失败，跳过；其他模块正常安装）
ENV NO_MIRROR="${NO_MIRROR}" \
    NO_BREW=1
RUN bash ~/.dotfiles/bootstrap.sh --all 2>&1 || \
    bash ~/.dotfiles/bootstrap.sh --zsh --vim --emacs --tmux --git --ssh --python --rust 2>&1 || true

# 默认入口：交互式 zsh
CMD ["zsh", "-l"]
