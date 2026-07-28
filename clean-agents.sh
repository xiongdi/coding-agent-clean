#!/usr/bin/env bash
# coding-agent-clean / clean-agents.sh
# Reset coding agents to a "just installed" state by wiping local config/cache/auth/state.
#
# Reads agents.json (same directory) and deletes the local state of every coding agent
# found on this machine. Supports --dry-run (default), --backup, project-local cleanup,
# and per-agent / per-category filtering.
#
# Usage:
#   ./clean-agents.sh                         # dry run, all agents
#   ./clean-agents.sh --apply                 # actually wipe everything found
#   ./clean-agents.sh --backup --apply        # backup then wipe
#   ./clean-agents.sh --agents claude-code,cursor --apply
#   ./clean-agents.sh --include-project-local --project-roots ~/workspace --apply
#   ./clean-agents.sh --marketplaces --apply  # only wipe marketplace state (keeps sessions/settings)
#
# Options:
#   --apply                 Actually delete/backup. Without this, only a dry-run is shown.
#   --backup                Move state to a timestamped backup dir instead of deleting.
#   --backup-dir <path>     Root dir for backups (default: ./backups/<timestamp>/)
#   --agents <list>         Comma-separated agent ids (default: all)
#   --cloud-too             Also list cloud-only agents (skipped by default)
#   --include-project-local Wipe project-local config (.clinerules, .cursor/rules, ...)
#   --project-roots <roots> Roots to scan for project-local config (repeatable; default: $PWD)
#   --json <path>           Path to agents.json (default: same dir as this script)
#   --marketplaces          Only wipe marketplace state (plugins/marketplaces, plugin-catalog-cache,
#                           known_marketplaces.json, cache/). Keeps sessions, settings, auth. Useful for
#                           resetting the official marketplace without nuking the whole ~/.claude tree.

set -euo pipefail

# --- defaults ---
APPLY=0
BACKUP=0
BACKUP_DIR=""
AGENTS=""
CLOUD_TOO=0
INCLUDE_PROJECT_LOCAL=0
PROJECT_ROOTS=()
JSON_PATH=""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ -z "$JSON_PATH" ]] && JSON_PATH="$SCRIPT_DIR/agents.json"

# --- parse args ---
while [[ $# -gt 0 ]]; do
    case "$1" in
        --apply) APPLY=1 ;;
        --backup) BACKUP=1 ;;
        --backup-dir) BACKUP_DIR="$2"; shift ;;
        --agents) AGENTS="$2"; shift ;;
        --cloud-too) CLOUD_TOO=1 ;;
        --include-project-local) INCLUDE_PROJECT_LOCAL=1 ;;
        --project-roots)
            shift
            # collect until next --flag
            while [[ $# -gt 0 && ! "$1" =~ ^-- ]]; do
                PROJECT_ROOTS+=("$1"); shift
            done
            continue ;;
        --json) JSON_PATH="$2"; shift ;;
        -h|--help)
            sed -n '2,20p' "$0" | sed 's/^# \?//'; exit 0 ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
    shift
done

[[ ${#PROJECT_ROOTS[@]} -eq 0 ]] && PROJECT_ROOTS=("$PWD")

if [[ ! -f "$JSON_PATH" ]]; then
    echo "ERROR: agents.json not found at $JSON_PATH. Use --json to specify." >&2
    exit 1
fi

# --- requires jq ---
if ! command -v jq &>/dev/null; then
    echo "ERROR: jq is required but not installed." >&2
    echo "  macOS:  brew install jq" >&2
    echo "  Linux:  sudo apt install jq  (or your distro equivalent)" >&2
    exit 1
fi

# --- helpers ---
# expand ~, %USERPROFILE% (Windows), $HOME, $XDG_* etc. in a path template
expand_path() {
    local s="$1"
    # Windows %VAR% env-var syntax (must run before the $HOME substitution,
    # and before ~ since %USERPROFILE% is a full path, not relative to HOME)
    s="${s//\%USERPROFILE\%/${USERPROFILE:-$HOME}}"
    s="${s/#\~/$HOME}"
    s="${s/\$HOME/$HOME}"
    # XDG fallbacks
    s="${s/\$XDG_CONFIG_HOME/${XDG_CONFIG_HOME:-$HOME/.config}}"
    s="${s/\$XDG_DATA_HOME/${XDG_DATA_HOME:-$HOME/.local/share}}"
    s="${s/\$XDG_STATE_HOME/${XDG_STATE_HOME:-$HOME/.local/state}}"
    s="${s/\$XDG_CACHE_HOME/${XDG_CACHE_HOME:-$HOME/.cache}}"
    echo "$s"
}

# glob-aware existence: prints matching paths (one per line), honors wildcards
find_paths() {
    local template="$1"
    local s
    s="$(expand_path "$template")"

    local parent leaf
    parent="$(dirname "$s")"
    leaf="$(basename "$s")"

    # wildcard in leaf?
    if [[ "$leaf" == *'*'* || "$leaf" == *'?'* || "$leaf" == *'['* ]]; then
        [[ -d "$parent" ]] || return 0
        local p
        for p in "$parent"/$leaf; do
            [[ -e "$p" ]] && echo "$p"
        done
    else
        [[ -e "$s" ]] && echo "$s"
    fi
}

# detect platform for path selection
platform_paths_field() {
    case "$(uname -s)" in
        Darwin) echo 'macos' ;;
        Linux) echo 'linux' ;;
        MINGW*|MSYS*|CYGWIN*) echo 'windows' ;;
        *) echo 'linux' ;;
    esac
}

# --- banner ---
if [[ $APPLY -eq 1 ]]; then
    MODE="APPLY (changes will be made)"
else
    MODE="DRY RUN (no changes)"
fi
plat="$(platform_paths_field)"

echo
echo '========================================='
echo " coding-agent-clean  ($MODE)"
echo " platform: $(uname -s) (bash)"
echo " agents.json: $JSON_PATH"
echo '========================================='
echo

if [[ $APPLY -eq 0 ]]; then
    echo 'Pass --apply to actually delete. Showing what would be removed.'
    echo
fi

# --- backup root ---
BACKUP_ROOT=""
if [[ $APPLY -eq 1 && $BACKUP -eq 1 ]]; then
    if [[ -z "$BACKUP_DIR" ]]; then
        BACKUP_DIR="$SCRIPT_DIR/backups/$(date +%Y%m%d_%H%M%S)"
    fi
    BACKUP_ROOT="$BACKUP_DIR"
    mkdir -p "$BACKUP_ROOT"
    echo "Backup root: $BACKUP_ROOT"
    echo
fi

remove_state() {
    local label="$1"; shift
    local paths=("$@")
    local p dest dest_parent
    for p in "${paths[@]}"; do
        [[ -e "$p" ]] || continue
        if [[ -n "$BACKUP_ROOT" ]]; then
            dest="$BACKUP_ROOT/$label/$(basename "$p")"
            dest_parent="$(dirname "$dest")"
            mkdir -p "$dest_parent"
            mv "$p" "$dest"
            echo "  [moved] $p"
        else
            rm -rf "$p"
            echo "  [removed] $p"
        fi
    done
}

# --- build agent list ---
agent_count() { jq '.agents | length' "$JSON_PATH"; }
agent_at()   { jq -r --argjson i "$1" '.agents[$i]' "$JSON_PATH"; }

N="$(agent_count)"
SUMMARY=()
GRAND_FOUND=0
GRAND_REMOVED=0

for (( i=0; i<N; i++ )); do
    row="$(agent_at "$i")"
    # one jq call instead of five
    IFS=$'\t' read -r id name is_cloud notes cats <<< "$(echo "$row" | jq -r '[.id, .name, .cloud_only, (.notes // ""), (if .categories then .categories | join(", ") else "(none)" end)] | @tsv')"

    # filter by --agents
    if [[ -n "$AGENTS" ]]; then
        found=0
        IFS=',' read -ra WANTED <<< "$AGENTS"
        for w in "${WANTED[@]}"; do
            w="$(echo "$w" | xargs)"
            [[ "$w" == "$id" ]] && found=1 && break
        done
        if [[ $found -eq 0 ]]; then continue; fi
    fi

    if [[ "$is_cloud" == "true" ]]; then
        if [[ $CLOUD_TOO -eq 1 ]]; then
            SUMMARY+=("$name|$id|cloud-only (no local state)")
        fi
        continue
    fi

    echo "[$name]"
    echo "  id: $id   categories: $cats"
    [[ -n "$notes" ]] && echo "  note: $notes"

    field="$(platform_paths_field)"
    found_paths=()

    # global paths
    while IFS= read -r tpl; do
        [[ -z "$tpl" ]] && continue
        while IFS= read -r resolved; do
            [[ -n "$resolved" ]] && found_paths+=("$resolved")
        done < <(find_paths "$tpl")
    done < <(echo "$row" | jq -r ".paths.$field[]?")

    # project-local paths
    if [[ $INCLUDE_PROJECT_LOCAL -eq 1 ]]; then
        while IFS= read -r ptpl; do
            [[ -z "$ptpl" ]] && continue
            for root in "${PROJECT_ROOTS[@]}"; do
                while IFS= read -r resolved; do
                    [[ -n "$resolved" ]] && found_paths+=("$resolved")
                done < <(find_paths "$root/$ptpl")
            done
        done < <(echo "$row" | jq -r '.project_local[]?.path?')
    fi

    # de-duplicate
    if [[ ${#found_paths[@]} -gt 0 ]]; then
        readarray -t found_paths < <(printf '%s\n' "${found_paths[@]}" | sort -u)
    fi

    if [[ ${#found_paths[@]} -eq 0 ]]; then
        echo "  -> not found on this machine"
        SUMMARY+=("$name|$id|not found")
        echo
        continue
    fi

    GRAND_FOUND=$((GRAND_FOUND + ${#found_paths[@]}))
    echo "  found ${#found_paths[@]} path(s):"
    for fp in "${found_paths[@]}"; do echo "    - $fp"; done

    if [[ $APPLY -eq 1 ]]; then
        remove_state "$id" "${found_paths[@]}"
        GRAND_REMOVED=$((GRAND_REMOVED + ${#found_paths[@]}))
    fi
    SUMMARY+=("$name|$id|found ${#found_paths[@]}")
    echo
done

# --- summary ---
echo '========================================='
echo ' summary'
echo '========================================='
printf '%-22s %-16s %s\n' AGENT ID STATUS
printf '%-22s %-16s %s\n' '----' '--' '------'
for s in "${SUMMARY[@]}"; do
    IFS='|' read -r nm st <<< "$s"
    printf '%-22s %-16s %s\n' "$nm" "$st"
done
echo
if [[ $APPLY -eq 0 ]]; then
    echo "Dry run complete. $GRAND_FOUND path(s) would be removed. Pass --apply to execute."
else
    echo "Done. $GRAND_REMOVED path(s) removed."
    [[ -n "$BACKUP_ROOT" ]] && echo "Backed up to: $BACKUP_ROOT"
fi
