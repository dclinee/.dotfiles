--[[
   WezTerm 跨平台配置文件
   作者: Dclinee
   版本: 1.1.0
   日期: 2026-08-09
   支持: macOS, Linux, Windows
   变更: 修复 home_dir API、merge_config 数组合并、gui-startup htop 检测
 ]] 

local wezterm = require 'wezterm'
local act = wezterm.action
local config = wezterm.config_builder()

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

-- Lua 内置文件存在检查函数
local function file_exists(name)
    local f = io.open(name, "r")
    if f then
        io.close(f)
        return true
    else
        return false
    end
end 

-- 获取配置目录路径
-- 优先用 wezterm.home_dir（API），失败时回退到 $HOME 环境变量
local home_dir = wezterm.home_dir or os.getenv('HOME')
if not home_dir then
  wezterm.log_error('无法确定 HOME 目录，WezTerm 模块化配置将不可用')
  return {}
end
local wezterm_dir = home_dir .. '/.dotfiles/wezterm'

-- 判断表是否为数组型（连续整数索引）
local function is_array(t)
  local count = 0
  for _ in pairs(t) do count = count + 1 end
  return count > 0 and t[1] ~= nil
end

-- 合并配置表的辅助函数
-- - 数组型表（keys / mouse_bindings）：用 insert 追加，避免互相覆盖
-- - 字典型表（colors / window_background）：按键合并
local function merge_config(config_table, file_path)
  if not file_exists(file_path) then return end
  local user_config = dofile(file_path)
  for k, v in pairs(user_config) do
    if type(v) == 'table' and type(config_table[k]) == 'table' then
      if is_array(v) then
        -- 数组型：追加合并
        for _, item in ipairs(v) do
          table.insert(config_table[k], item)
        end
      else
        -- 字典型：按键合并
        for sub_k, sub_v in pairs(v) do
          config_table[k][sub_k] = sub_v
        end
      end
    else
      config_table[k] = v
    end
  end
end

-- 加载核心配置
local core_files = wezterm.glob(wezterm_dir .. '/core/*.lua')
for _, file in ipairs(core_files) do
  merge_config(config, file)
end

-- 加载平台特定配置
local platform_file
if is_macos() then
  platform_file = wezterm_dir .. '/platform/macos.lua'
elseif is_linux() then
  platform_file = wezterm_dir .. '/platform/linux.lua'
elseif is_windows() then
  platform_file = wezterm_dir .. '/platform/windows.lua'
end
if platform_file then
  merge_config(config, platform_file)
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

-- 注：默认不强制 connect unix，避免无 domain daemon 时启动失败
-- 需要复用时手动执行: wezterm connect unix

-- SSH 域配置 (通过环境变量 WEZTERM_SSH_SERVER 配置)
local ssh_server = os.getenv('WEZTERM_SSH_SERVER')
if ssh_server then
  config.ssh_domains = {
    {
      name = 'dev-server',
      remote_address = ssh_server,
      username = os.getenv('WEZTERM_SSH_USER') or os.getenv('USER') or 'user',
      assume_shell = 'Posix',
    },
  }
end

return config
