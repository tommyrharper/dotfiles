#!/usr/bin/env bash
# agent-skills-lib.sh - shared manifest parsing for agent-skills-{sync,check}.sh
#
# Source this, then call agent_skills_parse_manifest <file>. It populates:
#   AGENT_SKILL_NAMES     (array of skill names, in manifest order)
#   AGENT_SKILL_SOURCE    (assoc array: name -> "org/repo")
#   AGENT_SKILL_PATH      (assoc array: name -> path within repo, default ".")

if [ -n "${AGENT_SKILLS_LIB_SOURCED:-}" ]; then
  return 0
fi
AGENT_SKILLS_LIB_SOURCED=1

agent_skills_parse_manifest() {
  local file=$1
  local section="" key val

  AGENT_SKILL_NAMES=()
  declare -gA AGENT_SKILL_SOURCE=()
  declare -gA AGENT_SKILL_PATH=()

  [ -f "$file" ] || { echo "agent-skills: manifest not found: $file" >&2; return 1; }

  while IFS= read -r line; do
    line="${line%%#*}"
    line="$(printf '%s' "$line" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')"
    [ -z "$line" ] && continue

    if [[ "$line" =~ ^\[([A-Za-z0-9_-]+)\]$ ]]; then
      section="${BASH_REMATCH[1]}"
      AGENT_SKILL_NAMES+=("$section")
      AGENT_SKILL_PATH["$section"]="."
      continue
    fi

    if [[ "$line" =~ ^([A-Za-z0-9_]+)[[:space:]]*=[[:space:]]*\"(.*)\"$ ]]; then
      key="${BASH_REMATCH[1]}"
      val="${BASH_REMATCH[2]}"
      [ -z "$section" ] && { echo "agent-skills: $file: '$key' outside any [section]" >&2; return 1; }
      case "$key" in
        source) AGENT_SKILL_SOURCE["$section"]="$val" ;;
        path) AGENT_SKILL_PATH["$section"]="$val" ;;
        *) echo "agent-skills: $file: unknown key '$key' in [$section]" >&2; return 1 ;;
      esac
      continue
    fi

    echo "agent-skills: $file: unparseable line: $line" >&2
    return 1
  done < "$file"

  for section in "${AGENT_SKILL_NAMES[@]}"; do
    [ -n "${AGENT_SKILL_SOURCE[$section]:-}" ] || { echo "agent-skills: $file: [$section] missing 'source'" >&2; return 1; }
  done
}
