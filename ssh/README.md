# SSH 模块

跨平台、多机通用的 SSH 客户端配置，通过 `Include` 分片管理，机器差异与仓库配置彻底分离。

## 目录结构

```
ssh/
├── config                  # 主入口（软链到 ~/.ssh/config），只做 Include
├── config.d/
│   ├── 10-core.conf        # 通用默认值（保活 / 连接复用 / 安全基线）
│   ├── 20-github.conf      # GitHub 走 ssh.github.com:443 加速
│   └── 30-hosts.conf       # 跨机器共享的主机模板（占位符）
├── platform/
│   ├── macos.conf          # macOS 专属（UseKeychain 钥匙串）
│   └── linux.conf          # Linux 专属
├── install.sh              # 安装器（软链 + 目录 + 权限 + config.local 模板）
├── check.sh                # 环境体检（软链 / 语法 / 权限 / 密钥）
├── uninstall.sh            # 卸载器（保留密钥与 config.local）
└── _common.sh              # 公共加载器（委托 lib/common.sh）
```

## 加载顺序

```
~/.ssh/config (软链)
  ├── Include ~/.dotfiles/ssh/config.d/*.conf    # 通用片段
  ├── Include ~/.dotfiles/ssh/platform/*.conf    # 平台片段
  └── Include ~/.ssh/config.local                # 本机私有覆盖（不提交仓库）
```

> ssh 对同一选项取"首次出现"的值：通用片段优先级最高，`config.local` 只能补充或新增主机，不能覆盖通用默认值。

## 安装

```bash
bash ssh/install.sh              # 常规安装
bash ssh/install.sh --gen-key    # 安装 + 生成本机 ed25519 密钥
bash ssh/check.sh                # 环境体检
bash ssh/uninstall.sh            # 卸载（保留密钥）
```

或通过 Makefile：`make ssh` / `make ssh-check` / `make ssh-uninstall`。

## 多台计算机的使用方式

| 内容 | 存放位置 | 是否提交仓库 |
|---|---|---|
| 通用默认值、公共主机 | `ssh/config.d/` | 是 |
| 平台专属选项 | `ssh/platform/` | 是 |
| 本机专属主机、独立密钥 | `~/.ssh/config.local` | 否 |
| 密钥对（每台机器独立） | `~/.ssh/id_ed25519*` | 否 |

1. 每台新机器执行 `bash ssh/install.sh --gen-key`，生成带 `用户@主机名` 注释的独立密钥；
2. 将 `~/.ssh/id_ed25519.pub` 添加到 GitHub → SSH keys（或远程服务器 `authorized_keys`）；
3. 机器差异写入 `~/.ssh/config.local`，仓库配置保持纯净，`git pull` 即可同步所有机器。

## GitHub 加速（SSH over 443）

`config.d/20-github.conf` 将 `github.com` 指向 `ssh.github.com:443`，绕开受限的 22 端口：

```bash
git remote set-url origin git@github.com:<user>/<repo>.git
ssh -T git@github.com   # 预期输出: Hi <user>!
```

## 平台兼容说明

macOS 的 `UseKeychain` 在 Linux 上会报"未知选项"，因此 `platform/macos.conf`
中先声明 `IgnoreUnknown UseKeychain`——Linux 的 OpenSSH 会安全跳过该选项，
同一份配置无需修改即可在 macOS / Linux 双平台使用。
