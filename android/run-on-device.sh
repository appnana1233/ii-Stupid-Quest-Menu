#!/system/bin/sh
# Run ii's Quest Menu directly on a rooted ARM64 Android/Quest device.
# This launcher intentionally uses local frida-inject, not frida-server.

set -u

TARGET="com.AnotherAxiom.GorillaTag"
RUNTIME="qjs"
FOREGROUND=0
FORCE=0

usage() {
    cat <<'EOF'
Usage: sh android/run-on-device.sh [options]

Options:
  --target PACKAGE   Android process/package name (default: com.AnotherAxiom.GorillaTag)
  --runtime NAME     Frida JavaScript runtime: qjs or v8 (default: qjs)
  --foreground       Keep the injector attached and show logs; Ctrl-C unloads the menu
  --force            Inject even if this launcher already recorded the current process
  -h, --help         Show this help

Normal launch from Termux:
  su -c "sh '$PWD/android/run-on-device.sh'"
EOF
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --target)
            shift
            [ "$#" -gt 0 ] || { echo "[!] --target needs a value" >&2; exit 2; }
            TARGET="$1"
            ;;
        --runtime)
            shift
            [ "$#" -gt 0 ] || { echo "[!] --runtime needs qjs or v8" >&2; exit 2; }
            RUNTIME="$1"
            ;;
        --foreground)
            FOREGROUND=1
            ;;
        --force)
            FORCE=1
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "[!] Unknown option: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
    shift
done

case "$RUNTIME" in
    qjs|v8) ;;
    *) echo "[!] Unsupported runtime '$RUNTIME'; use qjs or v8." >&2; exit 2 ;;
esac

if [ "$(id -u 2>/dev/null || echo unknown)" != "0" ]; then
    echo "[!] Root is required for local process injection." >&2
    echo "    From Termux, run:" >&2
    echo "    su -c \"sh '$0'\"" >&2
    exit 1
fi

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" 2>/dev/null && pwd)
PROJECT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." 2>/dev/null && pwd)
SOURCE_INJECTOR="$SCRIPT_DIR/vendor/frida-inject"
SOURCE_AGENT="$SCRIPT_DIR/agent.js"
SOURCE_HASH="$SCRIPT_DIR/vendor/frida-inject.sha256"
RUNTIME_DIR="/data/local/tmp/ii-menu-quest-tag"
INJECTOR="$RUNTIME_DIR/frida-inject"
AGENT="$RUNTIME_DIR/agent.js"
STATE_FILE="$RUNTIME_DIR/attached.pid"

if [ -z "$SCRIPT_DIR" ] || [ -z "$PROJECT_DIR" ]; then
    echo "[!] Could not resolve the project path." >&2
    exit 1
fi

ABI=$(getprop ro.product.cpu.abi 2>/dev/null || true)
case "$ABI" in
    arm64-v8a|aarch64|"") ;;
    *)
        echo "[!] This package contains an ARM64 injector, but the device reports '$ABI'." >&2
        exit 1
        ;;
esac

if [ ! -f "$SOURCE_INJECTOR" ] || [ ! -f "$SOURCE_AGENT" ]; then
    echo "[!] Package is incomplete. Missing android/vendor/frida-inject or android/agent.js." >&2
    exit 1
fi

if command -v sha256sum >/dev/null 2>&1 && [ -f "$SOURCE_HASH" ]; then
    EXPECTED_HASH=$(sed -n '1{s/[[:space:]].*$//;p;}' "$SOURCE_HASH")
    ACTUAL_HASH=$(sha256sum "$SOURCE_INJECTOR" | sed 's/[[:space:]].*$//')
    if [ "$EXPECTED_HASH" != "$ACTUAL_HASH" ]; then
        echo "[!] Bundled frida-inject failed its SHA-256 integrity check." >&2
        exit 1
    fi
fi

PIDS=$(pidof "$TARGET" 2>/dev/null || true)
PID=""
for candidate in $PIDS; do
    PID="$candidate"
    break
done

if [ -z "$PID" ]; then
    echo "[!] '$TARGET' is not running." >&2
    echo "    Start Gorilla Tag, wait until it finishes loading, then rerun this command." >&2
    exit 1
fi

if [ "$FORCE" -eq 0 ] && [ -f "$STATE_FILE" ]; then
    PREVIOUS_PID=$(cat "$STATE_FILE" 2>/dev/null || true)
    if [ "$PREVIOUS_PID" = "$PID" ]; then
        echo "[!] This launcher already injected process $PID." >&2
        echo "    Restart Gorilla Tag before reinjecting, or use --force at your own risk." >&2
        exit 1
    fi
fi

mkdir -p "$RUNTIME_DIR" || {
    echo "[!] Could not create $RUNTIME_DIR" >&2
    exit 1
}

cp "$SOURCE_INJECTOR" "$INJECTOR.tmp" && mv "$INJECTOR.tmp" "$INJECTOR"
cp "$SOURCE_AGENT" "$AGENT.tmp" && mv "$AGENT.tmp" "$AGENT"
chmod 700 "$INJECTOR"
chmod 600 "$AGENT"

# Best-effort SELinux relabeling on Android builds that provide restorecon.
if command -v restorecon >/dev/null 2>&1; then
    restorecon "$INJECTOR" "$AGENT" >/dev/null 2>&1 || true
fi

echo "[*] Target: $TARGET (PID $PID)"
echo "[*] Injector: Frida 17.18.0, Android ARM64"
echo "[*] Runtime: $RUNTIME"

if [ "$FOREGROUND" -eq 1 ]; then
    echo "[*] Foreground mode: press Ctrl-C to detach and unload the menu."
    exec "$INJECTOR" -p "$PID" -s "$AGENT" -R "$RUNTIME"
fi

if "$INJECTOR" -p "$PID" -s "$AGENT" -R "$RUNTIME" -e; then
    printf '%s\n' "$PID" > "$STATE_FILE"
    echo "[+] Injection complete. The menu remains loaded until Gorilla Tag exits."
else
    status=$?
    echo "[!] Injection failed with exit code $status." >&2
    echo "    Retry with --foreground to keep logs visible." >&2
    exit "$status"
fi
