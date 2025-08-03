#!/bin/bash
set -euo pipefail

CONFIG_DIR="/etc/transmission-cleanup.d"
CONFIG_EXT="conf"
TRANSMISSION_BIN="/usr/bin/transmission-remote"
DRY_RUN=false

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

cleanup_torrents() {
    local user="$1"
    local pass="$2"
    local port="$3"
    local cutoff="$4"
    local target_dir="$5"

    local remote="localhost:$port"
    log "Connecting to Transmission at $remote"

    log "Fetching completed torrents..."
    mapfile -t torrents < <("$TRANSMISSION_BIN" "$remote" -n "$user:$pass" -l | grep "100%.*Done" || true)
    log "Found ${#torrents[@]} completed torrents."

    for entry in "${torrents[@]}"; do
        local id name target fullpath last_modified abs_fullpath abs_target_dir

        id=$(echo "$entry" | sed -E 's/^ *([0-9]+).*/\1/')
        log "Processing torrent ID: $id"

        target=$("$TRANSMISSION_BIN" "$remote" -n "$user:$pass" -t "$id" -i | awk '/Location:/ {print $2}')
        name=$("$TRANSMISSION_BIN" "$remote" -n "$user:$pass" -t "$id" -f | head -1 | sed "s/ ([0-9]\+ files)://g")

        if [ -z "$name" ]; then
            log "  [SKIP] Torrent name is empty for ID $id"
            continue
        fi

        fullpath="$target/$name"
        log "  Torrent name: $name"
        log "  Full path: $fullpath"

        # Resolve absolute paths
        abs_fullpath=$(readlink -f "$fullpath" 2>/dev/null || echo "")
        abs_target_dir=$(readlink -f "$target_dir" 2>/dev/null || echo "")

        # Check if fullpath is inside target_dir
        if [[ -z "$abs_fullpath" || -z "$abs_target_dir" || "$abs_fullpath" != "$abs_target_dir"* ]]; then
            log "  [SKIP] \"$name\" (ID: $id) is outside target directory \"$target_dir\""
            continue
        fi

        last_modified=0

        if [ -d "$fullpath" ]; then
            log "  Target is a directory. Scanning files for last modified timestamp..."
            while IFS= read -r -d '' file; do
                local mtime
                mtime=$(stat -c %Y "$file" 2>/dev/null || echo 0)
                (( mtime > last_modified )) && last_modified=$mtime
            done < <(find "$fullpath" -type f -print0)
        elif [ -f "$fullpath" ]; then
            last_modified=$(stat -c %Y "$fullpath" 2>/dev/null || echo 0)
        else
            log "  [WARN] File or folder not found: $fullpath — skipping"
            continue
        fi

        local now
        now=$(date +%s)
        local age=$(( now - last_modified ))

        local age_days=$(( age / 86400 ))
        local cutoff_days=$(( cutoff / 86400 ))

        log "  Last modified: $(date -d @$last_modified)"
        log "  Age: $age_days days"
        log "  Cutoff: $cutoff_days days"

        if (( age > cutoff )); then
            if [ "$DRY_RUN" = true ]; then
                log "  [DRY-RUN] Would remove \"$name\" (ID: $id) - completed $age_days days ago"
            else
                log "  Removing \"$name\" (ID: $id) - completed $age_days days ago"
                "$TRANSMISSION_BIN" "$remote" -n "$user:$pass" -t "$id" --remove-and-delete
                log "  Deleted."
            fi
        else
            log "  [KEEP] \"$name\" is not old enough for deletion (age: $age_days days)"
        fi
    done
}

main() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run)
                DRY_RUN=true
                ;;
            *)
                log "Unknown argument: $1"
                exit 1
                ;;
        esac
        shift
    done

    for config in "$CONFIG_DIR"/*."$CONFIG_EXT"; do
        [ -e "$config" ] || continue
        log "Loading config: $config"

        # shellcheck source=/dev/null
        source "$config"

        : "${USER:?USER not set in config}"
        : "${PASS:?PASS not set in config}"
        : "${PORT:?PORT not set in config}"
        : "${TARGET_DIR:?TARGET_DIR not set in config}"

        # Convert cutoff from days (config) to seconds for script use
        local cutoff_days="${CUTOFF:-16}"
        local cutoff=$(( cutoff_days * 86400 ))

        cleanup_torrents "$USER" "$PASS" "$PORT" "$cutoff" "$TARGET_DIR"
    done
}

main "$@"
