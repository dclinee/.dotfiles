# 贡献指南

## 开发流程

1. Fork 本仓库
2. 创建功能分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 打开 Pull Request

## 代码规范

- 脚本使用 bash 或 zsh，添加 shebang
- 函数和变量命名使用 snake_case
- 添加必要的注释
- 保持代码简洁易读

## 测试

- 运行 `./validate.sh` 验证配置
- 在不同平台测试（Linux, macOS）
- 检查语法错误 (`shellcheck` 等工具)
