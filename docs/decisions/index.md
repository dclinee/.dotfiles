# 架构决策记录 (ADR)

架构决策记录（Architecture Decision Records）沉淀了本项目关键设计选择的背景、决策与后果，便于新贡献者快速理解项目演进历史。

## 决策清单

| 编号 | 标题 | 日期 | 状态 |
|------|------|------|------|
| [ADR-001](/decisions/adr-001) | 使用 bootstrap.sh 作为主安装入口 | 2025-01-01 | 已接受 |
| [ADR-002](/decisions/adr-002) | 分层安装顺序（基础→编辑器→终端→开发） | 2025-06-01 | 已接受 |
| [ADR-003](/decisions/adr-003) | 使用 zinit 而非手动 git clone 管理插件 | 2025-01-15 | 已接受 |
| [ADR-004](/decisions/adr-004) | 配置文件模块化为 core/platform/ftplugin 分层 | 2025-02-01 | 已接受 |
| [ADR-005](/decisions/adr-005) | 使用 safe_symlink 统一符号链接管理 | 2025-01-20 | 已接受 |
| [ADR-006](/decisions/adr-006) | Git 凭证使用 cache 而非 store | 2025-07-01 | 已接受 |
| [ADR-007](/decisions/adr-007) | 国内镜像源 + 代理回退策略 | 2025-03-01 | 已接受 |
| [ADR-008](/decisions/adr-008) | COMPLETED/FAILED 步骤追踪机制 | 2025-04-01 | 已接受 |
| [ADR-009](/decisions/adr-009) | Vim 9+ 兼容性：禁用 \ 行连续 | 2025-05-01 | 已接受 |
| [ADR-010](/decisions/adr-010) | Brew bundle 分层文件策略 | 2025-06-15 | 已接受 |

## 模板

新增 ADR 时建议遵循以下结构：

- **状态**：已接受 / 已废弃 / 已替代
- **日期**：YYYY-MM-DD
- **背景**：决策所解决的问题与上下文
- **决策**：做出的选择及理由
- **后果**：优点与缺点

## 相关文档

- [架构总览](/architecture/overview) — 系统架构图与加载流程
- [分层安装策略](/architecture/install-order) — 模块依赖与四层安装顺序
