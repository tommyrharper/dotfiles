#!/usr/bin/env bash
# Covers agent-skills.toml manifest parsing and check-script drift detection.
# Never touches the real ~/.agents/skills/ or ~/.agents/.skill-lock.json.
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

TMP_ROOT=$(dotfiles_test_tmproot agent-skills)
mkdir -p "$TMP_ROOT"

# --- manifest parsing ---------------------------------------------------

# shellcheck source=../agent-skills-lib.sh
. "$ROOT/agent-skills-lib.sh"

MANIFEST="$TMP_ROOT/manifest.toml"
cat > "$MANIFEST" <<'EOF'
# a comment
[alpha]
source = "org/alpha-repo"
path = "skills/alpha"

[beta]
source = "org/beta-repo"
EOF

agent_skills_parse_manifest "$MANIFEST" || fail "parser rejected a valid manifest"

[ "${#AGENT_SKILL_NAMES[@]}" -eq 2 ] || fail "expected 2 skills, got ${#AGENT_SKILL_NAMES[@]}"
[ "${AGENT_SKILL_SOURCE[alpha]}" = "org/alpha-repo" ] || fail "alpha source mismatched"
[ "${AGENT_SKILL_PATH[alpha]}" = "skills/alpha" ] || fail "alpha path mismatched"
[ "${AGENT_SKILL_SOURCE[beta]}" = "org/beta-repo" ] || fail "beta source mismatched"
[ "${AGENT_SKILL_PATH[beta]}" = "." ] || fail "beta path should default to '.'"

pass "manifest parsing extracts name/source/path with default path"

BAD_MANIFEST="$TMP_ROOT/bad.toml"
printf 'source = "org/repo"\n' > "$BAD_MANIFEST"
if agent_skills_parse_manifest "$BAD_MANIFEST" 2>/dev/null; then
  fail "parser accepted a key outside any [section]"
fi
pass "manifest parsing rejects a key outside any section"

# --- check script drift detection ---------------------------------------

SKILLS_DIR="$TMP_ROOT/skills"
mkdir -p "$SKILLS_DIR/alpha" "$SKILLS_DIR/undeclared-tool"

LOCK_FILE="$TMP_ROOT/lock.json"
cat > "$LOCK_FILE" <<'EOF'
{"skills":{"alpha":{},"ghost-skill":{}}}
EOF

OUTPUT=$("$ROOT/agent-skills-check.sh" --manifest "$MANIFEST" --skills-dir "$SKILLS_DIR" --lock "$LOCK_FILE") \
  || fail "check script exited non-zero on a well-formed manifest"

assert_contains "$OUTPUT" "declared-and-installed ==
  alpha" "alpha should be declared-and-installed"
assert_contains "$OUTPUT" "declared-but-missing ==
  beta" "beta should be declared-but-missing"
assert_contains "$OUTPUT" "installed-but-undeclared ==
  undeclared-tool" "undeclared-tool should be installed-but-undeclared"
assert_contains "$OUTPUT" "stale lock entries" "should report a stale lock entries section"
assert_contains "$OUTPUT" "ghost-skill" "ghost-skill should be flagged as a stale lock entry"
assert_not_contains "$OUTPUT" "  alpha
== stale" "alpha has a folder on disk and must not be flagged stale"

pass "check script reports all four drift categories"

# --- sync script dry-run makes no filesystem changes ---------------------

DEST="$TMP_ROOT/dry-run-dest"
"$ROOT/agent-skills-sync.sh" --manifest "$MANIFEST" --dest "$DEST" --dry-run >/dev/null \
  || fail "sync --dry-run exited non-zero"
[ -d "$DEST" ] && fail "sync --dry-run must not create the destination directory"

pass "sync --dry-run makes no filesystem changes"
