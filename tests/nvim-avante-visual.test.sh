#!/usr/bin/env bash
# Asking avante about a visual selection must work on a cold nvim.
#
# LazyVim's ai.avante extra declares its keys with no `mode`, so lazy.nvim
# builds the load trigger in normal mode only. avante's own {"n","v"} mappings
# are created inside its setup(), which has not run yet - so on a fresh nvim
# <leader>aa does not exist in visual mode at all, and avante's ask() reads the
# live selection (getpos("v")), so there is no cmdline workaround either.
# home/.config/nvim/lua/plugins/avante.lua re-declares those keys with
# mode = { "n", "v" }; drop that and selections silently stop reaching avante.
set -u
# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

command -v nvim >/dev/null 2>&1 || { echo "skip: nvim not installed"; exit 0; }

data_home="${XDG_DATA_HOME:-$HOME/.local/share}/nvim"
[ -d "$data_home/lazy/which-key.nvim" ] \
  || { echo "skip: plugins not cloned yet - open nvim once"; exit 0; }

# As in nvim-conform.test.sh: lazy.nvim only emits VeryLazy once a UI attaches,
# so under --headless the keymaps would never be installed and every check
# below would pass or fail for the wrong reason.
ready='lua vim.api.nvim_exec_autocmds("User", {pattern="VeryLazy", modeline=false})'

# <leader> is a space, hence the " aa" lookups.
probe=$(XDG_CONFIG_HOME="$ROOT/home/.config" nvim --headless -c "$ready" -c 'lua
for _, m in ipairs({ { " aa", "v" }, { " ae", "v" }, { " aa", "n" } }) do
  local map = vim.fn.maparg(m[1], m[2], false, true)
  print(m[2] .. m[1] .. "=" .. (map.desc or map.rhs or "NONE"))
end
local spec = vim.inspect(require("which-key.config").spec)
print("group=" .. (spec:match("group = \"(ai[^\"]*)\"") or "NONE"))' -c qa! 2>&1) \
  || fail "nvim exited non-zero (LazyVim never finished loading?)"

assert_contains "$probe" 'v aa=Ask Avante' \
  "<leader>aa is not mapped in visual mode: avante cannot see a selection"
assert_contains "$probe" 'v ae=Edit Avante' \
  "<leader>ae is not mapped in visual mode"
assert_contains "$probe" 'n aa=Ask Avante' \
  "<leader>aa is not mapped in normal mode"
assert_contains "$probe" 'group=ai/avante' \
  "which-key has no <leader>a group: the menu shows a bare \"+N keymaps\""

pass "avante is reachable from visual mode and <leader>a is a named which-key group"
