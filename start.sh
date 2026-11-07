#!/usr/bin/env bash
# ==============================================================================
#  ⚡ yt (macOS Edition) — скрипт быстрого запуска
# ==============================================================================
SOURCE="${BASH_SOURCE[0]:-$0}"
while [ -L "$SOURCE" ]; do
    DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
    SOURCE="$(readlink "$SOURCE")"
    [[ "$SOURCE" != /* ]] && SOURCE="$DIR/$SOURCE"
done
SCRIPT_DIR="$(cd -P "$(dirname "$SOURCE")" 2>/dev/null && pwd)"
cd "$SCRIPT_DIR" || exit 1
exec bash "$SCRIPT_DIR/yt.sh" "$@"
