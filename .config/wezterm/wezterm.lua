local wezterm = require("wezterm")

local config = wezterm.config_builder()

-- Session persistence across restarts (pane layout + cwd + scrollback).
-- Manual save/restore only (SUPER+S / SUPER+R) — startup auto-restore is
-- intentionally NOT wired, since gui-startup below force-spawns two windows.
local resurrect = wezterm.plugin.require("https://github.com/MLFlexer/resurrect.wezterm")
resurrect.state_manager.periodic_save({ interval_seconds = 300, save_workspaces = true })

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

local personal_scheme = "Gruvbox Material (Gogh)"
local work_scheme     = "Solarized Dark (Gogh)"

config.color_scheme = personal_scheme

-- Determine scheme for a window by OPEN ORDER, not workspace. window_id is
-- monotonic (first window has the lowest id), so sorting all live windows and
-- indexing into the scheme list gives a deterministic, race-free color:
-- window 1 → personal, window 2 → work, cycling for extras. This is immune to
-- the two failure modes of the old workspace-based logic:
--   1. window:active_workspace() returns the mux-GLOBAL active workspace (not
--      the window's own), so on any config reload every window resolved to the
--      focused workspace's scheme → all windows collapsed to one color.
--   2. Cmd+n windows join the active workspace, so a second window in
--      "personal" got the personal scheme instead of a distinct one.
local schemes = { personal_scheme, work_scheme }
local function scheme_for_window(window)
  local ids = {}
  for _, w in ipairs(wezterm.mux.all_windows()) do
    table.insert(ids, w:window_id())
  end
  table.sort(ids)
  local my_id = window:window_id()
  for i, id in ipairs(ids) do
    if id == my_id then
      return schemes[((i - 1) % #schemes) + 1]
    end
  end
  return personal_scheme
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
  -- resurrect: save current workspace state
  {
    key = "s",
    mods = "SUPER",
    action = wezterm.action_callback(function(_, _)
      resurrect.state_manager.save_state(resurrect.workspace_state.get_workspace_state())
    end),
  },
  -- resurrect: fuzzy-pick a saved state and restore it
  {
    key = "r",
    mods = "SUPER",
    action = wezterm.action_callback(function(win, pane)
      resurrect.fuzzy_loader.fuzzy_load(win, pane, function(id)
        local kind = string.match(id, "^([^/]+)")
        id = string.match(id, "([^/]+)$")
        id = string.match(id, "(.+)%..+$")
        local opts = {
          relative = true,
          restore_text = true,
          on_pane_restore = resurrect.tab_state.default_on_pane_restore,
        }
        if kind == "workspace" then
          resurrect.workspace_state.restore_workspace(resurrect.state_manager.load_state(id, "workspace"), opts)
        elseif kind == "window" then
          resurrect.window_state.restore_window(pane:window(), resurrect.state_manager.load_state(id, "window"), opts)
        elseif kind == "tab" then
          resurrect.tab_state.restore_tab(pane:tab(), resurrect.state_manager.load_state(id, "tab"), opts)
        end
      end)
    end),
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
