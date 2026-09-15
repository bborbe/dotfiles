local wezterm = require("wezterm")

local config = wezterm.config_builder()

-- Session persistence across restarts (pane layout + cwd + scrollback).
-- Manual save/restore only (SUPER+S / SUPER+R) — startup auto-restore is
-- intentionally NOT wired, since gui-startup below force-spawns two windows.
local resurrect = wezterm.plugin.require("https://github.com/MLFlexer/resurrect.wezterm")
resurrect.state_manager.periodic_save({ interval_seconds = 300, save_workspaces = true })

local is_windows = os.getenv("OS") and os.getenv("OS"):lower():find("windows")
local is_macos = wezterm.target_triple:lower():find("darwin") ~= nil

-- Three-window setup — one workspace + one theme per purpose:
--   manager → Gruvbox Material (Gogh)  — the Claude manager sessions
--   worker  → Solarized Dark (Gogh)    — worker sessions I drive by hand
--   managed → Tokyo Night Storm        — work the managers drive
--
-- Theme list for reference:
--   "Catppuccin Mocha", "Dracula (Official)", "Gruvbox Material (Gogh)",
--   "Tokyo Night Storm", "Tokyo Night", "nord", "rose-pine-moon",
--   "Solarized Light (Gogh)", "Gruvbox Light"

local windows = {
  { workspace = "manager", scheme = "Gruvbox Material (Gogh)", cwd = wezterm.home_dir },
  { workspace = "worker",  scheme = "Solarized Dark (Gogh)",   cwd = wezterm.home_dir .. "/Documents/workspaces" },
  { workspace = "managed", scheme = "Tokyo Night Storm",       cwd = wezterm.home_dir .. "/Documents/workspaces" },
}

local scheme_by_workspace = {}
local scheme_list = {}
for _, spec in ipairs(windows) do
  scheme_by_workspace[spec.workspace] = spec.scheme
  table.insert(scheme_list, spec.scheme)
end

config.color_scheme = windows[1].scheme

-- Scheme resolution, in order:
--   1. The window's OWN workspace, via MuxWindow:get_workspace(). Stable across
--      close/reopen, tab moves and config reloads, so a window keeps its theme
--      for as long as it keeps its purpose. NOT window:active_workspace(),
--      which returns the mux-GLOBAL active workspace and therefore collapsed
--      every window to the focused workspace's color on each reload.
--   2. Fallback for a window in an unlisted workspace (Cmd+N joins whatever
--      workspace is active): open order over the scheme list — window_id is
--      monotonic, so sorting live ids and indexing gives extra windows a
--      deterministic, distinct color instead of all sharing one.
local function scheme_for_window(window)
  local mux = window:mux_window()
  if mux then
    local scheme = scheme_by_workspace[mux:get_workspace()]
    if scheme then
      return scheme
    end
  end

  local ids = {}
  for _, w in ipairs(wezterm.mux.all_windows()) do
    table.insert(ids, w:window_id())
  end
  table.sort(ids)
  local my_id = window:window_id()
  for i, id in ipairs(ids) do
    if id == my_id then
      return scheme_list[((i - 1) % #scheme_list) + 1]
    end
  end
  return scheme_list[1]
end

-- Startup: spawn all three windows, cascaded so each stays grabbable
wezterm.on("gui-startup", function(cmd)
  local active = wezterm.gui.screens().active
  for i, spec in ipairs(windows) do
    local _, mux_win, _ = wezterm.mux.spawn_window {
      workspace = spec.workspace,
      cwd       = spec.cwd,
    }
    local gui = mux_win:gui_window()
    if gui then
      gui:set_config_overrides { color_scheme = spec.scheme }
      gui:set_position(active.x + 30 + (i - 1) * 50, active.y + 20 + (i - 1) * 40)
    end
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
  -- Park / restore across the windows. No hiding anywhere: the other windows
  -- are the background — they sit behind the current one, fully visible, so a
  -- parked tab needs no minimize/off-screen trick and no archive workspace.
  -- Both directions use the CLI, which is the only thing that moves a pane
  -- into an EXISTING window (the Lua enum has no such action;
  -- pane:move_to_new_window only makes a NEW window).
  -- Note: moves the ACTIVE pane — on a split tab only that pane parks.
  -- With three purpose-windows the target is ambiguous, so this picks by
  -- workspace name rather than grabbing the first non-current window.
  {
    key = "a",
    mods = "SUPER|SHIFT",
    action = wezterm.action_callback(function(win, pane)
      local current_id = win:window_id()
      local choices = {}
      for _, mw in ipairs(wezterm.mux.all_windows()) do
        if mw:window_id() ~= current_id then
          table.insert(choices, {
            id    = tostring(mw:window_id()),
            label = mw:get_workspace() .. "  (" .. #mw:tabs() .. " tabs)",
          })
        end
      end
      if #choices == 0 then
        win:toast_notification("wezterm", "no other window to park into", nil, 3000)
        return
      end
      -- Single other window: no point prompting, just send it.
      local function park_to(window_id)
        wezterm.run_child_process {
          wezterm.executable_dir .. "/wezterm", "cli", "move-pane-to-new-tab",
          "--pane-id", tostring(pane:pane_id()),
          "--window-id", window_id,
        }
      end
      if #choices == 1 then
        park_to(choices[1].id)
        return
      end
      win:perform_action(wezterm.action.InputSelector {
        title = "Park this tab into which window?",
        choices = choices,
        fuzzy = true,
        action = wezterm.action_callback(function(_, _, id)
          if id then
            park_to(id)
          end
        end),
      }, pane)
    end),
  },
  -- Restore: fuzzy-pick a tab from the OTHER window(s) and pull it back into
  -- the CURRENT window as a new tab. A parked (single-pane) tab moves whole.
  -- The CLI binary is addressed via wezterm.executable_dir — a bare "wezterm"
  -- doesn't resolve when the app launched from Finder (no PATH entry).
  {
    key = "w",
    mods = "SUPER|SHIFT",
    action = wezterm.action_callback(function(win, pane)
      local current_id = win:window_id()
      local choices = {}
      for _, mw in ipairs(wezterm.mux.all_windows()) do
        if mw:window_id() ~= current_id then
          local ws = mw:get_workspace()
          for _, t in ipairs(mw:tabs()) do
            for _, p in ipairs(t:panes()) do
              local title = t:get_title()
              if title == "" then
                title = p:get_title()
              end
              -- Prefix the workspace: with three windows the title alone
              -- doesn't say where the tab is being pulled from.
              table.insert(choices, { id = tostring(p:pane_id()), label = "[" .. ws .. "] " .. title })
            end
          end
        end
      end
      if #choices == 0 then
        win:toast_notification("wezterm", "no tabs in the other window", nil, 3000)
        return
      end
      win:perform_action(wezterm.action.InputSelector {
        title = "Pull tab into this window",
        choices = choices,
        fuzzy = true,
        action = wezterm.action_callback(function(w, _, id)
          if not id then
            return
          end
          local args = {
            wezterm.executable_dir .. "/wezterm", "cli", "move-pane-to-new-tab",
            "--pane-id", id,
            "--window-id", tostring(w:window_id()),
          }
          local ok, stderr = pcall(wezterm.run_child_process, args)
          if not ok or (stderr and #stderr > 0) then
            w:toast_notification("wezterm", "restore failed: " .. tostring(stderr), nil, 4000)
          end
        end),
      }, pane)
    end),
  },
  { key = "phys:LeftArrow",  mods = "CTRL|SHIFT", action = wezterm.action.MoveTabRelative(-1) },
  { key = "phys:RightArrow", mods = "CTRL|SHIFT", action = wezterm.action.MoveTabRelative(1) },
  -- Disable default ALT+Enter → ToggleFullScreen
  { key = "Enter", mods = "ALT", action = wezterm.action.DisableDefaultAssignment },
}

-- Cmd+click opens links. WezTerm ships no SUPER mouse binding of its own (the
-- old SUPER+drag → StartWindowDrag default moved to SHIFT|CTRL upstream), so
-- without these Cmd+click is a silent no-op. The Down→Nop half suppresses the
-- selection that would otherwise swallow the click.
-- Note: inside apps that enable mouse reporting (Claude Code, vim, tmux) the
-- TUI consumes clicks — hold SHIFT to bypass reporting and hit the link.
config.mouse_bindings = {
  {
    event = { Up = { streak = 1, button = "Left" } },
    mods = "SUPER",
    action = wezterm.action.OpenLinkAtMouseCursor,
  },
  {
    event = { Down = { streak = 1, button = "Left" } },
    mods = "SUPER",
    action = wezterm.action.Nop,
  },
  -- Keep the default SUPER+Left-drag → StartWindowDrag disabled (Cmd+drag
  -- otherwise moves the window).
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
