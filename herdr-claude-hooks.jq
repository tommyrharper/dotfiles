# Rewrites herdr's Claude hook to a $HOME path, dropping duplicates. See home.nix.
def portable:
  sub("^bash '[^']*/\\.claude/hooks/herdr-agent-state\\.sh'";
      "bash \"$HOME/.claude/hooks/herdr-agent-state.sh\"");
def dedupe: reduce .[] as $x ([]; if any(.[]; . == $x) then . else . + [$x] end);

if .hooks then
  .hooks |= map_values(
    map(.hooks |= map(if (.command | type) == "string" then .command |= portable else . end))
    | dedupe)
else . end
