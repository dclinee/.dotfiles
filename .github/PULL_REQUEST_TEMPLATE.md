<!--
  感谢你提交 Pull Request！为了让你的 PR 更容易被评审，请按以下模板填写。
  填写完毕后，删除方括号内的提示文字。

  Conventional Commits 推荐的类型:
    feat:     新功能
    fix:      缺陷修复
    docs:     文档变更
    style:    格式/空格/样式（不影响功能）
    refactor: 重构（不修复 bug、不加功能）
    perf:     性能优化
    test:     测试相关
    chore:    构建/CI/工具链维护
    ci:       CI/CD 变更
    build:    构建脚本/依赖变更
    revert:   回滚
    hotfix:   紧急修复
-->

## 描述
<!--
  一句话概述此 PR 的目的。
  如需展开，请在下方"更多细节"处说明。
-->

## 关联 Issue
<!-- 无则填 N/A -->
- Fixes: #N/A
- Related: <!-- 相关 Issue/讨论链接 -->

## 变更类型
<!-- 在对应选项前打 [x] -->
- [ ] **feat**: 新功能
- [ ] **fix**: 缺陷修复
- [ ] **docs**: 文档
- [ ] **style**: 格式/样式
- [ ] **refactor**: 重构
- [ ] **perf**: 性能优化
- [ ] **test**: 测试
- [ ] **chore**: 构建/CI/工具链
- [ ] **ci**: CI/CD
- [ ] **build**: 构建脚本/依赖
- [ ] **revert**: 回滚
- [ ] **hotfix**: 紧急修复

## 变更范围 (Scope)
<!-- 填受影响模块，如: bootstrap/zsh/vim/emacs/wezterm/brew/python/rust/tmux/git/docs/ci -->
- Scope: `<!-- 例如: bootstrap, zsh, ci -->`

## 破坏性变更
<!-- 是否有 BREAKING CHANGE？
     如果是，请在下一节详细描述迁移步骤。 -->
- [ ] 是
- [ ] 否

## 变更详情

### 新增
<!-- 新增了什么 -->
1.

### 修改
<!-- 修改了什么 -->
1.

### 修复
<!-- 修复了什么问题 -->
1.

## 测试计划
<!-- 如何验证？至少勾选本地验证 -->
- [ ] 本地执行过：`./validate.sh`
- [ ] 本地执行过：`./test_install.sh static`
- [ ] 本地执行过：`./bootstrap.sh --all` 或 `./bootstrap.sh --<模块>`
- [ ] 本地执行过：`bash -n` 对修改的脚本做语法检查
- [ ] 本地执行过：`make check`
- [ ] 集成测试：`./test_integration.sh` 或 Docker 测试
- [ ] 依赖 CI 通过（勾选后等待 CI 反馈）

## 回滚方案
<!-- 如出现问题如何回滚？ -->
- [ ] 可以安全 `git revert <commit>` 回滚
- [ ] 可能需要手动恢复配置文件：<!-- 说明哪些文件 -->
- [ ] 其他：<!-- 说明 -->

## 截图 / 演示
<!-- 可选。重要 UI/配置变更建议添加 -->
- [ ] 不适用
- [ ] 已附加（粘贴图片或链接）

##  Checklist
<!-- 提交前自检 -->
- [ ] 本 PR **没有硬编码的用户名/邮箱/路径/Token**
- [ ] 本 PR **不修改 `.gitconfig` 中的用户信息**（个人配置放 `.gitconfig.local`）
- [ ] 新增脚本含有 `#!/usr/bin/env bash` 开头
- [ ] 新增脚本含有 `set -euo pipefail`（或已标注"库文件，由调用者设置"）
- [ ] 新增命令调用前有 `command -v` 存在性检查
- [ ] Git Hooks：`pre-commit` / `commit-msg` / `pre-push` 检查通过
- [ ] 变更说明在 [CHANGELOG.md](../CHANGELOG.md) 的 Unreleased 部分已更新
- [ ] 涉及模块变更时，对应模块 `README.md` 已更新
