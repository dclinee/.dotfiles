-- ===================================
-- Wezterm 标签栏颜色配置
-- ===================================

return {
  colors = {
    tab_bar = {
      background = '#1a1b26',
      active_tab = {
        bg_color = '#282c34',
        fg_color = '#c0caf5',
        intensity = 'Normal',
        underline = 'None',
        italic = false,
        strikethrough = false,
      },
      inactive_tab = {
        bg_color = '#1a1b26',
        fg_color = '#545c7e',
      },
      inactive_tab_hover = {
        bg_color = '#282c34',
        fg_color = '#c0caf5',
        italic = true,
      },
      new_tab = {
        bg_color = '#1a1b26',
        fg_color = '#545c7e',
      },
      new_tab_hover = {
        bg_color = '#282c34',
        fg_color = '#c0caf5',
        italic = true,
      },
    },
  },
}
