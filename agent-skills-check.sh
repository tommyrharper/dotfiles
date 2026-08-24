#!/usr/bin/env bash
# agent-skills-check.sh - report drift between agent-skills.toml, the
# installed skill folders, and the skill-lock.json bookkeeping file.
# Read-only: never writes anything.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=agent-skills-lib.sh
. "$DIR/agent-skills-lib.sh"

MANIFEST="$DIR/agent-skills.toml"
SKILLS_DIR="$HOME/.agents/skills"
LOCK_FILE="$HOME/.agents/.skill-lock.json"

while [ $# -gt 0 ]; do
  case "$1" in
    --manifest) MANIFEST=$2; shift 2 ;;
    --skills-dir) SKILLS_DIR=$2; shift 2 ;;
    --lock) LOCK_FILE=$2; shift 2 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

agent_skills_parse_manifest "$MANIFEST"

declare -A installed=()
if [ -d "$SKILLS_DIR" ]; then
  for d in "$SKILLS_DIR"/*/; do
    [ -d "$d" ] || continue
    installed["$(basename "$d")"]=1
  done
fi

declare -A declared=()
for name in "${AGENT_SKILL_NAMES[@]}"; do
  declared["$name"]=1
done

echo "== declared-and-installed =="
any=0
for name in "${AGENT_SKILL_NAMES[@]}"; do
  if [ -n "${installed[$name]:-}" ]; then
    echo "  $name"
    any=1
  fi
done
[ "$any" = 1 ] || echo "  (none)"

echo "== declared-but-missing =="
any=0
for name in "${AGENT_SKILL_NAMES[@]}"; do
  if [ -z "${installed[$name]:-}" ]; then
    echo "  $name (source: ${AGENT_SKILL_SOURCE[$name]})"
    any=1
  fi
done
[ "$any" = 1 ] || echo "  (none)"

echo "== installed-but-undeclared =="
undeclared=()
for name in "${!installed[@]}"; do
  [ -z "${declared[$name]:-}" ] && undeclared+=("$name")
done
if [ "${#undeclared[@]}" -gt 0 ]; then
  printf '  %s\n' "${undeclared[@]}" | sort
else
  echo "  (none)"
fi

echo "== stale lock entries (declared in .skill-lock.json but no folder on disk) =="
any=0
if [ -f "$LOCK_FILE" ]; then
  if ! lock_names=$(jq -r 'if (.skills | type) == "object" then (.skills | keys[]) else error(".skills must be an object") end' "$LOCK_FILE"); then
    echo "agent-skills: failed to parse lock file: $LOCK_FILE" >&2
    exit 1
  fi
  while IFS= read -r name; do
    [ -z "$name" ] && continue
    if [ -z "${installed[$name]:-}" ]; then
      echo "  $name"
      any=1
    fi
  done <<< "$lock_names"
else
  echo "  (lock file not found: $LOCK_FILE)"
  any=1
fi
[ "$any" = 1 ] || echo "  (none)"
