-- ===================================
-- Wezterm macOS 平台配置
-- ===================================

return {
  -- macOS 特定配置
  native_macos_fullscreen_mode = true,
  window_background_opacity = 0.9,
  font_size = 16,
  
  -- 使用 macOS 风格的窗口控制
  use_resize_increments = true,
  window_decorations = 'RESIZE',
  
  -- macOS 特定快捷键行为
  send_composed_key_when_left_alt_is_pressed = false,
  send_composed_key_when_right_alt_is_pressed = true,
  
  -- macOS 特定默认终端
  default_prog = {'zsh', '--login'},
}
