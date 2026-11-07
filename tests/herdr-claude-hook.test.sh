#!/usr/bin/env bash
# settings.json is shared by every machine, but `herdr integration install
# claude` writes its hook with this machine's absolute home and only skips an
# exact match, so each machine appended its own entry (dead everywhere else,
# and leaking the username into this public repo). herdr-claude-hooks.jq,
# run by home.nix after the install, must fold all of them into one $HOME entry.
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

if ! command -v jq >/dev/null 2>&1; then
  echo "skip: jq not found for herdr Claude hook check"
  exit 0
fi

FILTER="$ROOT/herdr-claude-hooks.jq"
SETTINGS="$ROOT/home/.claude/settings.json"
# shellcheck disable=SC2016
PORTABLE='bash "$HOME/.claude/hooks/herdr-agent-state.sh" session'
TMP_ROOT=$(dotfiles_test_tmproot herdr-claude-hook)

herdr_commands() {
  jq -r '.hooks[][] | .hooks[] | .command // empty | select(test("herdr-agent-state"))' "$1"
}

tracked=$(herdr_commands "$SETTINGS")
[ "$tracked" = "$PORTABLE" ] \
  || fail "home/.claude/settings.json must hold exactly one herdr hook, '$PORTABLE' (got: $tracked)"
jq -f "$FILTER" "$SETTINGS" | cmp -s - "$SETTINGS" \
  || fail "the filter rewrites the tracked settings.json, so every rebuild would leave a git diff"

cat >"$TMP_ROOT/in.json" <<'JSON'
{
  "hooks": {
    "SessionStart": [
      { "matcher": "^(startup|resume|clear|compact|fork)$",
        "hooks": [{ "type": "command", "command": "bash '/Users/a/.claude/hooks/herdr-agent-state.sh' session", "timeout": 10 }] },
      { "matcher": "startup", "hooks": [{ "type": "command", "command": "echo mine" }, { "type": "prompt", "prompt": "p" }] },
      { "matcher": "^(startup|resume|clear|compact|fork)$",
        "hooks": [{ "type": "command", "command": "bash '/home/b c/.claude/hooks/herdr-agent-state.sh' session", "timeout": 10 }] }
    ]
  }
}
JSON
jq -f "$FILTER" "$TMP_ROOT/in.json" >"$TMP_ROOT/out.json" || fail "filter failed on a multi-machine settings.json"
got=$(herdr_commands "$TMP_ROOT/out.json")
[ "$got" = "$PORTABLE" ] || fail "entries from two machines must fold into one portable hook (got: $got)"
[ "$(jq -c '.hooks.SessionStart[1]' "$TMP_ROOT/out.json")" = '{"matcher":"startup","hooks":[{"type":"command","command":"echo mine"},{"type":"prompt","prompt":"p"}]}' ] \
  || fail "the filter must leave unrelated hooks untouched and in place"
[ "$(echo '{"a":1}' | jq -c -f "$FILTER")" = '{"a":1}' ] \
  || fail "a settings.json without hooks must pass through unchanged"

# The real install against a throwaway HOME, twice, so a herdr upgrade that
# changes the hook format shows up here rather than as duplicates in git.
if command -v herdr >/dev/null 2>&1; then
  mkdir -p "$TMP_ROOT/home/.claude"
  cp "$SETTINGS" "$TMP_ROOT/home/.claude/settings.json"
  for _ in 1 2; do
    HOME="$TMP_ROOT/home" herdr integration install claude >/dev/null 2>&1 \
      || fail "herdr integration install claude failed"
    jq -f "$FILTER" "$TMP_ROOT/home/.claude/settings.json" >"$TMP_ROOT/round.json" \
      || fail "filter failed on herdr's output"
    cp "$TMP_ROOT/round.json" "$TMP_ROOT/home/.claude/settings.json"
  done
  cmp -s "$TMP_ROOT/home/.claude/settings.json" "$SETTINGS" \
    || fail "herdr install + filter must reproduce the tracked settings.json exactly: $(diff "$SETTINGS" "$TMP_ROOT/home/.claude/settings.json")"
fi

pass "herdr's Claude hook stays one portable \$HOME entry across machines and rebuilds"
