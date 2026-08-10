--[[
   WezTerm 跨平台配置入口
   版本: 2.0.0
   日期: 2026-08-10
   重构: 拆分为 core/ 模块化加载，对齐 vim/zsh 分层模式

   结构:
     wezterm.lua          ← 本文件（加载器 + return config）
     core/00_basic.lua     ← 基础外观/窗口/标签/光标/性能
     core/01_keybindings.lua ← 快捷键/键表/鼠标
     core/02_colors.lua    ← 标签栏颜色配置
     core/03_events.lua    ← 事件处理（状态栏/配色切换/重载通知）
     core/04_domains.lua   ← 域配置（unix_domains / SSH）
     platform/linux.lua    ← Linux 平台特定配置
     platform/macos.lua    ← macOS 平台特定配置
     platform/windows.lua  ← Windows 平台特定配置
 ]]

local wezterm = require('wezterm')
local config = wezterm.config_builder()

-- ======================
-- 平台检测
-- ======================
local function is_macos()  return (wezterm.target_triple or ''):find('darwin') ~= nil end
local function is_linux()  return (wezterm.target_triple or ''):find('linux') ~= nil end
local function is_windows() return (wezterm.target_triple or ''):find('windows') ~= nil end

-- ======================
-- 模块加载器
-- ======================

-- 判断表是否为数组型（连续整数索引）
local function is_array(t)
  local count = 0
  for _ in pairs(t) do count = count + 1 end
  return count > 0 and t[1] ~= nil
end

-- 合并配置表: 数组型追加，字典型按键合并
local function merge_config(config_table, file_path)
  local ok, user_config = pcall(dofile, file_path)
  if not ok then
    wezterm.log_error('加载配置失败: ' .. file_path .. ' - ' .. tostring(user_config))
    return
  end
  for k, v in pairs(user_config) do
    if type(v) == 'table' and type(config_table[k]) == 'table' then
      if is_array(v) then
        for _, item in ipairs(v) do
          table.insert(config_table[k], item)
        end
      else
        for sub_k, sub_v in pairs(v) do
          config_table[k][sub_k] = sub_v
        end
      end
    else
      config_table[k] = v
    end
  end
end

-- ======================
-- 加载配置模块
-- ======================

local home_dir = wezterm.home_dir or os.getenv('HOME')
if not home_dir then
  wezterm.log_error('无法确定 HOME 目录，WezTerm 模块化配置将不可用')
  return {}
end
local wezterm_dir = home_dir .. '/.dotfiles/wezterm'

-- 1. 加载 core/ 下的所有 .lua（按文件名排序）
local core_files = wezterm.glob(wezterm_dir .. '/core/*.lua')
table.sort(core_files)
for _, file in ipairs(core_files) do
  merge_config(config, file)
end

-- 2. 加载平台特定配置
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

-- ======================
-- 调试配置
-- ======================
config.debug_key_events = false

return config
