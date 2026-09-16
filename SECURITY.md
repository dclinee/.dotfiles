# 安全策略

本项目是一个个人 dotfiles 配置仓库，不直接部署到任何生产环境。

## 报告漏洞

如果你在本仓库中发现安全问题（如硬编码的凭据、危险的 shell 命令、误导性的 hook 脚本等），请通过以下方式披露：

- **GitHub Issues**：开启标签 `security` 的 Issue
- **邮件**：直接联系仓库所有者

## 已采取的措施

- `.gitignore` 排除了 `.env`、`.env.local`、`.env.*.local`、`.codeartsdoer/`、`.pem`、`.key`、`.crt`、`*.local` 等敏感文件
- Git 配置使用 `.gitconfig.local` 存储个人信息，不提交到仓库
- SSH 配置使用 `config.local` 存储主机别名和密钥路径
- `safe_symlink` 函数防止覆盖已有配置文件
- `curl | sh` 模式已统一改为先下载到临时文件再执行
- 国内镜像源切换受 `NO_MIRROR=1` 环境变量控制，可回退官方源

## 范围声明

本仓库不包含可执行的生产代码、二进制构建产物或服务端组件。安全问题的影响范围限于仓库所有者的本地开发环境。
