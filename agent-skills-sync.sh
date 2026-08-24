#!/usr/bin/env bash
# agent-skills-sync.sh - install/update every skill declared in
# agent-skills.toml into the personal skills directory (default
# ~/.agents/skills/). Idempotent: safe to re-run, each run re-fetches and
# overwrites the declared skill folders to match the manifest.
#
# --dry-run prints the planned clone/copy per skill without cloning or writing
# files. --dest lets tests point at a scratch directory
# instead of the real ~/.agents/skills/.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=agent-skills-lib.sh
. "$DIR/agent-skills-lib.sh"

MANIFEST="$DIR/agent-skills.toml"
SKILLS_DIR="$HOME/.agents/skills"
DRY_RUN=0

while [ $# -gt 0 ]; do
	case "$1" in
	--manifest)
		MANIFEST=$2
		shift 2
		;;
	--dest)
		SKILLS_DIR=$2
		shift 2
		;;
	--dry-run)
		DRY_RUN=1
		shift
		;;
	*)
		echo "unknown argument: $1" >&2
		exit 2
		;;
	esac
done

agent_skills_parse_manifest "$MANIFEST"

for name in "${AGENT_SKILL_NAMES[@]}"; do
	repo="${AGENT_SKILL_SOURCE[$name]}"
	path="${AGENT_SKILL_PATH[$name]}"
	dest="$SKILLS_DIR/$name"

	if [ "$DRY_RUN" = 1 ]; then
		echo "[dry-run] $name: clone https://github.com/$repo.git, copy '$path' -> $dest"
		continue
	fi

	echo "==> $name (from $repo, path: $path)"
	tmp="$(mktemp -d)"

	git clone --depth 1 --quiet "https://github.com/$repo.git" "$tmp/repo"

	src_path="$tmp/repo/$path"
	[ -d "$src_path" ] || {
		echo "agent-skills: $name: path '$path' not found in $repo" >&2
		rm -rf "$tmp"
		exit 1
	}
	[ -f "$src_path/SKILL.md" ] || {
		echo "agent-skills: $name: no SKILL.md under '$path' in $repo" >&2
		rm -rf "$tmp"
		exit 1
	}

	mkdir -p "$SKILLS_DIR"
	rm -rf "$dest"
	cp -R "$src_path" "$dest"
	rm -rf "$dest/.git"

	rm -rf "$tmp"
done

[ "$DRY_RUN" = 1 ] && echo "dry-run complete: no files changed" || echo "sync complete"
