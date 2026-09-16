# editorconfig/ — EditorConfig 配置安装

## 用途

安装项目根目录的 `.editorconfig` 到用户主目录，为所有编辑器提供统一的缩进/换行/编码配置。

## 安装行为

- 创建符号链接：`~/.editorconfig` → `editorconfig/.editorconfig`（通过 `safe_symlink`）

## 体检

```bash
make editorconfig        # 安装
make doctor              # 全模块体检（含 editorconfig）
```