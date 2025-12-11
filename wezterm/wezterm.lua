--[[ 
   WezTerm 跨平台配置文件 
   作者: Dclinee 
   版本: 1.0.0 
   日期: 2025-12-10 
   支持: macOS, Linux, Windows 
 ]] 

local wezterm = require 'wezterm' 
local act = wezterm.action 
local config = wezterm.config_builder() or {} 

-- 平台检测函数 
local function is_macos() 
  return wezterm.target_triple:find 'darwin' ~= nil 
end 

local function is_linux() 
  return wezterm.target_triple:find 'linux' ~= nil 
end 

local function is_windows() 
  return wezterm.target_triple:find 'windows' ~= nil 
end 

-- 获取配置目录路径
local wezterm_dir = wezterm.home_dir .. '/.dotfiles/wezterm'

-- 加载核心配置
local core_files = wezterm.glob(wezterm_dir .. '/core/*.lua')
for _, file in ipairs(core_files) do
  local core_config = dofile(file)
  -- 合并核心配置到主配置
  for k, v in pairs(core_config) do
    if type(v) == 'table' and type(config[k]) == 'table' then
      -- 合并表类型配置
      for sub_k, sub_v in pairs(v) do
        config[k][sub_k] = sub_v
      end
    else
      -- 直接赋值非表类型配置
      config[k] = v
    end
  end
end

-- 加载平台特定配置
if is_macos() then
  local macos_file = wezterm_dir .. '/platform/macos.lua'
  if wezterm.path.file_exists(macos_file) then
    local macos_config = dofile(macos_file)
    for k, v in pairs(macos_config) do
      if type(v) == 'table' and type(config[k]) == 'table' then
        for sub_k, sub_v in pairs(v) do
          config[k][sub_k] = sub_v
        end
      else
        config[k] = v
      end
    end
  end
elseif is_linux() then
  local linux_file = wezterm_dir .. '/platform/linux.lua'
  if wezterm.path.file_exists(linux_file) then
    local linux_config = dofile(linux_file)
    for k, v in pairs(linux_config) do
      if type(v) == 'table' and type(config[k]) == 'table' then
        for sub_k, sub_v in pairs(v) do
          config[k][sub_k] = sub_v
        end
      else
        config[k] = v
      end
    end
  end
elseif is_windows() then
  local windows_file = wezterm_dir .. '/platform/windows.lua'
  if wezterm.path.file_exists(windows_file) then
    local windows_config = dofile(windows_file)
    for k, v in pairs(windows_config) do
      if type(v) == 'table' and type(config[k]) == 'table' then
        for sub_k, sub_v in pairs(v) do
          config[k][sub_k] = sub_v
        end
      else
        config[k] = v
      end
    end
  end
end

-- 标签栏颜色配置
config.colors = {
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
}

-- 状态栏配置
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

-- 颜色方案切换功能
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
  local current_scheme = overrides.color_scheme or config.color_scheme
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

-- 自动启动工作区配置
wezterm.on('gui-startup', function(cmd)
  local tab, pane, window = wezterm.mux.spawn_window(cmd or {})
  
  -- 创建默认工作区布局
  if not cmd then
    -- 垂直分割
    local right_pane = pane:split { direction = 'Right', size = 0.5 }
    
    -- 水平分割
    local bottom_pane = pane:split { direction = 'Down', size = 0.5 }
    
    -- 在底部窗格运行 htop
    bottom_pane:send_text 'htop\n'
  end
end)

-- 显示配置信息
wezterm.on('window-config-reloaded', function(window, pane)
  wezterm.log_info('WezTerm configuration reloaded successfully')
  wezterm.log_info('Running on: ' .. wezterm.target_triple)
end)

-- 性能优化配置
config.debug_key_events = false

-- 多域支持 (SSH 和本地复用)
config.unix_domains = {
  {
    name = 'unix',
    local_echo_threshold_ms = 10,
  },
}

config.default_gui_startup_args = { 'connect', 'unix' }

-- SSH 域配置 (根据需要修改)
config.ssh_domains = {
  {
    name = 'dev-server',
    remote_address = '192.168.1.100',
    username = os.getenv('USER') or 'user',
    assume_shell = 'Posix',
  },
}

return config
