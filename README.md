# ii's Quest Menu — Rooted Android On-Device Edition plus the worst menu ever lol

This package adapts the archived **ii's Quest Menu** Frida project so it can be launched **directly from a rooted ARM64 Android/Meta Quest device**. After copying the package to the device, you do not need a PC, an ADB-over-Wi-Fi connection, a Python Frida client, or a running `frida-server`.

The original menu is a Frida port of [ii's Stupid Menu](https://github.com/protogenreal/ii-menu-quest) and uses a modified build of [frida-il2cpp-bridge](https://github.com/vfsfitvnm/frida-il2cpp-bridge).

> **Important:** This package does not root a device or bypass firmware restrictions. It assumes the device is already rooted and that `su` works in Termux. Use it only on hardware and software you are authorized to modify. Game modifications can cause crashes, data loss, or account sanctions. The included menu is old and may not match the latest Gorilla Tag classes or methods.

## What changed

The original `run.bat` launches a Frida client on a Windows computer and connects to the headset. This edition adds:

- `run-android.sh`, an on-device launcher for Termux or another Android shell;
- an official **Frida 17.18.0 Android ARM64 `frida-inject`** binary;
- `android/agent.js`, which combines the IL2CPP bridge and transpiled TypeScript menu in the required load order;
- process, root, architecture, integrity, and duplicate-injection checks;
- an optional foreground diagnostics mode;
- reproducible build and static-check scripts.

## Requirements

| Requirement | Details |
|---|---|
| Device | ARM64 Android device or Meta Quest headset |
| Root | A working `su` command available to the shell |
| Terminal | Termux is recommended; use a current F-Droid or GitHub build rather than the obsolete Play Store build |
| Game | Gorilla Tag installed as `com.AnotherAxiom.GorillaTag` |
| External computer | Needed only to transfer the ZIP if you cannot download it directly on the device |

## Install on the device

1. Put `ii-menu-quest-tag-android.zip` in the device's **Downloads** folder.
2. Open Termux and grant shared-storage access if you have not done so:

   ```sh
   termux-setup-storage
   ```

3. Install `unzip`, extract the package into the Termux home directory, and enter it:

   ```sh
   pkg update
   pkg install unzip
   cd ~
   unzip ~/storage/downloads/ii-menu-quest-tag-android.zip
   cd ii-menu-quest-tag-android
   ```

4. Verify that Termux can obtain root:

   ```sh
   su -c id
   ```

   The output must contain `uid=0`. If it does not, fix root access before continuing.

## Run completely on-device

1. Start Gorilla Tag and wait until the game has finished loading.
2. Return to Termux without closing the game.
3. From the extracted project directory, run:

   ```sh
   su -c "sh '$PWD/run-android.sh'"
   ```

A successful launch ends with:

```text
[+] Injection complete. The menu remains loaded until Gorilla Tag exits.
```

The launcher copies the executable and combined agent to `/data/local/tmp/ii-menu-quest-tag`, attaches to the running Gorilla Tag process, eternalizes the agent, and exits. **Do not start `frida-server` for this launch method.**

You must run the launcher again each time Gorilla Tag starts a new process.

## Diagnostics and options

Keep the injector attached so logs stay visible:

```sh
su -c "sh '$PWD/run-android.sh' --foreground"
```

In foreground mode, pressing **Ctrl+C** detaches and unloads the injected script. Closing or restarting Gorilla Tag also unloads it.

If QuickJS reports a script-runtime issue, retry after restarting the game with V8:

```sh
su -c "sh '$PWD/run-android.sh' --runtime v8"
```

Other options:

```text
--target PACKAGE   Override the target package/process name
--force            Bypass this launcher's duplicate-process guard
-h, --help         Show command help
```

Avoid `--force` unless the previous attempt failed before loading the agent. Hooking the same game methods twice may crash the process.

## Troubleshooting

| Symptom | Action |
|---|---|
| `Root is required` | Run `su -c id`. The result must show `uid=0`; grant Termux root permission in the device's root manager if applicable. |
| `Gorilla Tag is not running` | Launch the game, wait for it to finish loading, and retry. Confirm the process with `su -c 'pidof com.AnotherAxiom.GorillaTag'`. |
| `Permission denied` when starting the shell script | Invoke it with `sh` exactly as shown. Android shared storage is commonly mounted `noexec`. |
| `Unable to load SELinux policy` or an attach denial | The active root solution or firmware is blocking `ptrace`. This package cannot repair the root method or device policy. |
| JavaScript/IL2CPP class or method error | The archived menu no longer matches the installed game version. The on-device launcher is working, but `gtag.ts` needs to be updated for that game build. |
| Game closes during injection | Restart the game and try `--foreground` to capture the first error. Do not use `--force` on an already-hooked process. |
| Wrong CPU architecture | This package contains only the ARM64 Android injector used by Quest 3/3S-class devices. |

## Rebuild the combined agent on a computer

Rebuilding is only necessary after editing `gtag.ts` or `frida-il2cpp-bridge.js`. It is not required on the Android device.

```sh
npm install
npm run check
```

`npm run check` rebuilds `android/agent.js`, checks its JavaScript syntax, validates the Android shell scripts, confirms that the bundled injector is ARM64, and verifies its SHA-256 digest.

## Files

| Path | Purpose |
|---|---|
| `run-android.sh` | Convenient on-device entry point |
| `android/run-on-device.sh` | Rooted Android launcher and checks |
| `android/agent.js` | Generated single-file Frida agent |
| `android/vendor/frida-inject` | Official Frida 17.18.0 Android ARM64 injector |
| `gtag.ts` | Original editable menu source |
| `frida-il2cpp-bridge.js` | Existing bundled IL2CPP bridge |
| `scripts/build-agent.sh` | Rebuilds the generated agent |
| `scripts/check.sh` | Runs static validation |
| `run.bat` | Preserved original Windows/host launch method |

Frida binary provenance, hashes, and licensing are recorded in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
