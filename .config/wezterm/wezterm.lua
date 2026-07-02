local wezterm = require("wezterm")

local config = wezterm.config_builder()

local is_windows = os.getenv("OS") and os.getenv("OS"):lower():find("windows")
local is_macos = wezterm.target_triple:lower():find("darwin") ~= nil

config.color_scheme = "Solarized Dark (Gogh)"
--config.color_scheme = "OneDark (base16)"
--config.color_scheme = "nord"
--config.color_scheme = "Dracula (Official)"
--config.color_scheme = "Gruvbox Material (Gogh)"
--config.color_scheme = "Catppuccin Macchiato"
--config.color_scheme = "Catppuccin Mocha"
--config.color_scheme = "Tokyo Night"
--config.color_scheme = "Tokyo Night Storm"
--config.color_scheme = "rose-pine-moon"

config.max_fps = 120
-- config.font = wezterm.font("Hack Nerd Font", { weight = "DemiBold" })
config.font = wezterm.font("Monaco")
config.window_decorations = "INTEGRATED_BUTTONS|RESIZE"
config.window_frame = {
  font = wezterm.font("Hack Nerd Font", { weight = "Bold" }),
}

config.inactive_pane_hsb = {
  saturation = 0.0,
  brightness = 0.5,
}

if is_windows then
  config.win32_system_backdrop = "Acrylic"
  config.window_background_opacity = 1.0
  config.window_frame.font_size = 12.0
end

if is_macos then
  config.window_background_opacity = 1.0
  config.macos_window_background_blur = 50
  config.font_size = 12.0
  config.window_frame.font_size = 12.0
end

return config
