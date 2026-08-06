# Dotfiles 性能优化方案

> 生成时间: 2026-08-06 15:40:57  
> 目标: 将冷启动降至 300ms 以下，热启动降至 120ms 以下

---

## 一、基线数据

### 1.1 当前性能指标

| 指标 | 测量值 | 测量条件 |
|------|--------|----------|
| 冷启动（清理缓存后） | **466ms** | 5 次平均，range 450-501ms |
| 热启动（缓存命中） | **223ms** | 5 次平均，range 215-233ms |
| 插件禁用基线 | **95ms** | 5 次平均，range 92-101ms |
| 插件加载开销 | **128ms** | 热启动 - 基线 |
| 冷→热加速比 | **52%** | 243ms 差异 |

### 1.2 核心文件加载耗时

| 文件 | 耗时 | 占热启动比例 | 说明 |
|------|------|-------------|------|
| `00_env.zsh` | 44ms | 19.7% | 环境变量 + brew --prefix + PYTHONPATH |
| `01_options.zsh` | 46ms | 20.6% | compinit + zstyle + setopt |
| `02_aliases.zsh` | 14ms | 6.3% | 别名定义（eza 检测） |
| `03_functions.zsh` | 15ms | 6.7% | 自定义函数 |
| `04_plugins.zsh` | **128ms** | **57.4%** | zinit + 4 同步插件 + 2 懒加载 |
| `05_starship.zsh` | 36ms | 16.1% | 字体检测 + starship init |

> ⚠️ 注：各文件独立加载耗时之和 > 总启动时间，因为独立测量包含子 shell 开销

### 1.3 关键命令耗时

| 命令 | 耗时 | 说明 |
|------|------|------|
| `brew --prefix` | **25ms** | ⚠️ 每次启动都调用，.zshenv 已设置 HOMEBREW_PREFIX |
| `brew --prefix zinit` | **25ms** | ⚠️ 插件加载时再次调用 brew |
| `compinit`（缓存命中） | 119ms | 最大单一开销 |
| `starship init zsh` | 11ms | 已优化 |
| `eza --version` | 63ms | 仅手动调用时，启动时不触发 |

---

## 二、瓶颈分析

### 🔴 P0 - 最高优先级

#### 瓶颈 1：冗余 `brew --prefix` 调用（节省 ~50ms）

**位置**: `zsh/core/00_env.zsh:18` 和 `zsh/core/04_plugins.zsh:39`

**问题**: 
- `.zshenv` 已经在所有 zsh 会话最开始设置了 `HOMEBREW_PREFIX`
- `00_env.zsh` 中再次调用 `brew --prefix` 完全冗余
- `04_plugins.zsh` 中 `brew --prefix zinit` 用于查找 zinit.zsh 路径，但 zinit 通常安装在固定位置

**优化方案**:
1. `00_env.zsh` 直接使用已有的 `HOMEBREW_PREFIX`，不再调用 `brew --prefix`
2. `04_plugins.zsh` 将 `brew --prefix zinit` 移到查找列表最后（作为 fallback），优先检查固定路径

**预期收益**: 热启动 -50ms → 173ms | 冷启动 -50ms → 416ms

#### 瓶颈 2：compinit 优化（节省 ~60ms 热启动，~150ms 冷启动）

**位置**: `zsh/core/01_options.zsh:30-34`

**问题**:
- `compinit -C`（缓存命中）仍需 119ms，因为 compdump 文件较大（52KB）
- `compinit -u`（重建）需要重新扫描所有补全函数
- 当前按日期判断是否重建，但每天首次启动仍需重建

**优化方案**:
1. 延长 compdump 缓存有效期（从 1 天改为 7 天或基于 mtime 变化判断）
2. 使用 `compinit -C -d` 时指定 `$ZSH_COMPDUMP` 路径并启用 `skip` 模式
3. 预生成 compdump 并随仓库分发（可选）
4. 使用 `zcompdump` 插件替代原生 compinit（提供更智能的缓存管理）

**预期收益**: 热启动 -60ms → 113ms | 冷启动 -150ms → 316ms

### 🟡 P1 - 高优先级

#### 瓶颈 3：插件懒加载扩展（节省 ~40ms）

**位置**: `zsh/core/04_plugins.zsh:78-93`

**问题**:
- 当前 4 个插件同步加载：zsh-autosuggestions、forgit、zsh-history-substring-search、zsh-z
- 其中 forgit（git 增强）和 zsh-z（目录跳转）可延迟加载
- zoxide init 在启动时同步 source

**优化方案**:
1. forgit → 改为 `zinit ice wait lucid` 懒加载
2. zsh-z → 改为 `zinit ice wait lucid` 懒加载（zoxide 已提供相同功能）
3. zsh-history-substring-search → 保持同步（核心功能）
4. zsh-autosuggestions → 保持同步（核心功能）
5. zoxide init → 改为首次调用 `z` 时 source

**预期收益**: 热启动 -40ms → 133ms

#### 瓶颈 4：HOMEBREW_PREFIX 直接硬编码（节省 ~5ms）

**位置**: `zsh/core/00_env.zsh:17-19`

**问题**:
- `command -v brew` 检查 + `brew --prefix` 调用 = ~25ms
- .zshenv 已保证 `HOMEBREW_PREFIX` 被设置

**优化方案**:
```zsh
# 直接使用 .zshenv 中已设置的 HOMEBREW_PREFIX
# 仅在未设置时才 fallback 检测
if [[ -z "${HOMEBREW_PREFIX:-}" ]] && command -v brew >/dev/null 2>&1; then
  export HOMEBREW_PREFIX="$(brew --prefix 2>/dev/null || echo '')"
fi
```

**预期收益**: 热启动 -5ms

### 🟢 P2 - 中优先级

#### 瓶颈 5：字体检测优化（节省 ~10ms 首次启动）

**位置**: `zsh/core/05_starship.zsh:17-64`

**问题**:
- 首次启动时字体检测需要 `fc-list` + 多目录 `find`
- 已有每日缓存机制，但缓存失效后仍较慢

**优化方案**:
1. 缓存文件中增加字体目录 mtime 校验，避免无效检测
2. 将字体检测延迟到首次显示提示符前（使用 `preexec` 钩子）
3. 首次启动时跳过检测，直接使用降级配置

**预期收益**: 首次启动 -10ms

#### 瓶颈 6：02_aliases.zsh 中 eza 检测优化（节省 ~3ms）

**位置**: `zsh/core/02_aliases.zsh:10`

**问题**:
- `command -v eza` 在每次 shell 启动时执行
- eza 是 brew 安装的，路径已在 PATH 中

**优化方案**: 使用参数展开或条件赋值：
```zsh
# 仅在 eza 存在时定义，不存在时回退
if (( $+commands[eza] )); then
  alias ls='eza --group-directories-first --icons'
else
  alias ls='ls --color=auto --group-directories-first'
fi
```

**预期收益**: 微小（-3ms），但更规范

---

## 三、优化实施计划

### Phase 1: 立即可做（P0 瓶颈）

| 步骤 | 改动文件 | 预估收益 | 风险 |
|------|---------|---------|------|
| 1 | `00_env.zsh`：移除 `brew --prefix` 冗余调用 | -25ms | 低 |
| 2 | `04_plugins.zsh`：`brew --prefix zinit` 移至 fallback | -25ms | 低 |
| 3 | `01_options.zsh`：compdump 缓存有效期延长至 7 天 | -60ms 热 / -150ms 冷 | 低 |
| 4 | `01_options.zsh`：使用 `compinit -C -d` + skip 优化 | -10ms | 低 |

**Phase 1 预期效果**: 热启动 223ms → **~128ms** | 冷启动 466ms → **~266ms**

### Phase 2: 进阶优化（P1 瓶颈）

| 步骤 | 改动文件 | 预估收益 | 风险 |
|------|---------|---------|------|
| 5 | `04_plugins.zsh`：forgit + zsh-z 改为懒加载 | -40ms | 中（首次使用需等待） |
| 6 | `04_plugins.zsh`：zoxide init 延迟加载 | -8ms | 低 |
| 7 | `00_env.zsh`：HOMEBREW_PREFIX 条件检测 | -5ms | 低 |

**Phase 2 预期效果**: 热启动 128ms → **~75ms** | 冷启动 266ms → **~175ms**

### Phase 3: 深度优化（P2 瓶颈）

| 步骤 | 改动文件 | 预估收益 | 风险 |
|------|---------|---------|------|
| 8 | `05_starship.zsh`：字体检测延迟到 preexec | -10ms 首次 | 中 |
| 9 | `02_aliases.zsh`：使用 `$+commands[eza]` | -3ms | 低 |
| 10 | 引入 `zcompdump` 插件管理 compinit | -30ms 冷 | 中 |

**Phase 3 预期效果**: 热启动 75ms → **~62ms** | 冷启动 175ms → **~130ms**

---

## 四、优化后性能预测

| 指标 | 当前 | Phase 1 后 | Phase 2 后 | Phase 3 后 |
|------|------|-----------|-----------|-----------|
| 冷启动 | 466ms | ~266ms | ~175ms | **~130ms** |
| 热启动 | 223ms | ~128ms | ~75ms | **~62ms** |
| 插件开销 | 128ms | ~88ms | ~48ms | **~35ms** |
| 冷→热加速比 | 52% | 52% | 57% | **52%** |

---

## 五、可观测性增强

### 5.1 内置性能计时器

在 `00_env.zsh` 中添加启动计时：
```zsh
# 启动性能计时（仅在 ZSH_PROFILE=1 时输出）
if [[ "${ZSH_PROFILE:-0}" == "1" ]]; then
  typeset -g _start_time=$((EPOCHREALTIME*1000))
  autoload -Uz add-zsh-hook
  _profile_end() {
    local end=$((EPOCHREALTIME*1000))
    echo "[ZSH_PROFILE] 启动耗时: ${(int)(end - _start_time)}ms" >&2
    add-zsh-hook -D preexec _profile_end
  }
  add-zsh-hook preexec _profile_end
fi
```

### 5.2 插件加载耗时统计

zinit 内置 `zinit times` 命令，可在 `list_plugins` 函数中暴露：
```zsh
function list_plugins() {
  echo "zinit 插件加载耗时:"
  zinit times  # 显示每个插件的加载耗时
  zinit loaded  # 列出已加载插件
}
```

---

## 六、风险评估

| 优化项 | 风险等级 | 影响范围 | 回滚方案 |
|--------|---------|---------|---------|
| 移除 brew --prefix | 低 | 仅影响 00_env.zsh | 恢复原代码 |
| compinit 缓存延长 | 低 | 补全系统 | `rm ~/.cache/zsh/zcompdump*` |
| 插件懒加载 | 中 | forgit/zsh-z 首次使用延迟 | 改回 `zinit light` |
| zcompdump 插件 | 中 | 补全系统 | 移除插件，恢复 compinit |
| 字体检测延迟 | 中 | 首次提示符 | 恢复同步检测 |

---

## 七、验证方法

```bash
# 基线测试
./zsh/profile_performance.sh

# 优化后对比
# 1. 清理缓存
rm -f ~/.cache/zsh/zcompdump*
# 2. 冷启动测试
for i in 1 2 3 4 5; do
  t=$(( $(date +%s%N) / 1000000 ))
  zsh -i -c "exit"
  t2=$(( $(date +%s%N) / 1000000 ))
  echo "冷启动 $i: $((t2 - t))ms"
done
# 3. 热启动测试
for i in 1 2 3 4 5; do
  t=$(( $(date +%s%N) / 1000000 ))
  zsh -i -c "exit"
  t2=$(( $(date +%s%N) / 1000000 ))
  echo "热启动 $i: $((t2 - t))ms"
done
# 4. 插件禁用基线
for i in 1 2 3 4 5; do
  t=$(( $(date +%s%N) / 1000000 ))
  ZSH_DISABLE_PLUGINS=1 zsh -i -c "exit"
  t2=$(( $(date +%s%N) / 1000000 ))
  echo "基线 $i: $((t2 - t))ms"
done
```
