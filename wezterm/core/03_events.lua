-- ===================================
-- Wezterm 事件处理
-- ===================================
-- 本文件注册 wezterm.on 事件回调，不返回配置表
-- 返回空表以兼容 merge_config 机制

local wezterm = require('wezterm')

-- 状态栏: 显示电池 + 时间
wezterm.on('update-right-status', function(window, pane)
  local date = wezterm.strftime '%Y-%m-%d %H:%M:%S'
  local bat = ''
  for _, b in ipairs(wezterm.battery_info()) do
    bat = string.format('%.0f%%', b.state_of_charge * 100)
  end

  window:set_right_status(wezterm.format({
    { Text = ' ' .. bat .. ' ' },
    { Text = date .. ' ' },
  }))
end)

-- 颜色方案切换 (Leader+r 触发)
local color_schemes = {
  'Tokyo Night',
  'Dracula',
  'One Dark (Gogh)',
  'Solarized Dark Higher Contrast',
  'Catppuccin Mocha',
  'Gruvbox Dark',
  'Monokai Pro',
  'Nord',
}

wezterm.on('random-color-scheme', function(window, pane)
  local overrides = window:get_config_overrides() or {}
  local current_scheme = overrides.color_scheme or 'Tokyo Night'
  local current_index = nil

  for i, scheme in ipairs(color_schemes) do
    if scheme == current_scheme then
      current_index = i
      break
    end
  end

  local next_index = current_index and (current_index % #color_schemes) + 1 or 1
  overrides.color_scheme = color_schemes[next_index]

  window:set_config_overrides(overrides)
  wezterm.log_info('Switched to color scheme: ' .. overrides.color_scheme)
end)

-- 配置重载通知
wezterm.on('window-config-reloaded', function(window, pane)
  wezterm.log_info('WezTerm configuration reloaded successfully')
  wezterm.log_info('Running on: ' .. wezterm.target_triple)
end)

return {}
