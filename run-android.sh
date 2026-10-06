#!/system/bin/sh
set -u
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" 2>/dev/null && pwd)
exec sh "$SCRIPT_DIR/android/run-on-device.sh" "$@"
