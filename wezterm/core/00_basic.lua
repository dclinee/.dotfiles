-- ===================================
-- Wezterm 核心基础配置
-- ===================================

local wezterm = require('wezterm')

return {
  -- 基础外观配置
  color_scheme = 'Tokyo Night',
  font = wezterm.font_with_fallback({
    { family = 'JetBrains Mono', weight = 'Medium' },
    { family = 'Fira Code', weight = 'Medium' },
    { family = 'Hack', weight = 'Medium' },
    { family = 'Source Code Pro', weight = 'Medium' },
    { family = 'Noto Sans Mono', weight = 'Medium' },
    { family = 'Sarasa Mono SC', weight = 'Medium' },  -- 中文字体
    { family = 'PingFang SC', weight = 'Medium' },     -- macOS 中文字体
    { family = 'Microsoft YaHei', weight = 'Medium' }, -- Windows 中文字体
  }),
  line_height = 1.05,
  cell_width = 1.0,
  
  -- 抗锯齿和渲染优化
  freetype_load_target = 'Normal',
  freetype_render_target = 'Normal',
  freetype_load_flags = 'NO_HINTING',
  
  -- 窗口配置
  window_padding = {
    left = 8,
    right = 8,
    top = 8,
    bottom = 8,
  },
  
  window_frame = {
    font = wezterm.font('JetBrains Mono', { weight = 'Bold' }),
    font_size = 12,
    active_titlebar_bg = '#1a1b26',
    inactive_titlebar_bg = '#1a1b26',
  },
  
  -- 标签页配置
  enable_tab_bar = true,
  hide_tab_bar_if_only_one_tab = true,
  tab_bar_at_bottom = true,
  use_fancy_tab_bar = false,
  show_new_tab_button_in_tab_bar = false,
  
  -- 滚动条配置
  enable_scroll_bar = true,
  scrollback_lines = 10000,
  
  -- 光标配置
  default_cursor_style = 'BlinkingBar',
  cursor_blink_rate = 500,
  cursor_blink_ease_in = 'EaseIn',
  cursor_blink_ease_out = 'EaseOut',
  
  -- 性能优化
  max_fps = 60,
  front_end = 'WebGpu',
  
  -- 终端特性
  term = 'xterm-256color',
  warn_about_missing_glyphs = false,
  exit_behavior = 'Close',
  
  -- 颜色透明度
  window_background_opacity = 0.95,
  text_background_opacity = 1.0,
  inactive_pane_hsb = {
    saturation = 0.7,
    brightness = 0.7,
  },
  
  -- 窗口装饰
  window_decorations = 'RESIZE',
  window_close_confirmation = 'NeverPrompt',
  
  -- 状态栏
  status_update_interval = 1000,
}
