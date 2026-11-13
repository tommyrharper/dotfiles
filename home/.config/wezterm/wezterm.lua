local wezterm = require("wezterm")
local act = wezterm.action

local config = wezterm.config_builder()

config.color_scheme = "rose-pine-moon"
config.font = wezterm.font("Hack Nerd Font")
config.font_size = 15.0
config.window_background_opacity = 0.8
config.macos_window_background_blur = 50
config.native_macos_fullscreen_mode = true -- this means you lose the pretty opacity
config.hide_tab_bar_if_only_one_tab = true
config.window_decorations = "RESIZE"

config.colors = {
  selection_bg = "#ea9a97",
  selection_fg = "#232136",
  copy_mode_active_highlight_bg = { Color = "#ea9a97" },
  copy_mode_active_highlight_fg = { Color = "#232136" },
  copy_mode_inactive_highlight_bg = { Color = "#3e8fb0" },
  copy_mode_inactive_highlight_fg = { Color = "#e0def4" },
}

config.leader = { key = "Space", mods = "CTRL", timeout_milliseconds = 1000 }
config.keys = {
  {
    key = "[",
    mods = "LEADER",
    action = wezterm.action.ActivateCopyMode,
  },
  -- Send a real ctrl+b when you press prefix then ctrl+b again
  {
    key = "Space",
    mods = "LEADER|CTRL",
    action = wezterm.action.SendKey({ key = "Space", mods = "CTRL" }),
  },
  -- tmux-style pane management, same keys, wezterm leader instead of ctrl+b
  { key = "%", mods = "LEADER", action = wezterm.action.SplitHorizontal({ domain = "CurrentPaneDomain" }) },
  { key = '"', mods = "LEADER", action = wezterm.action.SplitVertical({ domain = "CurrentPaneDomain" }) },
  { key = "h", mods = "LEADER", action = wezterm.action.ActivatePaneDirection("Left") },
  { key = "l", mods = "LEADER", action = wezterm.action.ActivatePaneDirection("Right") },
  { key = "k", mods = "LEADER", action = wezterm.action.ActivatePaneDirection("Up") },
  { key = "j", mods = "LEADER", action = wezterm.action.ActivatePaneDirection("Down") },
  { key = "x", mods = "LEADER", action = wezterm.action.CloseCurrentPane({ confirm = true }) },
  -- Pull the current pane out into its own window (tmux break-pane).
  {
    key = "n",
    mods = "LEADER",
    action = wezterm.action_callback(function(win, pane)
      pane:move_to_new_window()
    end),
  },
  -- Undo break-pane: merge this pane into the first other window as a new tab.
  -- No Lua API for cross-window pane moves, so shell out to the wezterm CLI;
  -- absolute path because the GUI app's PATH may not include it. Must be
  -- background_child_process, not os.execute: a blocking call here deadlocks
  -- wezterm (the CLI waits on the same GUI thread the callback is holding).
  {
    key = "m",
    mods = "LEADER",
    action = wezterm.action_callback(function(win, pane)
      for _, other in ipairs(wezterm.mux.all_windows()) do
        if other:window_id() ~= win:window_id() then
          wezterm.background_child_process({
            wezterm.executable_dir .. "/wezterm",
            "cli",
            "move-pane-to-new-tab",
            "--pane-id",
            tostring(pane:pane_id()),
            "--window-id",
            tostring(other:window_id()),
          })
          return
        end
      end
    end),
  },
  {
    key = "T",
    mods = "LEADER|SHIFT",
    action = act.PromptInputLine({
      description = "Enter new tab title:",
      action = wezterm.action_callback(function(window, pane, line)
        if line then
          window:active_tab():set_title(line)
        end
      end),
    }),
  },
  -- Leader+o: QuickSelect restricted to URLs, then open the picked one in the
  -- default browser. Ctrl+Shift+Space (wezterm's built-in QuickSelect) is left
  -- alone and still just copies the hinted text to the clipboard.
  {
    key = "o",
    mods = "LEADER",
    action = act.QuickSelectArgs({
      label = "open url",
      patterns = { "https?://\\S+" },
      action = wezterm.action_callback(function(window, pane)
        local url = window:get_selection_text_for_pane(pane)
        if url and url ~= "" then
          wezterm.open_with(url)
        end
      end),
    }),
  },
  -- AI-fill the Zsh input buffer: sends Ctrl-G, bound in home.nix to ai-fill-buffer.
  { key = "g", mods = "LEADER", action = wezterm.action.SendKey({ key = "g", mods = "CTRL" }) },
  -- Cmd+hjkl sends raw arrow keys, for Vim-style nav in TUI grids (e.g. Claude
  -- agents view). Cmd rather than Option because macOS never delivers Cmd to
  -- terminal programs, so this cannot shadow a Neovim mapping - Option did,
  -- eating LazyVim's Alt+j/Alt+k move-line. The cost is wezterm's own Cmd+h
  -- (hide app) and Cmd+k (clear scrollback), which these override.
  { key = "h", mods = "CMD", action = act.SendString("\x1b[D") },
  { key = "j", mods = "CMD", action = act.SendString("\x1b[B") },
  { key = "k", mods = "CMD", action = act.SendString("\x1b[A") },
  { key = "l", mods = "CMD", action = act.SendString("\x1b[C") },
  -- Clear the shell input line without copying it to the kill ring (widget in home.nix).
  { key = "K", mods = "CTRL|SHIFT", action = act.SendString("\x1b[107;6u") },
  -- Option+Left/Right send Esc-b / Esc-f, the readline word-nav sequences.
  -- Without this macOS Option composes a character instead, which Herdr
  -- misreads as a prompt-indicator toggle and leaves the terminal wedged.
  { key = "LeftArrow", mods = "OPT", action = act.SendString("\x1bb") },
  { key = "RightArrow", mods = "OPT", action = act.SendString("\x1bf") },
}

return config
