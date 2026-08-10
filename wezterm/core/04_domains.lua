-- ===================================
-- Wezterm 域配置 (SSH / 本地复用)
-- ===================================
-- 注: 默认不强制 connect unix，避免无 domain daemon 时启动失败
-- 需要复用时手动执行: wezterm connect unix

local wezterm = require('wezterm')

local domain_config = {
  unix_domains = {
    {
      name = 'unix',
      local_echo_threshold_ms = 10,
    },
  },
}

-- SSH 域配置 (通过环境变量 WEZTERM_SSH_SERVER 配置)
local ssh_server = os.getenv('WEZTERM_SSH_SERVER')
if ssh_server then
  domain_config.ssh_domains = {
    {
      name = 'dev-server',
      remote_address = ssh_server,
      username = os.getenv('WEZTERM_SSH_USER') or os.getenv('USER') or 'user',
      assume_shell = 'Posix',
    },
  }
end

return domain_config
