# WezTerm Configuration

A modern, cross-platform WezTerm configuration with a focus on productivity, aesthetics, and performance.

## Features

- **Cross-Platform Support**: Linux, macOS, and Windows
- **Modern Aesthetics**: Tokyo Night color scheme with transparent backgrounds
- **Productive Keybindings**: Vim-style navigation with Leader key support
- **Smart Font Handling**: Multiple font fallbacks for consistent rendering
- **Advanced Features**: 
  - Dynamic status bar with battery and time
  - Color scheme switching
  - Multi-domain support (local + SSH)
  - Automatic workspace layout
- **Performance Optimized**: WebGPU rendering (where supported)

## Installation

### Linux
```bash
# Debian/Ubuntu
apt install wezterm

# Fedora
dnf install wezterm

# Arch Linux
pacman -S wezterm
```

### macOS
```bash
brew install --cask wezterm
```

### Windows
```powershell
# Winget
winget install WezTerm.WezTerm

# Chocolatey
choco install wezterm
```

## Configuration Setup

### 1. Clone the dotfiles repository
```bash
git clone https://github.com/yourusername/dotfiles.git ~/.dotfiles
```

### 2. Create a symbolic link

#### Linux/macOS
```bash
ln -sf ~/.dotfiles/wezterm/wezterm.lua ~/.wezterm.lua
```

#### Windows (PowerShell)
```powershell
New-Item -ItemType SymbolicLink -Path $env:USERPROFILE\.wezterm.lua -Target $env:USERPROFILE\.dotfiles\wezterm\wezterm.lua -Force
```

## Configuration Structure

```
wezterm/
├── wezterm.lua              # Main configuration entry point
├── core/                    # Core configuration modules
│   ├── 00_basic.lua         # Appearance and window settings
│   └── 01_keybindings.lua   # Keyboard shortcuts
├── platform/                # Platform-specific configurations
│   ├── linux.lua            # Linux optimizations
│   ├── macos.lua            # macOS optimizations
│   └── windows.lua          # Windows optimizations
└── README.md                # This file
```

## Keybindings

### Leader Key: `Ctrl+b`

| Key | Action |
|-----|--------|
| `n` | New window |
| `w` | Show tab navigator |
| `t` | New tab |
| `q` | Close tab |
| `3` | Split vertical |
| `2` | Split horizontal |
| `x` | Close pane |
| `z` | Toggle pane zoom |
| `h/j/k/l` | Navigate panes |
| `H/J/K/L` | Resize panes |
| `c` | Copy to clipboard |
| `v` | Paste from clipboard |
| `/` | Search |
| `f` | Toggle fullscreen |
| `r` | Cycle color schemes |
| `R` | Reload configuration |

### Other Shortcuts

| Key | Action |
|-----|--------|
| `Ctrl+Tab` | Next tab |
| `Ctrl+Shift+Tab` | Previous tab |
| `Ctrl+=` | Increase font size |
| `Ctrl+-` | Decrease font size |
| `Ctrl+0` | Reset font size |

## Color Schemes

Press `Ctrl+b r` to cycle through these color schemes:

- Tokyo Night (default)
- Dracula
- One Dark (Gogh)
- Solarized Dark Higher Contrast
- Catppuccin Mocha
- Gruvbox Dark
- Monokai Pro
- Nord

## Platform-Specific Optimizations

### Linux
- Wayland support enabled by default
- WebGPU rendering backend
- Optimized for Zsh

### macOS
- Native fullscreen mode
- Optimized keyboard behavior
- Better font rendering for Retina displays

### Windows
- Software rendering backend (more stable)
- PowerShell as default terminal
- Windows-specific keyboard handling

## Performance Tips

1. **Use GPU acceleration**: WebGPU is enabled on Linux/macOS for better performance
2. **Limit scrollback**: Configure `scrollback_lines` in `core/00_basic.lua`
3. **Disable debug features**: `debug_key_events` is set to false by default
4. **Use appropriate rendering backend**: Software backend is more stable on Windows

## Troubleshooting

### Font rendering issues
1. Ensure you have the recommended fonts installed:
   - JetBrains Mono
   - Fira Code
   - Sarasa Mono SC (for Chinese)

### Windows-specific issues
1. **Rendering glitches**: Try switching to Software backend in `platform/windows.lua`
2. **Permission issues**: Run WezTerm as administrator for the first run
3. **PowerShell issues**: Ensure PowerShell 7+ is installed

### Linux Wayland issues
1. **Window positioning**: Try disabling Wayland in `platform/linux.lua`
2. **Performance issues**: Check if your GPU drivers support WebGPU

## Customization

### Adding a new color scheme
1. Add it to the `color_schemes` table in `wezterm.lua`
2. Run `Ctrl+b R` to reload the configuration
3. Use `Ctrl+b r` to cycle to your new scheme

### Modifying keybindings
Edit `core/01_keybindings.lua` to customize keyboard shortcuts.

### Adding platform-specific settings
Edit the appropriate file in the `platform/` directory.

## Multi-Domain Support

### SSH Domains
Edit `wezterm.lua` to add your SSH servers:

```lua
config.ssh_domains = {
  {
    name = 'dev-server',
    remote_address = 'your-server.example.com',
    username = 'your-username',
  },
}
```

Connect to SSH domains using:
```bash
wezterm connect ssh://dev-server
```

## Automatic Workspace Layout

The configuration automatically creates a default workspace layout with:
- A main pane
- A right pane (50% width)
- A bottom pane (50% height) running `htop`

## Updating

To update your configuration, simply pull the latest changes:
```bash
git -C ~/.dotfiles pull
```

Then reload WezTerm configuration with `Ctrl+b R`.

## License

MIT
