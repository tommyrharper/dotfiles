#!/usr/bin/env bash
# Covers agent-capabilities.sh (check/sync) against a fixture $HOME with stub
# `skills`/`claude` binaries - never touches the real ~/.agents/skills,
# ~/.claude/skills, or plugin state.
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

if ! command -v nix >/dev/null 2>&1; then
  echo "skip: nix not found for TOML parsing (builtins.fromTOML)"
  exit 0
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "skip: jq not found"
  exit 0
fi

SCRIPT="$ROOT/agent-capabilities.sh"
TMP_ROOT=$(dotfiles_test_tmproot agent-capabilities)
FIXTURE_HOME="$TMP_ROOT/home"
FIXTURE_BIN="$TMP_ROOT/bin"
FIXTURE_MANIFEST="$TMP_ROOT/fixture.toml"
CALL_LOG="$TMP_ROOT/calls.log"

mkdir -p "$FIXTURE_HOME/.agents/skills" "$FIXTURE_HOME/.claude/skills" "$FIXTURE_BIN"
: >"$CALL_LOG"

cat >"$FIXTURE_MANIFEST" <<'EOF'
[[capability]]
name = "fixture-skill"
kind = "skill"
source = "acme/fixture-skill"
targets = ["codex", "claude"]

[[capability]]
name = "fixture-local-skill"
kind = "skill"
source = "local"
targets = ["codex"]

[[capability]]
name = "fixture-plugin"
kind = "plugin"
source = "acme/fixture-plugin"
id = "fixture-plugin@acme"
targets = ["claude"]

[[capability]]
name = "fixture-orphan-plugin"
kind = "plugin"
source = "acme/fixture-orphan-plugin"
id = "fixture-orphan-plugin@acme"
targets = ["pi"]

[[capability]]
name = "fixture-ext"
kind = "pi-extension"
source = "repo"
targets = ["pi"]
EOF

# --- stub CLIs: log every call, answer canned data, never touch the network -
cat >"$FIXTURE_BIN/skills" <<EOF
#!/usr/bin/env bash
echo "skills \$*" >>"$CALL_LOG"
if [ "\$1" = "ls" ]; then
  echo '[{"name":"fixture-skill","agents":["Codex"]},{"name":"undeclared-skill","agents":["Codex"]}]'
  exit 0
fi
if [ "\$1" = "add" ]; then
  # simulate the real installer creating the skill directory
  mkdir -p "$FIXTURE_HOME/.agents/skills/\$2"
  echo "installed" > "$FIXTURE_HOME/.agents/skills/\$2/SKILL.md"
  exit 0
fi
exit 0
EOF

cat >"$FIXTURE_BIN/claude" <<EOF
#!/usr/bin/env bash
echo "claude \$*" >>"$CALL_LOG"
if [ "\$1" = "plugin" ] && [ "\$2" = "list" ]; then
  echo '[{"id":"fixture-plugin@acme","enabled":true}]'
  exit 0
fi
exit 0
EOF
chmod +x "$FIXTURE_BIN/skills" "$FIXTURE_BIN/claude"

run_caps() {
  HOME="$FIXTURE_HOME" PATH="$FIXTURE_BIN:$PATH" "$SCRIPT" "$@"
}

# --- manifest parsing ---------------------------------------------------

count=$(nix eval --impure --json --expr "builtins.fromTOML (builtins.readFile \"$FIXTURE_MANIFEST\")" | jq '.capability | length')
[ "$count" = "5" ] || fail "expected 5 fixture capabilities, got $count"
pass "manifest parses all declared capabilities"

# --- optional `path` defaults to "." ------------------------------------

default_path=$(nix eval --impure --json --expr "builtins.fromTOML (builtins.readFile \"$FIXTURE_MANIFEST\")" \
  | jq -r '.capability[] | select(.name == "fixture-ext") | .path // "."')
[ "$default_path" = "." ] || fail "expected omitted path to default to '.', got '$default_path'"
pass "omitted path field defaults to '.'"

# --- per-target resolution: installed on codex, missing on claude -------

: >"$CALL_LOG"
mkdir -p "$FIXTURE_HOME/.agents/skills/fixture-skill" "$FIXTURE_HOME/.agents/skills/undeclared-skill"
check_json=$(run_caps check --json --manifest "$FIXTURE_MANIFEST")

codex_status=$(jq -r '.[] | select(.name=="fixture-skill" and .target=="codex") | .status' <<<"$check_json")
claude_status=$(jq -r '.[] | select(.name=="fixture-skill" and .target=="claude") | .status' <<<"$check_json")
[ "$codex_status" = "installed" ] || fail "expected fixture-skill/codex installed, got $codex_status"
[ "$claude_status" = "declared-but-missing" ] || fail "expected fixture-skill/claude missing, got $claude_status"
pass "check resolves install state independently per target"

# --- installed-but-undeclared -------------------------------------------

undeclared=$(jq -r '.[] | select(.name=="undeclared-skill") | .status' <<<"$check_json")
[ "$undeclared" = "installed-but-undeclared" ] || fail "expected undeclared-skill to be flagged, got '$undeclared'"
pass "check flags skills present on disk but absent from the manifest"

# --- manual-action-required: local source, unsupported plugin target ----

local_status=$(jq -r '.[] | select(.name=="fixture-local-skill") | .status' <<<"$check_json")
[ "$local_status" = "manual-action-required" ] || fail "expected local-source skill to be manual-action-required, got $local_status"

orphan_status=$(jq -r '.[] | select(.name=="fixture-orphan-plugin") | .status' <<<"$check_json")
[ "$orphan_status" = "manual-action-required" ] || fail "expected plugin with no plugin-CLI target to be manual-action-required, got $orphan_status"
pass "check reports manual-action-required for local-source skills and unsupported plugin targets"

# --- stale lock entries ---------------------------------------------------

cat >"$FIXTURE_HOME/.agents/.skill-lock.json" <<'EOF'
{"skills": {"fixture-skill": {"source": "acme/fixture-skill"}, "stale-ghost": {"source": "acme/ghost"}}}
EOF
check_json=$(run_caps check --json --manifest "$FIXTURE_MANIFEST")
stale_status=$(jq -r '.[] | select(.name=="stale-ghost") | .status' <<<"$check_json")
[ "$stale_status" = "stale-lock-entry" ] || fail "expected stale-ghost to be flagged stale, got '$stale_status'"
not_stale=$(jq -r '[.[] | select(.name=="fixture-skill" and .status=="stale-lock-entry")] | length' <<<"$check_json")
[ "$not_stale" = "0" ] || fail "fixture-skill has a matching directory and must not be reported stale"
pass "check detects a lock entry with no matching on-disk skill directory"
rm -f "$FIXTURE_HOME/.agents/.skill-lock.json"

# --- sync refuses to touch a pre-existing, never-synced directory --------

: >"$CALL_LOG"
out=$(run_caps sync --manifest "$FIXTURE_MANIFEST" --only skill 2>&1)
assert_contains "$out" "never synced by this tool" "sync should refuse an unmanaged pre-existing skill dir without --force"
[ -s "$CALL_LOG" ] && fail "sync must not invoke skills/claude when it refuses to adopt an unmanaged directory"
pass "sync refuses to adopt a pre-existing unmanaged skill directory without --force"

# --- sync --force adopts it, records state, is idempotent ----------------

: >"$CALL_LOG"
out=$(run_caps sync --manifest "$FIXTURE_MANIFEST" --only skill --force 2>&1)
assert_contains "$out" "synced: skill 'fixture-skill'" "forced sync should report success"
assert_contains "$(cat "$CALL_LOG")" "skills add acme/fixture-skill" "forced sync should call \`skills add\` with the declared source"
pass "sync --force adopts a pre-existing directory and calls the skills CLI"

# --- local modification after a recorded sync is refused without --force -

echo "hand-edited" >"$FIXTURE_HOME/.agents/skills/fixture-skill/local-change.md"
: >"$CALL_LOG"
out=$(run_caps sync --manifest "$FIXTURE_MANIFEST" --only skill 2>&1)
assert_contains "$out" "local modifications" "sync should detect drift from the recorded hash"
[ -s "$CALL_LOG" ] && fail "sync must not overwrite local modifications without --force"
pass "sync refuses to overwrite local modifications made since the last sync"

# --- local-source skills always report manual action, never call skills --

: >"$CALL_LOG"
out=$(run_caps sync --manifest "$FIXTURE_MANIFEST" --only skill --force 2>&1)
assert_contains "$out" "manual-action-required: skill 'fixture-local-skill'" "local-source skill must report manual action"
assert_not_contains "$(cat "$CALL_LOG")" "fixture-local-skill" "sync must never call the skills CLI for a local-source entry"
pass "sync reports manual-action-required for local-source skills instead of guessing a source"

# --- plugin sync: already installed is a no-op, otherwise installs -------

: >"$CALL_LOG"
out=$(run_caps sync --manifest "$FIXTURE_MANIFEST" --only plugin 2>&1)
assert_contains "$out" "already installed: plugin 'fixture-plugin'" "already-installed plugin should be a no-op"
assert_not_contains "$(cat "$CALL_LOG")" "marketplace add" "sync must not reinstall an already-installed plugin"
assert_not_contains "$(cat "$CALL_LOG")" "plugin install" "sync must not reinstall an already-installed plugin"
pass "plugin sync is idempotent against an already-installed plugin"

cat >"$FIXTURE_BIN/claude" <<EOF
#!/usr/bin/env bash
echo "claude \$*" >>"$CALL_LOG"
if [ "\$1" = "plugin" ] && [ "\$2" = "list" ]; then
  echo '[]'
  exit 0
fi
exit 0
EOF
: >"$CALL_LOG"
out=$(run_caps sync --manifest "$FIXTURE_MANIFEST" --only plugin 2>&1)
assert_contains "$out" "synced: plugin 'fixture-plugin'" "missing plugin should be installed"
assert_contains "$(cat "$CALL_LOG")" "plugin marketplace add acme/fixture-plugin" "sync should add the declared marketplace"
assert_contains "$(cat "$CALL_LOG")" "plugin install fixture-plugin@acme" "sync should install the declared plugin id"
pass "plugin sync installs a declared-but-missing plugin via the claude plugin CLI"

pass "agent-capabilities.sh check/sync behave correctly against fixtures"
