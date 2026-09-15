local wezterm = require("wezterm")

local config = wezterm.config_builder()

-- Session persistence across restarts (pane layout + cwd + scrollback).
-- Manual save/restore only (SUPER+S / SUPER+R) — startup auto-restore is
-- intentionally NOT wired, since gui-startup below force-spawns four windows.
local resurrect = wezterm.plugin.require("https://github.com/MLFlexer/resurrect.wezterm")
resurrect.state_manager.periodic_save({ interval_seconds = 300, save_workspaces = true })

local is_windows = os.getenv("OS") and os.getenv("OS"):lower():find("windows")
local is_macos = wezterm.target_triple:lower():find("darwin") ~= nil

-- Four-window setup — one theme + one title per purpose:
--   Managers → Gruvbox Material (Gogh)  — the Claude manager sessions
--   Direct   → Solarized Dark (Gogh)    — work I drive directly, by hand
--   Agents   → Tokyo Night Storm        — the worker agents the managers drive
--   Hold     → nord                     — parked: blocked or not wanted now
--
-- Names deliberately start with four different letters (M/D/A/H). An earlier
-- pass used manager/worker/managed, where "manager" and "managed" were
-- indistinguishable at a glance in a window switcher — which is the entire
-- point of naming them. SUPER|SHIFT+1..4 pins the current window to a purpose.
--
-- Theme list for reference:
--   "Catppuccin Mocha", "Dracula (Official)", "Gruvbox Material (Gogh)",
--   "Tokyo Night Storm", "Tokyo Night", "nord", "rose-pine-moon",
--   "Solarized Light (Gogh)", "Gruvbox Light"

-- EVERY WINDOW SHARES ONE WORKSPACE. This is the whole design constraint,
-- and it is not negotiable: a WezTerm workspace behaves like a virtual desktop,
-- so only the ACTIVE workspace's windows get gui windows at all. Measured
-- directly (census logging, 2026-09-15) with one window per workspace:
--
--   T+3s | active_workspace=manager | id=0 ws=manager gui=YES
--                                   | id=1 ws=worker  gui=no
--                                   | id=2 ws=managed gui=no
--
-- The others are not hidden, stacked or mis-positioned — they have no gui
-- window, and one appears only when you close the current one and the active
-- workspace moves. So "one workspace per purpose" can never put several windows
-- on screen together, however the spawning is done.
--
-- Purpose therefore keys off the WINDOW, not the workspace. The mapping lives
-- in wezterm.GLOBAL because that is the one table that survives a config
-- reload — a plain module-level table is rebuilt every reload, which would drop
-- every window back to the fallback colour on the first save of this file.
local WORKSPACE = "main"

local window_specs = {
  { purpose = "Managers", scheme = "Gruvbox Material (Gogh)", cwd = wezterm.home_dir },
  { purpose = "Direct",   scheme = "Solarized Dark (Gogh)",   cwd = wezterm.home_dir .. "/Documents/workspaces" },
  { purpose = "Agents",   scheme = "Tokyo Night Storm",       cwd = wezterm.home_dir .. "/Documents/workspaces" },
  -- Parking lot for tabs that are blocked or not wanted right now, and the
  -- natural destination for the SUPER|SHIFT+A park binding. nord is cold and
  -- desaturated — distinct from the warm brown, teal and purple above without
  -- being a light theme glaring among three dark ones.
  { purpose = "Hold",     scheme = "nord",                    cwd = wezterm.home_dir },
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
--      several windows can carry distinct themes while sharing one workspace.
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

-- Startup: spawn every purpose window into the ONE shared workspace.
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

-- Debug output goes to a FILE, not wezterm.log_info.
--
-- log_info writes to the GUI process's stderr, which for an app launched from
-- Finder is unreadable — and that is the normal case. Several rounds of this
-- config were debugged blind for exactly that reason: a handler that never ran
-- and a handler that raised looked identical from outside. A file can be
-- tailed from anywhere, including by tooling that is not attached to the GUI.
local DEBUG_LOG = "/tmp/wezterm-debug.log"

local function dbg(msg)
  if not DEBUG then
    return
  end
  wezterm.log_info("WEZDEBUG: " .. msg)
  local f = io.open(DEBUG_LOG, "a")
  if f then
    f:write(os.date("%H:%M:%S") .. " " .. msg .. "\n")
    f:close()
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

-- How often the window set is checked. Low enough that an accidentally closed
-- window is back before you reach for it, high enough to be free at idle.
local RECONCILE_INTERVAL_SECONDS = 5

-- The window title is the purpose, re-asserted on every title computation.
--
-- `wezterm cli set-window-title` is NOT usable for this: it sets the title
-- once, and any pane that emits a title escape immediately overwrites it. Every
-- window here runs Claude, which sets the terminal title continuously, so the
-- CLI title survived only on an idle window — measured directly: of three
-- windows titled via the CLI, only the idle one still read its given name
-- seconds later.
--
-- format-window-title is the durable mechanism because it OWNS the computation
-- rather than racing it. It receives TabInformation, whose `window_id` (since
-- 20220807-113146-c2fee766) is what makes a per-window lookup possible at all.
wezterm.on("format-window-title", function(tab, pane, tabs, panes, config)
  local purpose = purpose_of(tab.window_id)
  if purpose then
    return purpose
  end
  -- No recorded purpose: reproduce wezterm's default title.
  return tab.active_pane.title
end)

local function claim(mux_win, purpose)
  local id = mux_win:window_id()
  wezterm.GLOBAL.window_purpose[tostring(id)] = purpose
  -- Re-resolve the colour directly: window-config-reloaded does not fire just
  -- because a window's purpose changed, so an adopted window would otherwise
  -- keep its old fallback scheme until the next config save.
  local ok, gui = pcall(function()
    return mux_win:gui_window()
  end)
  if ok and gui then
    gui:set_config_overrides { color_scheme = scheme_by_purpose[purpose] }
  end
  dbg(string.format("claimed id=%s purpose=%s", tostring(id), purpose))
end

-- Re-apply every window's scheme from its recorded purpose.
--
-- Needed after a pane is moved between windows: the colour is a per-WINDOW
-- config override, and moving a pane does not re-run that override, so the
-- moved tab keeps rendering in the scheme of the window it came from. Nothing
-- re-asserts it on its own — not window-config-reloaded, which does not fire
-- for a move — so the wrong colour persists until the next config save.
-- Apply a window's scheme. With force=true, CLEAR the override first and set it
-- back a moment later.
--
-- The clear is the whole point. set_config_overrides with the value a window
-- already holds is a no-op — wezterm sees no change and does not repaint — so
-- simply re-asserting the correct scheme does nothing for a pane that moved
-- into the window and is still drawn in its previous window's palette. That is
-- why a config reload "fixed" it and a re-assert did not: the reload forces the
-- repaint that an unchanged value never triggers.
local function apply_scheme(mw, scheme, force)
  local ok, gui = pcall(function()
    return mw:gui_window()
  end)
  if not ok or not gui then
    return "skip(no gui)"
  end
  if force then
    gui:set_config_overrides {}
    wezterm.time.call_after(0.1, function()
      local ok2, g2 = pcall(function()
        return mw:gui_window()
      end)
      if ok2 and g2 then
        g2:set_config_overrides { color_scheme = scheme }
      end
    end)
    return scheme .. "(forced)"
  end
  gui:set_config_overrides { color_scheme = scheme }
  return scheme
end

local function reassert_schemes(force)
  local report = {}
  for _, mw in ipairs(wezterm.mux.all_windows()) do
    local purpose = purpose_of(mw:window_id())
    local scheme = purpose and scheme_by_purpose[purpose]
    local applied = "skip(no purpose)"
    if scheme then
      applied = apply_scheme(mw, scheme, force)
    end
    table.insert(report, string.format("%s=%s", tostring(mw:window_id()), applied))
  end
  dbg("reassert" .. (force and " FORCED" or "") .. " " .. table.concat(report, " "))
end

-- Detect a pane changing windows, by any route — the park/restore bindings, a
-- drag, or a hand-run `wezterm cli move-pane-to-new-tab`. Returns true when the
-- pane→window mapping differs from the previous tick, which is the signal that
-- some window needs a forced repaint rather than a no-op re-assert.
local function panes_moved()
  local current = {}
  for _, mw in ipairs(wezterm.mux.all_windows()) do
    local wid = tostring(mw:window_id())
    for _, tab in ipairs(mw:tabs()) do
      for _, p in ipairs(tab:panes()) do
        current[tostring(p:pane_id())] = wid
      end
    end
  end

  local previous = wezterm.GLOBAL.pane_window or {}
  local moved = false
  for pane_id, wid in pairs(current) do
    if previous[pane_id] and previous[pane_id] ~= wid then
      moved = true
      dbg(string.format("pane %s moved window %s -> %s", pane_id, previous[pane_id], wid))
    end
  end

  wezterm.GLOBAL.pane_window = current
  return moved
end

-- Moves go through the CLI and complete asynchronously, so re-assert shortly
-- after rather than immediately — at the moment the CLI call returns, the pane
-- has not landed in its new window yet.
local function reassert_schemes_after_move()
  -- force=true: the destination window's override is already correct, so only
  -- a cleared-then-restored override repaints the pane that just arrived.
  wezterm.time.call_after(0.3, function()
    reassert_schemes(true)
  end)
end

-- Keep the window set whole: exactly one window per purpose, correctly titled
-- and coloured. Runs on a timer, so a window closed by accident comes back
-- within a few seconds, and a config reload repairs whatever drifted.
--
-- Adoption (step 3) is what makes this self-healing rather than merely
-- additive: windows that exist but have no recorded purpose — Cmd+N windows,
-- resurrect-restored ones, or any window whose GLOBAL entry was lost — are
-- assigned the free purposes in window-id order instead of being ignored and
-- duplicated.
local function reconcile()
  local windows = wezterm.mux.all_windows()

  -- Never resurrect from zero. Zero windows means wezterm is quitting;
  -- spawning here would fight the shutdown and make it unquittable.
  if #windows == 0 then
    return
  end

  local map = wezterm.GLOBAL.window_purpose

  -- 1. Drop entries for windows that no longer exist, so their purpose frees up.
  local alive = {}
  for _, mw in ipairs(windows) do
    alive[tostring(mw:window_id())] = true
  end
  for id in pairs(map) do
    if not alive[id] then
      map[id] = nil
    end
  end

  -- 2. Release duplicate claims — two windows must never hold one purpose.
  local taken = {}
  for _, mw in ipairs(windows) do
    local key = tostring(mw:window_id())
    local purpose = map[key]
    if purpose then
      if taken[purpose] then
        map[key] = nil
      else
        taken[purpose] = true
      end
    end
  end

  -- 3. Collect purposeless windows, oldest first, as adoption candidates.
  local orphans = {}
  for _, mw in ipairs(windows) do
    if not map[tostring(mw:window_id())] then
      table.insert(orphans, mw)
    end
  end
  table.sort(orphans, function(a, b)
    return a:window_id() < b:window_id()
  end)

  -- 4. Fill every unheld purpose: adopt an orphan if there is one, else spawn.
  for _, spec in ipairs(window_specs) do
    if not taken[spec.purpose] then
      local mux_win = table.remove(orphans, 1)
      if not mux_win then
        -- Spawn into the ACTIVE workspace, never the hardcoded startup one.
        -- A window spawned into a non-active workspace gets no gui window, so
        -- respawning into WORKSPACE while the session sits in another one
        -- silently produces an invisible replacement — the window is "restored"
        -- and you still cannot see it. Observed live: a respawn landed in
        -- "main" while the real windows were in "personal", and the user saw
        -- two windows, not three.
        local workspace = wezterm.mux.get_active_workspace() or WORKSPACE
        local _, _, spawned = wezterm.mux.spawn_window {
          workspace = workspace,
          cwd       = spec.cwd,
        }
        mux_win = spawned
        dbg("respawned purpose=" .. spec.purpose .. " into ws=" .. tostring(workspace))
      end
      claim(mux_win, spec.purpose)
      taken[spec.purpose] = true
    end
  end

  -- 5. Re-assert colours, forcing a repaint only when a pane actually changed
  -- windows. Forcing on every tick would clear and restore the override once a
  -- second-ish on every window, which is visible flicker for no reason; never
  -- forcing leaves a moved pane drawn in its old window's palette.
  reassert_schemes(panes_moved())
end

-- Heartbeat: update-status fires roughly once a second per window, so it gives
-- a recurring tick without self-scheduling anything. Throttled via GLOBAL so
-- the work happens at most once per RECONCILE_INTERVAL_SECONDS no matter how
-- many windows are ticking.
--
-- A self-rearming wezterm.time.call_after chain was tried first and never ran.
-- The config is re-evaluated constantly — every reload, and again as each
-- window resolves its config — and the guard meant to keep exactly one chain
-- alive (compare a captured generation against a counter bumped per
-- evaluation) instead retired every chain: the counter had always moved on by
-- the time a 5s timer fired. It failed silently, which is the worst property a
-- guard can have. An event-driven tick has no such failure mode.
wezterm.on("update-status", function(window, pane)
  local now = os.time()
  local last = wezterm.GLOBAL.last_reconcile or 0
  if now - last < RECONCILE_INTERVAL_SECONDS then
    return
  end
  wezterm.GLOBAL.last_reconcile = now
  -- Report failures explicitly. An error raised in an event handler is logged
  -- and swallowed by wezterm, so without this a broken reconcile is
  -- indistinguishable from one that never fires.
  local ok, err = pcall(reconcile)
  dbg("tick reconcile ok=" .. tostring(ok) .. (ok and "" or (" err=" .. tostring(err))))
end)

wezterm.on("gui-startup", function(cmd)
  for _, spec in ipairs(window_specs) do
    local _, _, mux_win = wezterm.mux.spawn_window {
      workspace = WORKSPACE,
      cwd       = spec.cwd,
    }
    -- Record purpose BEFORE the window can fire window-config-reloaded, so the
    -- very first colour resolution already sees it. reconcile() cannot do this
    -- job: at gui-startup there are zero windows, which is exactly the case its
    -- quit-guard refuses to act on.
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
        reassert_schemes_after_move()
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
              -- Prefix the source window's purpose: with several windows the tab
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
            return
          end
          reassert_schemes_after_move()
        end),
      }, pane)
    end),
  },
  { key = "phys:LeftArrow",  mods = "CTRL|SHIFT", action = wezterm.action.MoveTabRelative(-1) },
  { key = "phys:RightArrow", mods = "CTRL|SHIFT", action = wezterm.action.MoveTabRelative(1) },
  -- Disable default ALT+Enter → ToggleFullScreen
  { key = "Enter", mods = "ALT", action = wezterm.action.DisableDefaultAssignment },
}

-- SUPER|SHIFT + 1..N pins the CURRENT window to a purpose: Managers, Direct,
-- Agents, Hold. Colour and title follow immediately.
--
-- This is the manual override for the automatic assignment. Adoption has to
-- guess — it hands out free purposes in window-id order — and that guess is
-- wrong whenever the on-screen arrangement does not match id order, which is
-- routine after a window is closed and another respawned. Without a way to
-- correct it by hand, the only remedy was to reload the config and hope the
-- ordering came out right, which is not a remedy.
for i, spec in ipairs(window_specs) do
  table.insert(config.keys, {
    key = tostring(i),
    mods = "SUPER|SHIFT",
    action = wezterm.action_callback(function(win, _)
      local mux = win:mux_window()
      if not mux then
        return
      end
      -- Free the purpose from whoever holds it, so two windows never share one.
      for id, purpose in pairs(wezterm.GLOBAL.window_purpose) do
        if purpose == spec.purpose then
          wezterm.GLOBAL.window_purpose[id] = nil
        end
      end
      claim(mux, spec.purpose)
      win:toast_notification("wezterm", "this window is now " .. spec.purpose, nil, 2000)
    end),
  })
end

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
