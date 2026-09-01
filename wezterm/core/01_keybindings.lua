-- ===================================
-- Wezterm 快捷键配置
-- ===================================
--
-- 快捷键分层约定（无模态前缀，避免吞键）:
--   WezTerm 窗口/窗格管理: CTRL+SHIFT 组合键（本文件）
--   tmux 会话前缀:         C-a（见 tmux/.tmux.conf）
--   终端应用原生快捷键:     Ctrl-b / C-x 等单 Ctrl 组合键完整保留
--
-- 注意: 不配置 leader 前缀键。leader 模式激活期间（默认 1s）,
-- 非 LEADER 绑定的按键会被 WezTerm 吞掉而不透传给终端,
-- 导致终端 Emacs 中 Ctrl-b（backward-char）等单 Ctrl 键失效。

local wezterm = require('wezterm')
local act = wezterm.action

return {
  -- 键绑定配置
  keys = {
    -- 窗口管理
    { key = 'N', mods = 'CTRL|SHIFT', action = act.SpawnWindow },
    { key = 'W', mods = 'CTRL|SHIFT', action = act.ShowTabNavigator },

    -- 标签页管理
    { key = 'T', mods = 'CTRL|SHIFT', action = act.SpawnTab 'CurrentPaneDomain' },
    { key = 'Q', mods = 'CTRL|SHIFT', action = act.CloseCurrentTab { confirm = false } },
    { key = 'Tab', mods = 'CTRL', action = act.ActivateTabRelative(1) },
    { key = 'Tab', mods = 'SHIFT|CTRL', action = act.ActivateTabRelative(-1) },

    -- 窗格管理
    -- 说明: CTRL+SHIFT+数字 必须绑定映射字符 @/#（US 布局下 Shift+2=@, Shift+3=#）,
    --       因为 WezTerm 按映射字符优先匹配,用 '2'/'3' 绑定会被默认的标签切换遮蔽;
    --       此处同时覆盖了这两个键位上的默认 ActivateTab 绑定
    { key = '@', mods = 'CTRL|SHIFT',
      action = act.SplitHorizontal { domain = 'CurrentPaneDomain' } },
    { key = '#', mods = 'CTRL|SHIFT',
      action = act.SplitVertical { domain = 'CurrentPaneDomain' } },
    { key = 'X', mods = 'CTRL|SHIFT', action = act.CloseCurrentPane { confirm = false } },
    { key = 'Z', mods = 'CTRL|SHIFT', action = act.TogglePaneZoomState },

    -- 窗格导航 (Vim 风格)
    { key = 'H', mods = 'CTRL|SHIFT', action = act.ActivatePaneDirection 'Left' },
    { key = 'J', mods = 'CTRL|SHIFT', action = act.ActivatePaneDirection 'Down' },
    { key = 'K', mods = 'CTRL|SHIFT', action = act.ActivatePaneDirection 'Up' },
    { key = 'L', mods = 'CTRL|SHIFT', action = act.ActivatePaneDirection 'Right' },

    -- 窗格大小调整: CTRL+SHIFT+A 进入调整模式,
    -- H/J/K/L 或方向键连续调整,ESC/Enter 退出,空闲 5s 自动退出
    { key = 'A', mods = 'CTRL|SHIFT',
      action = act.ActivateKeyTable {
        name = 'resize_pane',
        one_shot = false,
        timeout_milliseconds = 5000,
      } },

    -- 复制粘贴: 使用默认绑定 CTRL+SHIFT+C / CTRL+SHIFT+V
    -- 搜索
    { key = 'F', mods = 'CTRL|SHIFT', action = act.Search { CaseInSensitiveString = '' } },

    -- 全屏: 使用默认绑定 ALT+Enter
    --       （native_macos_fullscreen_mode 下也可用系统 ⌃⌘F）
    -- 颜色方案切换
    { key = 'S', mods = 'CTRL|SHIFT', action = act.EmitEvent 'random-color-scheme' },

    -- 重新加载配置: 使用默认绑定 CTRL+SHIFT+R

    -- 字体大小调整
    { key = '=', mods = 'CTRL', action = act.IncreaseFontSize },
    { key = '-', mods = 'CTRL', action = act.DecreaseFontSize },
    { key = '0', mods = 'CTRL', action = act.ResetFontSize },
  },

  -- 键表配置 (模态操作)
  key_tables = {
    -- 窗格大小调整模式（CTRL+SHIFT+A 进入）
    resize_pane = {
      { key = 'h', action = act.AdjustPaneSize { 'Left', 5 } },
      { key = 'j', action = act.AdjustPaneSize { 'Down', 5 } },
      { key = 'k', action = act.AdjustPaneSize { 'Up', 5 } },
      { key = 'l', action = act.AdjustPaneSize { 'Right', 5 } },
      { key = 'LeftArrow', action = act.AdjustPaneSize { 'Left', 5 } },
      { key = 'DownArrow', action = act.AdjustPaneSize { 'Down', 5 } },
      { key = 'UpArrow', action = act.AdjustPaneSize { 'Up', 5 } },
      { key = 'RightArrow', action = act.AdjustPaneSize { 'Right', 5 } },
      { key = 'Escape', action = act.PopKeyTable },
      { key = 'Enter', action = act.PopKeyTable },
    },
  },

  -- 鼠标配置
  mouse_bindings = {
    -- 悬停在 URL 上时按住 CMD 键可打开
    { event = { Up = { streak = 1, button = 'Left' } },
      mods = 'CMD',
      action = act.OpenLinkAtMouseCursor },
  },
}
