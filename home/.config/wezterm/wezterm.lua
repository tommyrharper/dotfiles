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
  -- Option+hjkl sends raw arrow keys, for Vim-style nav in TUI grids (e.g. Claude agents view).
  { key = "h", mods = "OPT", action = act.SendString("\x1b[D") },
  { key = "j", mods = "OPT", action = act.SendString("\x1b[B") },
  { key = "k", mods = "OPT", action = act.SendString("\x1b[A") },
  { key = "l", mods = "OPT", action = act.SendString("\x1b[C") },
  -- Option+Left/Right send Esc-b / Esc-f, the readline word-nav sequences.
  -- Without this macOS Option composes a character instead, which Herdr
  -- misreads as a prompt-indicator toggle and leaves the terminal wedged.
  { key = "LeftArrow", mods = "OPT", action = act.SendString("\x1bb") },
  { key = "RightArrow", mods = "OPT", action = act.SendString("\x1bf") },
}

return config
