#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT_DIR"

bash -n scripts/build-agent.sh
sh -n run-android.sh
sh -n android/run-on-device.sh
node --check android/agent.js

test -s android/agent.js
test -x android/vendor/frida-inject
file android/vendor/frida-inject | grep -q 'ARM aarch64'

EXPECTED_HASH=$(cut -d' ' -f1 android/vendor/frida-inject.sha256)
ACTUAL_HASH=$(sha256sum android/vendor/frida-inject | cut -d' ' -f1)
test "$EXPECTED_HASH" = "$ACTUAL_HASH"

grep -q 'globalThis.Il2Cpp = Il2Cpp' android/agent.js
grep -q "ii's Stupid Menu Quest" android/agent.js

printf '%s\n' 'All static checks passed.'
