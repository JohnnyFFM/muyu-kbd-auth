# muyu-kbd-auth

Complete the Xiaomi keyboard authentication handshake on a **Xiaomi Pad 7 Pro
(codename `muyu`) running crDroid**, so the magnetic pogo keyboard authenticates
the same way it does on stock HyperOS — using the device's own TrustZone key.

## Why

On crDroid the keyboard periodically asks the tablet to re-authenticate
(MiAuth). Stock HyperOS answers using `MiDevAuthService` + the `midevauthd` HAL,
which talk to a signed **TrustZone trustlet** (`/vendor/firmware_mnt/image/devauth.*`)
that holds the per-device key. crDroid ships neither the daemon nor the Xiaomi
framework, so the handshake never completes.

Key finding: on this device the **TrustZone path is fully intact** under crDroid
(`/dev/smcinvoke`, `qseecom_proxy`, `libQSEEComAPI.so`, and the `devauth`
trustlet are all present). Only the thin Xiaomi daemon is missing — and it runs
fine when copied over. So we don't need any key or server; we reuse the device's
own trustlet.

## Architecture

```
[keyboard] ── /dev/nanodev0 ── device/kbd_auth.sh ── tokenhelper ──(binder)──
                                                  midevauthd ──(smcinvoke)── devauth trustlet (key)
```

* **`midevauthd`** — Xiaomi's HAL daemon (NOT in this repo; copied from the stock
  ROM at runtime). Loads the trustlet and serves `IMidevauthService`.
* **`tokenhelper`** (this repo, built in CI) — a tiny binder client that calls
  `IMidevauthService.devauth_token_get(type, uid, keyMeta, challenge)` and prints
  the resulting token. That's the one piece a shell script can't do itself.
* **`device/kbd_auth.sh`** (this repo) — drives the nanodev handshake
  (`AUTH_START → STEP3 → STEP5`) and calls `tokenhelper` to produce the STEP5
  token for the keyboard's challenge.

No Xiaomi proprietary binaries are committed here. `aidl/…/IMidevauthService.aidl`
is an interface description reconstructed (for interoperability) from the
device's own decompiled HAL; the transaction-code order is chosen so
`devauth_token_get` lands on code **17** and `devauth_token_verify` on **16**,
matching the on-device service.

## Build

GitHub Actions (`.github/workflows/build-tokenhelper.yml`) cross-compiles
`tokenhelper` for `arm64-v8a` with the Android NDK and uploads it as an artifact
(`tokenhelper-arm64`). No local toolchain needed. Trigger it by pushing, or via
"Run workflow".

## Install / run (device, rooted — Magisk)

```sh
# 1) copy Xiaomi's HAL daemon + libs from the stock ROM (one time)
#    /odm/bin/midevauthd, /odm/lib64/libmidevauth.so,
#    /odm/lib64/vendor.xiaomi.hardware.aidl.midevauth-V1-ndk_platform.so
adb push <stock>/midevauthd                 /data/local/tmp/mda/
adb push <stock>/libmidevauth.so            /data/local/tmp/mda/
adb push <stock>/vendor.xiaomi.hardware.aidl.midevauth-V1-ndk_platform.so /data/local/tmp/mda/
adb push tokenhelper                         /data/local/tmp/mda/
adb push device/kbd_auth.sh                  /data/local/tmp/mda/

# 2) start the HAL daemon
su -c 'cd /data/local/tmp/mda; chmod 755 midevauthd tokenhelper kbd_auth.sh; \
       LD_LIBRARY_PATH=/data/local/tmp/mda:/vendor/lib64:/system/lib64 ./midevauthd & '

# 3) start the handshake bridge
su -c 'setsid /data/local/tmp/mda/kbd_auth.sh >/dev/null 2>&1 < /dev/null &'

# logs: /data/adb/kbd/auth.log
```

Once validated, both can be moved to `/data/adb/service.d/` to run at boot.

## Status

Validated so far: `midevauthd` loads the `devauth` trustlet on crDroid and reads
the key (key version 2); the handshake framing and the `token_get` call shape are
confirmed against the decompiled stock service. End-to-end "keyboard enables" is
the final on-device test.

## Runtime notes (validated 2026-10-08)

End-to-end verified on crDroid under **Enforcing SELinux**: `midevauthd` loads the
`devauth` trustlet (key version 2), and `tokenhelper token …` returns a genuine
16-byte token that the handshake sends as STEP5 — with no keyboard stall.

Two gotchas that matter:

1. **Vendor servicemanager.** `midevauthd` registers the HAL with the *vendor*
   servicemanager (`vndservice list` shows it; `service list` does not). A client
   must therefore use the vendor `libbinder`, or `AServiceManager_waitForService`
   blocks forever. Run `tokenhelper` with
   `LD_LIBRARY_PATH=/vendor/lib64:/system/lib64` so it binds `/dev/vndbinder`.
   `device/kbd_auth.sh` already does this for its `tokenhelper` call.
2. **Cold kick.** Unlike stock, nothing proactively starts auth, so `kbd_auth.sh`
   sends one AUTH_START at startup and then answers every keyboard re-auth.

`device/start.sh` launches both detached with the right environment.

## Install at boot (Magisk)

Put the five runtime files in `/data/adb/kbdauth/` and the launcher in
`/data/adb/service.d/`:

```sh
su -c 'mkdir -p /data/adb/kbdauth'
adb push midevauthd libmidevauth.so vendor.xiaomi.hardware.aidl.midevauth-V1-ndk_platform.so tokenhelper device/kbd_auth.sh /data/adb/kbdauth/   # midevauthd/libs from the stock ROM
adb push device/service.d-kbdauth.sh /data/adb/service.d/kbdauth.sh
su -c 'chmod 755 /data/adb/kbdauth/midevauthd /data/adb/kbdauth/tokenhelper /data/adb/kbdauth/kbd_auth.sh /data/adb/service.d/kbdauth.sh'
```

On boot the launcher waits for `sys.boot_completed` + `/dev/nanodev0`, starts
`midevauthd`, waits for it to register with the vendor servicemanager, then
starts `kbd_auth.sh`. Verified to survive a reboot and re-authenticate with no
manual steps. Remove with `rm /data/adb/service.d/kbdauth.sh` + kill the two
processes. Logs: `/data/adb/kbd/svc.log`, `/data/adb/kbd/auth.log`.
