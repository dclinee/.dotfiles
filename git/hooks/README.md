# ======================
# Git Hooks 模板
# ======================
# 将本目录设为公共 hooks 目录:
#   git config --global core.hooksPath ~/.dotfiles/git/hooks
#
# 每个脚本需加上可执行权限:
#   chmod +x pre-commit commit-msg pre-push

# ======================
# pre-commit: 检查尾随空格和行尾
# ======================
#!/usr/bin/env bash
# 检查暂存区中是否有尾随空格的文件
if git rev-parse --verify HEAD >/dev/null 2>&1; then
  against=HEAD
else
  against=$(git hash-object -t tree /dev/null)
fi

# 获取变更的文本文件
files=$(git diff --cached --name-only --diff-filter=AM "$against")
if [[ -z "$files" ]]; then
  exit 0
fi

# 检查尾随空格
if echo "$files" | xargs grep -l '[[:space:]]$' 2>/dev/null | grep -q .; then
  echo "❌ 以下文件包含尾随空格:"
  echo "$files" | xargs grep -l '[[:space:]]$' 2>/dev/null
  echo "请运行: sed -i 's/[[:space:]]*$//' <file>"
  exit 1
fi

# 检查行尾（Windows 行尾转义）
if echo "$files" | xargs grep -l $'\r' 2>/dev/null | grep -q .; then
  echo "❌ 以下文件包含 CRLF 行尾:"
  echo "$files" | xargs grep -l $'\r' 2>/dev/null
  echo "请运行: dos2unix <file> 或修改 .gitattributes"
  exit 1
fi

echo "✅ pre-commit 检查通过"
exit 0

# ======================
# commit-msg: 检查提交信息格式
# ======================
#!/usr/bin/env bash
# 检查提交信息是否符合 Conventional Commits 格式
commit_msg_file="$1"
commit_msg=$(head -n 1 "$commit_msg_file")

# 跳过合并提交和回滚提交
if echo "$commit_msg" | grep -qE '^(Merge|Revert|fixup!|squash!)'; then
  exit 0
fi

# 检查提交信息长度
if [[ ${#commit_msg} -gt 72 ]]; then
  echo "❌ 提交信息首行超过 72 字符（当前 ${#commit_msg} 字符）"
  echo "   $commit_msg"
  exit 1
fi

# 检查是否包含破坏性变更标记
if echo "$commit_msg" | grep -qE '^[a-z]+(\([^)]+\))?!:'; then
  echo "⚠️  检测到破坏性变更标记，请注意版本号升级"
fi

echo "✅ commit-msg 检查通过"
exit 0

# ======================
# pre-push: 检查目标分支保护
# ======================
#!/usr/bin/env bash
# 阻止直接推送到 main/master 分支
protected_branches="main master develop"

while read local_ref local_sha remote_ref remote_sha; do
  remote_branch="${remote_ref#refs/heads/}"

  for protected in $protected_branches; do
    if [[ "$remote_branch" == "$protected" ]]; then
      echo "❌ 禁止直接推送到 $remote_branch 分支"
      echo "   请创建 Pull Request 进行审查"
      exit 1
    fi
  done
done

echo "✅ pre-push 检查通过"
exit 0
