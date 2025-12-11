-- ===================================
-- Wezterm Windows 平台配置
-- ===================================

return {
  -- Windows 特定配置
  font_size = 12,
  window_background_opacity = 0.9,
  
  -- Windows 特定默认终端
  default_prog = {'pwsh.exe', '-NoLogo'},
  
  -- Windows 特定窗口行为
  adjust_window_size_when_changing_font_size = false,
  use_resize_increments = true,
  
  -- Windows 特定渲染优化
  front_end = 'Software', -- Windows 上 Software 后端更稳定
  
  -- Windows 特定快捷键行为
  send_composed_key_when_left_alt_is_pressed = true,
  send_composed_key_when_right_alt_is_pressed = true,
}