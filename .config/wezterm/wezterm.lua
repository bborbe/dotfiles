local wezterm = require("wezterm")

local config = wezterm.config_builder()

local is_windows = os.getenv("OS") and os.getenv("OS"):lower():find("windows")
local is_macos = wezterm.target_triple:lower():find("darwin") ~= nil

-- Two-window setup:
--   Window 1 (personal) → Solarized Dark (Gogh) — current theme
--   Window 2 (work)     → OneDark (base16)        — distinct dark theme
--
-- Theme list for reference:
--   "Catppuccin Mocha", "Dracula (Official)", "Gruvbox Material (Gogh)",
--   "Tokyo Night Storm", "Tokyo Night", "nord", "rose-pine-moon",
--   "Solarized Light (Gogh)", "Gruvbox Light"

local personal_scheme = "Solarized Dark (Gogh)"
local work_scheme     = "Gruvbox Material (Gogh)"

config.color_scheme = personal_scheme

-- Determine scheme for a window: workspace name takes priority, then a
-- sticky "first free color" assignment stored in wezterm.GLOBAL, which
-- persists across config reloads so a window keeps its color (no swap,
-- no recompute → no reload cascade).
local function scheme_for_window(window)
  local ws = window:active_workspace()
  if ws:find("^work") then
    return work_scheme
  elseif ws:find("^personal") then
    return personal_scheme
  end

  local assigned = wezterm.GLOBAL.assigned or {}
  local my_id = tostring(window:window_id())
  -- Already assigned (survives reload) → keep it stable.
  if assigned[my_id] then
    return assigned[my_id]
  end

  -- Which schemes are held by other currently-open windows. Close a window →
  -- its color frees → next new window reclaims it.
  local used = {}
  for _, w in ipairs(wezterm.mux.all_windows()) do
    local id = tostring(w:window_id())
    if id ~= my_id and assigned[id] then
      used[assigned[id]] = true
    end
  end
  local chosen = personal_scheme
  for _, s in ipairs({ personal_scheme, work_scheme }) do
    if not used[s] then
      chosen = s
      break
    end
  end
  assigned[my_id] = chosen
  wezterm.GLOBAL.assigned = assigned -- reassign whole table so it persists
  return chosen
end

-- Startup: spawn both windows
wezterm.on("gui-startup", function(cmd)
  local active = wezterm.gui.screens().active

  -- Window 1 — personal
  local _, pers_win, _ = wezterm.mux.spawn_window {
    workspace = "personal",
    cwd       = wezterm.home_dir,
  }
  local pers_gui = pers_win:gui_window()
  if pers_gui then
    pers_gui:set_config_overrides { color_scheme = personal_scheme }
    pers_gui:set_position(active.x + 30, active.y + 20)
  end

  -- Window 2 — work
  local _, work_win, _ = wezterm.mux.spawn_window {
    workspace = "work",
    cwd       = wezterm.home_dir .. "/Documents/workspaces",
  }
  local work_gui = work_win:gui_window()
  if work_gui then
    work_gui:set_config_overrides { color_scheme = work_scheme }
    work_gui:set_position(active.x + 80, active.y + 60)
  end
end)

-- Applied to EVERY window at creation and on config reload
wezterm.on("window-config-reloaded", function(window)
  window:set_config_overrides {
    color_scheme = scheme_for_window(window),
  }
end)

config.enable_scroll_bar = true
config.exit_behavior = "Hold"
config.unix_domains = { { name = "unix" } }
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

config.keys = {
  {
    key = "k",
    mods = "SUPER",
    action = wezterm.action.Multiple({
      wezterm.action.ClearScrollback("ScrollbackAndViewport"),
      wezterm.action.SendKey({ key = "L", mods = "CTRL" }),
    }),
  },
  { key = "phys:LeftArrow",  mods = "CTRL|SHIFT", action = wezterm.action.MoveTabRelative(-1) },
  { key = "phys:RightArrow", mods = "CTRL|SHIFT", action = wezterm.action.MoveTabRelative(1) },
  -- Disable default ALT+Enter → ToggleFullScreen
  { key = "Enter", mods = "ALT", action = wezterm.action.DisableDefaultAssignment },
}

-- Disable default SUPER+Left-drag → StartWindowDrag (Cmd+click moving the window)
config.mouse_bindings = {
  {
    event = { Drag = { streak = 1, button = "Left" } },
    mods = "SUPER",
    action = wezterm.action.Nop,
  },
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
