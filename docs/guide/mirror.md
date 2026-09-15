# 国内镜像

国内访问 GitHub、Homebrew、Emacs 包等资源缓慢，安装脚本已内置镜像降级策略，无需额外配置。

## 镜像源清单

| 资源 | 主源 | 镜像/回退 |
|------|------|----------|
| Homebrew bottles | formulae.brew.sh | USTC 镜像 |
| Emacs 包 (gnu/nongnu/melpa) | elpa.gnu.org | 清华镜像 |
| GitHub raw | raw.githubusercontent.com | ghproxy.net → gh-proxy.com |
| GitHub releases | github.com/.../releases | ghproxy.net → gh-proxy.com |
| zinit 插件 | github.com | ghfast.top → ghproxy.net |
| vim-plug | github.com | gh-proxy.com |
| Starship 安装脚本 | starship.rs | gh-proxy.com |
| Nerd Font | github.com releases | ghproxy.net |

## 回退策略

所有外部下载采用三级回退：

```
原始源 (GitHub/starship.rs)
    │ 超时/失败
    ▼
镜像 1 (ghproxy.net / ghfast.top)
    │ 超时/失败
    ▼
镜像 2 (gh-proxy.com)
```

每级都设置超时控制（`--connect-timeout 15 --max-time 60`），避免单点失败阻塞安装。

## 安全验证

所有通过 `curl | sh` 执行的脚本（Homebrew 安装脚本、Starship 安装脚本）都经过 SHA256 哈希验证，确保镜像内容未被篡改。

```bash
# 下载到临时文件 → 验证 SHA256 → 执行
curl -fsSL -o /tmp/install.sh https://...
echo "<expected-sha256>  /tmp/install.sh" | sha256sum -c -
bash /tmp/install.sh
```

## 手动指定镜像

如需覆盖默认镜像，可通过环境变量：

```bash
# 示例：使用自定义 GitHub 代理
export DOTFILES_GH_PROXY=https://your-proxy.example.com/
./bootstrap.sh
```

:::warning 注意
镜像源可能不同步最新版本。如遇版本过旧问题，可临时取消镜像：

```bash
export DOTFILES_NO_MIRROR=1
./bootstrap.sh
```
:::
