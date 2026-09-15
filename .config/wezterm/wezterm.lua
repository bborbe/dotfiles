local wezterm = require("wezterm")

local config = wezterm.config_builder()

-- Session persistence across restarts (pane layout + cwd + scrollback).
-- Manual save/restore only (SUPER+S / SUPER+R) — startup auto-restore is
-- intentionally NOT wired, since gui-startup below force-spawns three windows.
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

-- ALL THREE WINDOWS SHARE ONE WORKSPACE. This is the whole design constraint,
-- and it is not negotiable: a WezTerm workspace behaves like a virtual desktop,
-- so only the ACTIVE workspace's windows get gui windows at all. Measured
-- directly (census logging, 2026-09-15) with one window per workspace:
--
--   T+3s | active_workspace=manager | id=0 ws=manager gui=YES
--                                   | id=1 ws=worker  gui=no
--                                   | id=2 ws=managed gui=no
--
-- The other two are not hidden, stacked or mis-positioned — they have no gui
-- window, and one appears only when you close the current one and the active
-- workspace moves. So "one workspace per purpose" can never put three windows
-- on screen together, however the spawning is done.
--
-- Purpose therefore keys off the WINDOW, not the workspace. The mapping lives
-- in wezterm.GLOBAL because that is the one table that survives a config
-- reload — a plain module-level table is rebuilt every reload, which would drop
-- every window back to the fallback colour on the first save of this file.
local WORKSPACE = "main"

local window_specs = {
  { purpose = "manager", scheme = "Gruvbox Material (Gogh)", cwd = wezterm.home_dir },
  { purpose = "worker",  scheme = "Solarized Dark (Gogh)",   cwd = wezterm.home_dir .. "/Documents/workspaces" },
  { purpose = "managed", scheme = "Tokyo Night Storm",       cwd = wezterm.home_dir .. "/Documents/workspaces" },
}

local scheme_by_purpose = {}
local scheme_list = {}
for _, spec in ipairs(window_specs) do
  scheme_by_purpose[spec.purpose] = spec.scheme
  table.insert(scheme_list, spec.scheme)
end

wezterm.GLOBAL.window_purpose = wezterm.GLOBAL.window_purpose or {}

-- Two constraints on the table above:
--   * Keys must be STRINGS — GLOBAL holds json-like data, so window ids get
--     tostring()'d on both write and read.
--   * The in-place nested write below (GLOBAL.window_purpose[id] = purpose)
--     requires wezterm >= 20230320-124340-559cb7b0. Before that, indexing
--     GLOBAL returned a COPY and the assignment silently did nothing, needing
--     a read/modify/write-back. Silently: no error, the value just never
--     appears — which here would look like every window losing its theme on
--     the first config save. Fine on this build (20260716+); if this config is
--     ever run somewhere older, that is the first thing to check.
local function purpose_of(window_id)
  return wezterm.GLOBAL.window_purpose[tostring(window_id)]
end

config.color_scheme = window_specs[1].scheme

-- Scheme resolution, in order:
--   1. The purpose recorded for this window id at spawn, from wezterm.GLOBAL.
--      Survives config reloads, and is per-window rather than per-workspace so
--      three windows can carry three themes while sharing one workspace.
--   2. Fallback for a window with no recorded purpose — a Cmd+N window, a
--      resurrect-restored one, or anything that outlived the mapping. Open
--      order over the scheme list: window_id is monotonic, so sorting live ids
--      and indexing gives it a deterministic colour instead of defaulting
--      everything to one.
local function scheme_for_window(window)
  local purpose = purpose_of(window:window_id())
  if purpose and scheme_by_purpose[purpose] then
    return scheme_by_purpose[purpose]
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

-- Startup: spawn all three windows into the ONE shared workspace.
--
-- The `workspace = WORKSPACE` on every spawn is the load-bearing part. Give
-- each window its own workspace and only one of them is ever on screen, for
-- the reason documented at WORKSPACE above: a non-active workspace's window is
-- a mux window with NO gui window.
--
-- Two traps that follow from that, both of which cost real debugging time:
--
--   * Asking a headless mux window for :gui_window() RAISES rather than
--     returning nil — "mux window id 1 is not currently associated with a gui
--     window". An `if gui then` guard cannot catch it, and the error
--     propagates out of this handler, aborting it, so every window after the
--     failing one is never spawned at all.
--   * Deferring, retrying or pcall-ing around :gui_window() does NOT fix that.
--     It only silences the error while the window still has no GUI — and a
--     silenced version is strictly worse, because "one window, no errors"
--     reads like a positioning bug and sends you looking in the wrong place.
--
-- So do not call :gui_window() here at all. Colours are not set here either:
-- window-config-reloaded below fires for every window that has a GUI and
-- resolves the scheme from the recorded purpose.
-- Spawn diagnostics. Flip to true and run `wezterm-gui start --always-new-process`
-- to get a census of every mux window with whether it has a gui window.
--
-- Keep this: window spawning here failed in a way that is invisible from the
-- outside — a headless window looks exactly like one that is hidden behind
-- another, and both look like a positioning bug. The census is what
-- distinguished them (gui=YES vs gui=no against active_workspace) after several
-- wrong fixes aimed at position and timing. window-config-reloaded is the other
-- half of the signal: it fires ONLY for windows that have a gui window, so
-- counting its lines counts the real windows.
local DEBUG = false

local function dbg(msg)
  if DEBUG then
    wezterm.log_info("WEZDEBUG: " .. msg)
  end
end

local function census(tag)
  local parts = {}
  for _, mw in ipairs(wezterm.mux.all_windows()) do
    local ok, gui = pcall(function()
      return mw:gui_window()
    end)
    table.insert(parts, string.format(
      "id=%s ws=%s gui=%s tabs=%d",
      tostring(mw:window_id()),
      tostring(mw:get_workspace()),
      (ok and gui ~= nil) and "YES" or "no",
      #mw:tabs()
    ))
  end
  dbg(string.format(
    "%s | active_workspace=%s | mux_windows=%d | %s",
    tag,
    tostring(wezterm.mux.get_active_workspace()),
    #wezterm.mux.all_windows(),
    table.concat(parts, " || ")
  ))
end

wezterm.on("gui-startup", function(cmd)
  for _, spec in ipairs(window_specs) do
    local _, _, mux_win = wezterm.mux.spawn_window {
      workspace = WORKSPACE,
      cwd       = spec.cwd,
    }
    -- Record purpose BEFORE the window can fire window-config-reloaded, so the
    -- very first colour resolution already sees it.
    wezterm.GLOBAL.window_purpose[tostring(mux_win:window_id())] = spec.purpose
    dbg(string.format("spawned id=%s purpose=%s ws=%s",
      tostring(mux_win:window_id()), spec.purpose, WORKSPACE))
  end

  -- Census after every spawn has had time to land. Timers are only armed under
  -- DEBUG so a normal start schedules nothing.
  if DEBUG then
    wezterm.time.call_after(3.0, function()
      census("T+3s")
    end)
    wezterm.time.call_after(8.0, function()
      census("T+8s")
    end)
  end
end)

-- Applied to EVERY window at creation and on config reload
wezterm.on("window-config-reloaded", function(window)
  local scheme = scheme_for_window(window)
  local mux = window:mux_window()
  dbg(string.format(
    "config-reloaded: gui window id=%s purpose=%s ws=%s -> scheme=%s",
    tostring(window:window_id()),
    tostring(purpose_of(window:window_id())),
    mux and tostring(mux:get_workspace()) or "<no mux>",
    scheme
  ))
  window:set_config_overrides {
    color_scheme = scheme,
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
            label = (purpose_of(mw:window_id()) or ("window " .. mw:window_id()))
              .. "  (" .. #mw:tabs() .. " tabs)",
          })
        end
      end
      if #choices == 0 then
        win:toast_notification("wezterm", "no other window to park into", nil, 3000)
        return
      end
      local function park_to(window_id)
        wezterm.run_child_process {
          wezterm.executable_dir .. "/wezterm", "cli", "move-pane-to-new-tab",
          "--pane-id", tostring(pane:pane_id()),
          "--window-id", window_id,
        }
      end
      -- Exactly one other window: the pick is forced, so skip the prompt.
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
          local origin = purpose_of(mw:window_id()) or ("window " .. mw:window_id())
          for _, t in ipairs(mw:tabs()) do
            for _, p in ipairs(t:panes()) do
              local title = t:get_title()
              if title == "" then
                title = p:get_title()
              end
              -- Prefix the source window's purpose: with three windows the tab
              -- title alone doesn't say where it would be pulled from.
              table.insert(choices, { id = tostring(p:pane_id()), label = "[" .. origin .. "] " .. title })
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
