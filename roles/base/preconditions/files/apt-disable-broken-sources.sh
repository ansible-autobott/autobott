#!/bin/bash
# ============================================================================================================
# Disable the APT sources that make `apt-get update` fail
# ============================================================================================================
# One outdated repository (rotated signing key, dropped suite, dead host) makes every
# `apt update` fail, and with it the first apt task of the run. This script finds such
# sources and disables them, so the run can go on:
#
#   - a healthy host costs a single `apt-get update`; the per-file checks only run when
#     that update fails.
#   - each file in sources.list.d is then updated on its own, into a scratch lists dir
#     (the host's lists and cache stay untouched); a failing file is retried once.
#   - .sources files get `Enabled: no` in every stanza, .list files get their entries
#     commented out; both with a comment saying why. The role that manages a source
#     rewrites its file, which enables it again.
#   - nothing is disabled when the distro's own sources fail as well (no network, broken
#     mirror): that is not a third-party problem, so the run fails as it would anyway.
#
# Usage: apt-disable-broken-sources.sh [protected ...]
#   protected: basenames in sources.list.d that are never disabled (the distro's own
#              sources); /etc/apt/sources.list is always protected.
# Prints one line per disabled file (nothing when all sources are healthy); notes on
# why nothing was disabled go to stderr.
set -euo pipefail

SOURCES_LIST=/etc/apt/sources.list
SOURCES_D=/etc/apt/sources.list.d
MARK="# Disabled by autobott (preconditions) on $(date -u +%F): apt-get update failed for this source.
# The role that manages it re-enables it by rewriting this file; remove the file if it is not needed."

if apt-get update -qq --error-on=any >/dev/null 2>&1; then
  exit 0
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
# apt downloads as the unprivileged _apt user, which must reach the scratch lists dir.
chmod 0755 "$tmp"
mkdir -p "$tmp/empty"

# Update from <file> alone. Succeeds when every source in it could be fetched; sets
# fetched=1 when at least one Release file came in (proof that the network works).
fetched=0
source_ok() {
  rm -rf "$tmp/lists" "$tmp/cache"
  mkdir -p "$tmp/lists/partial" "$tmp/cache"
  apt-get update -qq --error-on=any \
    -o Dir::Etc::SourceList="$1" \
    -o Dir::Etc::SourceParts="$tmp/empty" \
    -o Dir::State::Lists="$tmp/lists" \
    -o Dir::Cache="$tmp/cache" >/dev/null 2>&1 || return 1
  if compgen -G "$tmp/lists/*Release" >/dev/null; then fetched=1; fi
}

source_ok_retry() {
  source_ok "$1" || { sleep 5; source_ok "$1"; }
}

is_protected() {
  local name p
  name="$(basename "$1")"
  for p in "${protected[@]}"; do
    [ "$name" = "$p" ] && return 0
  done
  return 1
}

protected=("$@")
broken=()
shopt -s nullglob
for f in "$SOURCES_LIST" "$SOURCES_D"/*.list "$SOURCES_D"/*.sources; do
  [ -f "$f" ] || continue
  source_ok_retry "$f" && continue
  if [ "$f" = "$SOURCES_LIST" ] || is_protected "$f"; then
    echo "the distro source $f fails too; not disabling anything" >&2
    exit 0
  fi
  broken+=("$f")
done

if [ "${#broken[@]}" -eq 0 ]; then
  echo "apt-get update fails, but no single source file does; not disabling anything" >&2
  exit 0
fi
if [ "$fetched" -eq 0 ]; then
  echo "no source could be fetched (network down?); not disabling anything" >&2
  exit 0
fi

for f in "${broken[@]}"; do
  case "$f" in
    *.sources)
      # Drop any Enabled field and open every stanza with `Enabled: no`.
      awk -v mark="$MARK" '
        BEGIN { print mark; new = 1 }
        /^[[:space:]]*$/ { print; new = 1; next }
        /^[Ee]nabled:/ { next }
        new && !/^#/ { print "Enabled: no"; new = 0 }
        { print }
      ' "$f" > "$tmp/disabled"
      ;;
    *.list)
      { printf '%s\n' "$MARK"; sed -E 's/^([[:space:]]*deb(-src)?[[:space:]])/# \1/' "$f"; } > "$tmp/disabled"
      ;;
  esac
  cat "$tmp/disabled" > "$f"
  echo "$f"
done
