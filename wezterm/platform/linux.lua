-- ===================================
-- Wezterm Linux 平台配置
-- ===================================

return {
  -- Linux 特定配置
  enable_wayland = true,
  window_background_opacity = 0.95,
  font_size = 14,
  
  -- Linux 特定默认终端
  default_prog = {'zsh', '--login'},
}
