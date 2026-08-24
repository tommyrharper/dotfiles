#!/usr/bin/env bash
# Check/sync agent-capabilities.toml (skills, plugins, Pi extras) against the
# real state on this machine. See README.md, "Agent capabilities".
#
# Never touches runtime/cache/plugin internals - only:
#   - ~/.agents/skills, ~/.claude/skills (via the `skills` CLI)
#   - Claude Code plugins (via `claude plugin`)
#   - Codex plugins (via `codex plugin`)
#   - reading (never writing) home.nix-managed Pi paths for drift checks
#
# Testability: every real-world path/command below is derived from $HOME and
# $PATH, so tests run this against a fixture $HOME with stub `skills`/
# `claude`/`codex` binaries on $PATH instead of the real machine state.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
MANIFEST="$ROOT/agent-capabilities.toml"
STATE_DIR="${AGENT_CAPABILITIES_STATE_DIR:-$HOME/.cache/agent-capabilities}"
STATE_FILE="$STATE_DIR/sync-state.json"

usage() {
  cat <<'EOF'
Usage:
  agent-capabilities.sh check [--json] [--manifest PATH]
  agent-capabilities.sh sync  [--force] [--dry-run] [--manifest PATH] [--only KIND]

check   Report declared vs installed/enabled per target and kind: missing,
        undeclared, stale lock entries, manual-action-required.
sync    Install/update declared skills and plugins via their own CLIs
        (`skills`, `claude plugin`, `codex plugin`). Idempotent. Skips (and
        reports) any target whose local content changed since the last sync,
        unless --force is passed. Pi extras are always no-op (Home Manager
        owns them; see ./rebuild.sh).

--manifest PATH   Use PATH instead of ./agent-capabilities.toml (for tests).
--only KIND       sync only entries of this kind (skill|plugin).
EOF
}

json_mode=0
force=0
dry_run=0
only_kind=""
cmd="${1:-}"
[ $# -gt 0 ] && shift || true

while [ $# -gt 0 ]; do
  case "$1" in
    --json) json_mode=1 ;;
    --force) force=1 ;;
    --dry-run) dry_run=1 ;;
    --manifest) MANIFEST="$2"; shift ;;
    --only) only_kind="$2"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown option: $1" >&2; usage >&2; exit 1 ;;
  esac
  shift
done

if [ -z "$cmd" ] || { [ "$cmd" != "check" ] && [ "$cmd" != "sync" ]; }; then
  usage >&2
  exit 1
fi

if [ ! -f "$MANIFEST" ]; then
  echo "manifest not found: $MANIFEST" >&2
  exit 1
fi
if ! command -v nix >/dev/null 2>&1; then
  echo "nix not found (needed to parse TOML via builtins.fromTOML)" >&2
  exit 1
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "jq not found" >&2
  exit 1
fi

manifest_json() {
  nix eval --impure --json --expr \
    "builtins.fromTOML (builtins.readFile \"$MANIFEST\")" 2>/dev/null
}

# --- skills CLI helpers -------------------------------------------------

# Maps our target vocabulary to the display name `skills ls --json` uses,
# and to the slug `skills add --agent` expects. opencode is check-only:
# it reads the Codex/Claude skill directories as compatibility sources.
skill_agent_display() {
  case "$1" in
    codex) echo "Codex" ;;
    claude) echo "Claude Code" ;;
    opencode) echo "OpenCode" ;;
    *) echo "" ;;
  esac
}
skill_agent_slug() {
  case "$1" in
    codex) echo "codex" ;;
    claude) echo "claude-code" ;;
    opencode) echo "" ;;
    *) echo "" ;;
  esac
}

skills_installed_json() {
  if command -v skills >/dev/null 2>&1; then
    skills ls -g --json 2>/dev/null || echo "[]"
  else
    echo "[]"
  fi
}

skill_dir_for_target() {
  local name="$1" target="$2"
  case "$target" in
    codex) echo "$HOME/.agents/skills/$name" ;;
    claude) echo "$HOME/.claude/skills/$name" ;;
    opencode)
      # opencode natively reads ~/.agents/skills and ~/.claude/skills as
      # "global compatibility" sources (see README) - no separate copy is
      # required, so treat either as satisfying the opencode target.
      if [ -e "$HOME/.agents/skills/$name" ]; then
        echo "$HOME/.agents/skills/$name"
      elif [ -e "$HOME/.claude/skills/$name" ]; then
        echo "$HOME/.claude/skills/$name"
      else
        echo "$HOME/.config/opencode/skills/$name"
      fi
      ;;
    *) echo "" ;;
  esac
}

# --- plugin CLI helpers --------------------------------------------------

claude_installed_json() {
  if command -v claude >/dev/null 2>&1; then
    claude plugin list --json 2>/dev/null || echo "[]"
  else
    echo "[]"
  fi
}

codex_plugin_installed() {
  # codex plugin list has no --json; best-effort text match.
  local id="$1"
  command -v codex >/dev/null 2>&1 || return 1
  codex plugin list 2>/dev/null | grep -F "$id" | grep -q "installed"
}

# --- content hashing for refuse-to-overwrite -----------------------------

content_hash() {
  local dir="$1"
  if [ ! -e "$dir" ]; then
    echo ""
    return
  fi
  if [ -f "$dir" ]; then
    sha256sum "$dir" | cut -d' ' -f1
    return
  fi
  # ponytail: assumes no filenames containing newlines; skill directories are
  # git-cloned/tool-installed content, not adversarial input. Switch to NUL-
  # delimited find/sort/xargs if that stops holding.
  find "$dir" -type f | LC_ALL=C sort | xargs -I{} sha256sum "{}" 2>/dev/null \
    | sha256sum | cut -d' ' -f1
}

state_get() {
  local key="$1"
  [ -f "$STATE_FILE" ] || { echo ""; return; }
  jq -r --arg k "$key" '.[$k] // ""' "$STATE_FILE"
}

state_set() {
  local key="$1" value="$2"
  mkdir -p "$STATE_DIR"
  local cur="{}"
  [ -f "$STATE_FILE" ] && cur="$(cat "$STATE_FILE")"
  echo "$cur" | jq --arg k "$key" --arg v "$value" '.[$k] = $v' >"$STATE_FILE.tmp"
  mv "$STATE_FILE.tmp" "$STATE_FILE"
}

# =========================================================================
# check
# =========================================================================

run_check() {
  local manifest installed_skills installed_claude_plugins
  manifest="$(manifest_json)"
  installed_skills="$(skills_installed_json)"
  installed_claude_plugins="$(claude_installed_json)"

  local rows="[]"

  # declared entries: missing / installed / manual-action-required
  while IFS= read -r entry; do
    local name kind source targets_json id
    name="$(jq -r '.name' <<<"$entry")"
    kind="$(jq -r '.kind' <<<"$entry")"
    source="$(jq -r '.source' <<<"$entry")"
    id="$(jq -r '.id // ""' <<<"$entry")"
    targets_json="$(jq -c '.targets' <<<"$entry")"

    while IFS= read -r target; do
      local status detail
      case "$kind" in
        skill)
          if [ "$source" = "local" ]; then
            status="manual-action-required"
            detail="no reproducible remote source (source = local)"
          else
            local dir
            dir="$(skill_dir_for_target "$name" "$target")"
            if [ -n "$dir" ] && [ -e "$dir" ]; then
              status="installed"; detail="$dir"
            else
              status="declared-but-missing"; detail="expected $dir"
            fi
          fi
          ;;
        plugin)
          if [ "$target" = "claude" ]; then
            if jq -e --arg id "$id" '.[] | select(.id == $id)' <<<"$installed_claude_plugins" >/dev/null; then
              status="installed"
              detail="$(jq -r --arg id "$id" '.[] | select(.id == $id) | "enabled=\(.enabled)"' <<<"$installed_claude_plugins")"
            else
              status="declared-but-missing"; detail="not in \`claude plugin list\`"
            fi
          elif [ "$target" = "codex" ]; then
            if codex_plugin_installed "$id"; then
              status="installed"; detail="via codex plugin list"
            else
              status="declared-but-missing"; detail="not in \`codex plugin list\`"
            fi
          else
            status="manual-action-required"; detail="no plugin CLI for target $target"
          fi
          ;;
        pi-extension|pi-theme)
          local repo_path="$ROOT/$(jq -r '.path // "."' <<<"$entry")"
          local base linked
          base="$(basename "$repo_path")"
          if [ "$kind" = "pi-extension" ]; then
            linked="$HOME/.pi/agent/extensions/$base"
          else
            linked="$HOME/.pi/agent/themes/$base"
          fi
          if [ ! -e "$repo_path" ]; then
            status="declared-but-missing"; detail="missing in repo: $repo_path"
          elif [ ! -e "$linked" ]; then
            status="declared-but-missing"; detail="not linked at $linked (run ./rebuild.sh)"
          else
            status="installed"; detail="$linked"
          fi
          ;;
        *)
          status="manual-action-required"; detail="unknown kind: $kind"
          ;;
      esac
      rows="$(jq --arg name "$name" --arg kind "$kind" --arg target "$target" \
                 --arg status "$status" --arg detail "$detail" \
                 '. + [{name:$name, kind:$kind, target:$target, status:$status, detail:$detail}]' <<<"$rows")"
    done < <(jq -r '.[]' <<<"$targets_json")
  done < <(jq -c '.capability[]' <<<"$manifest")

  # installed-but-undeclared skills (codex/claude dirs)
  for target in codex claude; do
    local dir declared_names
    dir="$([ "$target" = codex ] && echo "$HOME/.agents/skills" || echo "$HOME/.claude/skills")"
    declared_names="$(jq -r --arg t "$target" \
      '[.capability[] | select(.kind == "skill" and (.targets | index($t))) | .name]' <<<"$manifest")"
    [ -d "$dir" ] || continue
    for entry_dir in "$dir"/*/; do
      [ -d "$entry_dir" ] || continue
      local n
      n="$(basename "$entry_dir")"
      if ! jq -e --arg n "$n" 'index($n)' <<<"$declared_names" >/dev/null; then
        rows="$(jq --arg name "$n" --arg target "$target" \
          '. + [{name:$name, kind:"skill", target:$target, status:"installed-but-undeclared", detail:"present on disk, not in manifest"}]' <<<"$rows")"
      fi
    done
  done

  # installed-but-undeclared claude plugins
  local declared_ids
  declared_ids="$(jq -r '[.capability[] | select(.kind == "plugin") | .id]' <<<"$manifest")"
  while IFS= read -r pid; do
    [ -n "$pid" ] || continue
    if ! jq -e --arg p "$pid" 'index($p)' <<<"$declared_ids" >/dev/null; then
      rows="$(jq --arg name "$pid" \
        '. + [{name:$name, kind:"plugin", target:"claude", status:"installed-but-undeclared", detail:"present in claude plugin list, not in manifest"}]' <<<"$rows")"
    fi
  done < <(jq -r '.[].id' <<<"$installed_claude_plugins")

  # stale lock entries: named in ~/.agents/.skill-lock.json but no dir on disk
  local lock_file="$HOME/.agents/.skill-lock.json"
  if [ -f "$lock_file" ]; then
    while IFS= read -r n; do
      [ -n "$n" ] || continue
      if [ ! -e "$HOME/.agents/skills/$n" ]; then
        rows="$(jq --arg name "$n" \
          '. + [{name:$name, kind:"skill", target:"codex", status:"stale-lock-entry", detail:"in ~/.agents/.skill-lock.json but not on disk"}]' <<<"$rows")"
      fi
    done < <(jq -r '.skills // {} | keys[]' "$lock_file" 2>/dev/null)
  fi

  if [ "$json_mode" = 1 ]; then
    echo "$rows" | jq .
    return
  fi

  echo "$rows" | jq -r '
    group_by(.status) | .[] |
    "== \(.[0].status) ==",
    (.[] | "  \(.kind)/\(.target)  \(.name)  -  \(.detail)"),
    ""
  '
}

# =========================================================================
# sync
# =========================================================================

sync_skill() {
  local name="$1" source="$2" targets_json="$3"
  if [ "$source" = "local" ]; then
    echo "manual-action-required: skill '$name' has no reproducible source (source = local)"
    return
  fi

  local slugs=()
  local dirs=()
  local keys=()
  while IFS= read -r target; do
    local slug dir key last_hash cur_hash
    slug="$(skill_agent_slug "$target")"
    [ -n "$slug" ] || continue

    dir="$(skill_dir_for_target "$name" "$target")"
    key="skill:$name:$target"
    last_hash="$(state_get "$key")"
    cur_hash="$(content_hash "$dir")"

    if [ -e "$dir" ] && [ -z "$last_hash" ] && [ "$force" != 1 ]; then
      echo "skip: skill '$name' target '$target' exists at $dir but was never synced by this tool; rerun with --force to adopt it"
      continue
    fi
    if [ -e "$dir" ] && [ -n "$last_hash" ] && [ "$last_hash" != "$cur_hash" ] && [ "$force" != 1 ]; then
      echo "skip: skill '$name' target '$target' has local modifications since last sync; rerun with --force to overwrite"
      continue
    fi

    slugs+=("$slug")
    dirs+=("$dir")
    keys+=("$key")
  done < <(jq -r '.[]' <<<"$targets_json")
  [ "${#slugs[@]}" -gt 0 ] || { echo "skip: skill '$name' has no skills-CLI target"; return; }

  if [ "$dry_run" = 1 ]; then
    echo "dry-run: skills add $source -g --agent ${slugs[*]} -y"
    return
  fi
  if ! command -v skills >/dev/null 2>&1; then
    echo "manual-action-required: skill '$name' declared but the \`skills\` CLI is not installed"
    return
  fi
  skills add "$source" -g --agent "${slugs[@]}" -y
  local i
  for i in "${!keys[@]}"; do
    state_set "${keys[$i]}" "$(content_hash "${dirs[$i]}")"
  done
  echo "synced: skill '$name' ($source) -> ${slugs[*]}"
}

sync_plugin() {
  local name="$1" source="$2" id="$3" targets_json="$4"
  if ! jq -e 'index("claude")' <<<"$targets_json" >/dev/null; then
    echo "manual-action-required: plugin '$name' has no supported sync target"
    return
  fi
  if ! command -v claude >/dev/null 2>&1; then
    echo "manual-action-required: plugin '$name' declared but the \`claude\` CLI is not installed"
    return
  fi
  local installed
  installed="$(claude_installed_json)"
  if jq -e --arg id "$id" '.[] | select(.id == $id)' <<<"$installed" >/dev/null; then
    echo "already installed: plugin '$name' ($id)"
    return
  fi
  if [ "$dry_run" = 1 ]; then
    echo "dry-run: claude plugin marketplace add $source && claude plugin install $id"
    return
  fi
  claude plugin marketplace add "$source"
  claude plugin install "$id"
  echo "synced: plugin '$name' ($id)"
}

run_sync() {
  local manifest
  manifest="$(manifest_json)"

  while IFS= read -r entry; do
    local name kind source id targets_json
    name="$(jq -r '.name' <<<"$entry")"
    kind="$(jq -r '.kind' <<<"$entry")"
    source="$(jq -r '.source' <<<"$entry")"
    id="$(jq -r '.id // ""' <<<"$entry")"
    targets_json="$(jq -c '.targets' <<<"$entry")"

    [ -n "$only_kind" ] && [ "$kind" != "$only_kind" ] && continue

    case "$kind" in
      skill) sync_skill "$name" "$source" "$targets_json" ;;
      plugin) sync_plugin "$name" "$source" "$id" "$targets_json" ;;
      pi-extension|pi-theme)
        echo "no-op: '$name' ($kind) is managed by Home Manager - run ./rebuild.sh"
        ;;
      *) echo "manual-action-required: unknown kind '$kind' for '$name'" ;;
    esac
  done < <(jq -c '.capability[]' <<<"$manifest")
}

case "$cmd" in
  check) run_check ;;
  sync) run_sync ;;
esac
