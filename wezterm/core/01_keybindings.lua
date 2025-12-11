-- ===================================
-- Wezterm 快捷键配置
-- ===================================

local wezterm = require('wezterm')
local act = wezterm.action

return {
  -- Leader 键配置
  leader = { key = 'b', mods = 'CTRL', timeout_milliseconds = 1000 },
  
  -- 键绑定配置
  keys = {
    -- 窗口管理
    { key = 'n', mods = 'LEADER', action = act.SpawnWindow },
    { key = 'w', mods = 'LEADER', action = act.ShowTabNavigator },
    
    -- 标签页管理
    { key = 't', mods = 'LEADER', action = act.SpawnTab 'CurrentPaneDomain' },
    { key = 'q', mods = 'LEADER', action = act.CloseCurrentTab { confirm = false } },
    { key = 'Tab', mods = 'CTRL', action = act.ActivateTabRelative(1) },
    { key = 'Tab', mods = 'SHIFT|CTRL', action = act.ActivateTabRelative(-1) },
    
    -- 窗格管理
    { key = '3', mods = 'LEADER', action = act.SplitVertical { domain = 'CurrentPaneDomain' } },
    { key = '2', mods = 'LEADER', action = act.SplitHorizontal { domain = 'CurrentPaneDomain' } },
    { key = 'x', mods = 'LEADER', action = act.CloseCurrentPane { confirm = false } },
    { key = 'z', mods = 'LEADER', action = act.TogglePaneZoomState },
    
    -- 窗格导航 (Vim 风格)
    { key = 'h', mods = 'LEADER', action = act.ActivatePaneDirection 'Left' },
    { key = 'j', mods = 'LEADER', action = act.ActivatePaneDirection 'Down' },
    { key = 'k', mods = 'LEADER', action = act.ActivatePaneDirection 'Up' },
    { key = 'l', mods = 'LEADER', action = act.ActivatePaneDirection 'Right' },
    
    -- 窗格大小调整
    { key = 'H', mods = 'LEADER|SHIFT', action = act.AdjustPaneSize { 'Left', 5 } },
    { key = 'J', mods = 'LEADER|SHIFT', action = act.AdjustPaneSize { 'Down', 5 } },
    { key = 'K', mods = 'LEADER|SHIFT', action = act.AdjustPaneSize { 'Up', 5 } },
    { key = 'L', mods = 'LEADER|SHIFT', action = act.AdjustPaneSize { 'Right', 5 } },
    
    -- 复制粘贴
    { key = 'c', mods = 'LEADER', action = act.CopyTo 'Clipboard' },
    { key = 'v', mods = 'LEADER', action = act.PasteFrom 'Clipboard' },
    
    -- 搜索
    { key = '/', mods = 'LEADER', action = act.Search { CaseInSensitiveString = '' } },
    
    -- 全屏
    { key = 'f', mods = 'LEADER', action = act.ToggleFullScreen },
    
    -- 颜色方案切换
    { 
      key = 'r', 
      mods = 'LEADER', 
      action = act.EmitEvent 'random-color-scheme', 
    },
    
    -- 重新加载配置
    { key = 'R', mods = 'LEADER|SHIFT', action = act.ReloadConfiguration },
    
    -- 字体大小调整
    { key = '=', mods = 'CTRL', action = act.IncreaseFontSize },
    { key = '-', mods = 'CTRL', action = act.DecreaseFontSize },
    { key = '0', mods = 'CTRL', action = act.ResetFontSize },
  },
  
  -- 键表配置 (模态操作)
  key_tables = {
    -- 调整窗格大小模式
    resize_pane = {
      { key = 'LeftArrow', action = act.AdjustPaneSize { 'Left', 1 } },
      { key = 'h', action = act.AdjustPaneSize { 'Left', 1 } },
      { key = 'RightArrow', action = act.AdjustPaneSize { 'Right', 1 } },
      { key = 'l', action = act.AdjustPaneSize { 'Right', 1 } },
      { key = 'UpArrow', action = act.AdjustPaneSize { 'Up', 1 } },
      { key = 'k', action = act.AdjustPaneSize { 'Up', 1 } },
      { key = 'DownArrow', action = act.AdjustPaneSize { 'Down', 1 } },
      { key = 'j', action = act.AdjustPaneSize { 'Down', 1 } },
      { key = 'Escape', action = 'PopKeyTable' },
      { key = 'Enter', action = 'PopKeyTable' },
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
