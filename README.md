# abxylute-one-root

Root, debloat and decoder-unlock toolkit for the **abxylute One** cloud handheld
(MediaTek **MT8168**, 4GB RAM, Android 12, A/B (a/b) slots, 64GB eMMC, vendor
build `yoyo20230104`).

Everything in here was verified working on a real device (2026-11-23). The
device bootloader is **completely unprotected** — SBC, SLA, DAA, root-cert all
disabled — which makes the whole process unusually safe: every step is
readable/writable and reversible, no exploits needed beyond standard MTK
BootROM automation.

> ⚠️ You do this at your own risk. `flash` steps write to eMMC. Read steps
> never modify anything. Make your own dumps before flashing anything.

---

## TL;DR

1. `mtkclient` gets full flash access (unprotected BootROM).
2. Dump `boot_a`, `boot_b`, `vbmeta_a`, `vbmeta_b` + any other partitions you care about.
3. Patch the **active slot's** boot with **Magisk** (in-app "Select and Patch a File").
4. Flash **only** the Magisk-patched boot back. **Do NOT flash a modified vbmeta** (see gotchas).
5. Install the `magisk-module/` in this repo through the Magisk app — it raises the
   MTK h264/hevc decoder 1080p performance point from 30fps → 60fps, systemless.
6. Debloat (see list below) — most of it works **without root** via `adb shell pm disable-user`.

---

## What you need

- USB-C **data** cable from the handheld to a Linux host
- [mtkclient](https://github.com/bkerler/mtkclient) (tested with commit at v2.1.4, Python venv)
- [Magisk](https://github.com/topjohnwu/Magisk/releases) (tested v31.1) APK + its "Select and Patch a File" flow
- adb (`platform-tools`) for the wireless/USB debug side

### Host USB permissions

The handheld re-enumerates with a fresh **root-owned** USB node on every replug.
Install a udev rule once (as root):

```
SUBSYSTEM=="usb", ATTRS{idVendor}=="0e8d", MODE="0666"
ATTR{idVendor}=="18d1", MODE="0666"
```

in `/etc/udev/rules.d/99-mtk.rules`, then `udevadm control --reload-rules`.
If adb still says `no permissions` after a chmod, restart the adb daemon
(`adb kill-server`) — it caches the denial.

### Entering BROM / preloader

Power the handheld **fully off**, then either:
- plug in the cable with **no buttons** (preloader mode), or
- hold nothing and just replug — the BROM window shows at every cold plug-in
  (`lsusb` shows `0e8d:20ff MediaTek Inc.` for a few seconds, then `0e8d:2000 MT65xx Preloader`).

mtkclient catches either. On this device **volume-down at power-on boots recovery**,
not BROM. `adb reboot bootloader` → fastboot is *not* needed for any of this.

---

## Step 1: Dump everything (read-only)

```bash
for p in boot_a boot_b vbmeta_a vbmeta_b; do
  mtk r "$p" "dumps/$p.img"
done
```

Keep these — they are your instant restore for every later step. Other useful
partitions on this device: `lk_a/b`, `vendor_boot_a/b`, `dtbo_a/b`, `super`,
`seccfg`, `proinfo`. (`misc` does not exist on this device.)

Find the active slot from a booted device: `adb shell getprop ro.boot.slot_suffix`
(here: `_b`).

## Step 2: Magisk patch (boot only!)

1. `adb install Magisk-v31.1.apk` (or newer)
2. `adb push dumps/boot_b.img /sdcard/Download/boot_b.img` (active slot's boot)
3. On the handheld: Magisk → **Install** → **Select and Patch a File** → pick `boot_b.img`
4. `adb pull /sdcard/Download/magisk_patched-XXXX.img`

## Step 3: Flash the patched boot

```bash
mtk w boot_b magisk_patched_boot_b.img
```

**That's it.** Boot up. Magisk app shows "Installed: 31.1".

### ⚠️ vbmeta gotcha (bootloop!)

We also patched `vbmeta_b` — AVB flags set to "verification disabled"
(flags field at byte offset 120 of an `AVB0` header) — *before* flashing the
Magisk boot, the classic recipe for locked devices. On this handheld that
**bootloops**: the MTK LK rejects a flag-modified vbmeta, while happily booting
an *unsigned, unverified* boot (because SBC is disabled and nothing is checked
at all).

Symptom: logo → dark → logo → dark forever.

Fix: flash boot_b + vbmeta_b *originals* back:

```bash
mtk w boot_b,vbmeta_b dumps/boot_b.img,dumps/vbmeta_b.img
```

Then re-flash *only* the Magisk boot. Stock vbmeta stays.

## Step 4: the decoder module (`magisk-module/`)

The vendor declares both `c2.mtk.avc.decoder` and `c2.mtk.hevc.decoder` with
`performance-point-1920x1088 = 30` (fps) in `/vendor/etc/media_codecs_c2.xml`
(plus the `OMX.MTK` alias file), while the *same* file measures those decoders
at 50–100fps @ 1080p. Conservative declarations.

This module (systemless `system/vendor/etc` overlay) raises the avc + hevc
decoder performance point to 60:

```
magisk-module/
├── module.prop
└── system/vendor/etc/
    ├── media_codecs_c2.xml
    └── media_codecs_mediatek_video.xml
```

Install: Magisk → Modules → Install from storage → zip → reboot. Uninstalling
the module reverts the files; original `/vendor` is never touched.

Whether the 60fps raise is *required* we could not prove — it may be the case
that the framework accepts 1080p60 regardless (measured rates support it,
and frame-rate is largely advisory in configure paths). A/B-test if you care.
It costs nothing.

## Step 5: Debloat (no root needed for any of this)

This vendor ships a lot of junk. Freeze list (all reversible with `pm enable <pkg>`):

```bash
# Tencent gamepad UI stack (keeps: keyguard = lockscreen!)
pm disable-user -k com.levelinfinite.southpole.gamepad.launcher.mtk       # replace with Lawnchair/Nova
pm disable-user -k com.levelinfinite.southpole.gamepad.recommend.mtk
pm disable-user -k com.levelinfinite.southpole.gamepad.quicksetting.mtk
# Optional: keep gamepad.settings enabled if you want the vendor controller settings
# (key mapping, deadzones, OTA) via the shortcut app below.
# pm disable-user -k com.levelinfinite.southpole.gamepad.settings.mtk

# MTK junk
for p in com.mediatek.omacp com.mediatek.simprocessor com.mediatek.duraspeed \
         com.mediatek.gnssdebugreport com.mediatek.lbs.em2.ui \
         com.mediatek.gnss.nonframeworklbs com.mediatek.location.lppe.main \
         com.mediatek.batterywarning com.debug.loggerui \
         com.yuntian.gmssetupwizardcustom; do
  pm disable-user -k "$p"
done

# Android cruft
for p in com.android.agingtest com.android.traceur com.android.dynsystem \
         com.android.quicksearchbox com.android.printspooler com.android.bips \
         com.google.android.printservice.recommendation \
         com.android.managedprovisioning com.android.providers.calendar \
         com.android.egg com.google.android.apps.restore \
         com.google.android.apps.wellbeing com.google.android.factorytest \
         com.android.settings.intelligence com.google.android.syncadapters.calendar \
         com.google.android.onetimeinitializer com.google.android.feedback \
         com.google.mainline.telemetry; do
  pm disable-user -k "$p"
done

# Fully remove user-space copies of system apps you never want back
cmd package uninstall -k --user 0 com.amazon.venezia
cmd package uninstall -k --user 0 com.microsoft.xboxone.smartglass
```

Notes:
- `com.mediatek.duraspeed` is MTK's background-app *killer* — freezing it protects
  streaming sessions.
- **Do not** freeze `com.levelinfinite.southpole.gamepad.keyguard.mtk` (the lockscreen)
  — replacing it strands certain hardware-button flows.
- Leave alone: `configupdater`, `keychain`, `com.android.se`, GMS/Play/webview/networkstack.
- This toybox `pm` does not accept `--user`; use `cmd package uninstall -k --user 0`.
- Set a new default home (e.g. Lawnchair) *before* freezing the vendor launcher:
  `cmd role add-role-holder android.app.role.HOME app.lawnchair 0`

- **Heads-up: out of the box this firmware has no status bar / notification shade.**
  SystemUI runs its *TV* component list, and the vendor UI (now frozen) was the only
  brightness/notifications panel. Step 7 brings back the real Android phone UI.

Result on ours: MemAvailable went ~1.2GB → 1.8-2.1GB, swap from ~700MB → ~80MB,
and the "sluggish device" problem was mostly **memory pressure + kswapd churn**,
not CPU or Wi-Fi.

---

## Step 6 (optional): GamePad Settings shortcut (`gamepad-settings-shortcut/`)

The vendor controller settings (button mapping, stick/trigger deadzones, wallpaper,
OTA) live in `com.levelinfinite.southpole.gamepad.settings.mtk`, which has **no
launcher icon**: the vendor home screen was the only way in. Lawnchair can't open
hidden activities, so this repo has a ~3KB app that adds a **GamePad Settings** icon
to the app drawer and just opens `…settings.SettingsActivity`. No root needed.

```bash
adb shell pm enable com.levelinfinite.southpole.gamepad.settings.mtk
adb install gamepad-settings-shortcut/GamePadSettings-shortcut.apk
```

To rebuild it yourself, run `gamepad-settings-shortcut/build.sh` (Android SDK
build-tools 34 + platform 34; uses Docker for `javac` if there's no JDK). It signs
with a throwaway local keystore. The prebuilt APK is signed with a different key, so
uninstall it before installing your own build.

---

## Step 7 (optional): real status bar + notification shade (`magisk-phone-systemui/`)

**Why there's no status bar:** the vendor's framework reports a UI-mode type that
makes SystemUI resolve its `-television` resources, so it starts `TvStatusBar`
(13 services, no status bar, no shade, no quick settings) instead of the phone
`StatusBar`. Restarting SystemUI doesn't help, because it's not a boot-timing issue.
Also, Android's lock screen (`config_keyguardComponent`) is bound to the vendor
app `com.levelinfinite.southpole.gamepad.keyguard.mtk`, not SystemUI.

The Magisk module adds two runtime resource overlays (RROs) in `/product/overlay`:

| Overlay | Target | Overrides |
|---|---|---|
| `uk.karl.phonesystemui.overlay` | `com.android.systemui` | `config_systemUIServiceComponents` → phone list, `config_systemUIFactoryComponent` → `SystemUIFactory`, `config_enableKeyguardService` → true (default **and** `-television` qualifier) |
| `uk.karl.phonesystemui.frameworkoverlay` | `android` | `config_keyguardComponent` → SystemUI's `KeyguardService` |

Both are needed. With only the SystemUI overlay, the phone UI appears but its
`KeyguardViewMediator` is never bound, so it believes the device is locked forever.
The `NotificationShade` window then keeps input focus and **nothing but the shade
responds to touch**.

**Install (the order matters; keep a USB cable plugged in for recovery):**

```bash
adb shell locksettings set-disabled true     # no lock screen (the vendor one is no longer used)
# Magisk app → Modules → Install from storage → phonesystemui-v4.zip → reboot
adb shell cmd overlay enable uk.karl.phonesystemui.frameworkoverlay
adb shell cmd overlay enable uk.karl.phonesystemui.overlay
adb reboot
```

The overlays are *mutable* (not static), so they start **disabled** and can be turned
off from adb **without root**:

```bash
adb shell cmd overlay disable uk.karl.phonesystemui.overlay
adb shell cmd overlay disable uk.karl.phonesystemui.frameworkoverlay
adb reboot
```

Wireless debugging switches off when SystemUI changes, so have USB adb ready.
If all else fails, hold volume-down during boot for Magisk safe mode (this disables all modules).

Result: status bar with clock/battery, notification shade, quick settings with
brightness, heads-up notifications, gesture nav; Lawnchair works normally.
Build from source with `magisk-phone-systemui/build.sh`.

---

## Streaming notes (XBXPlay / XStreaming at 1080p)

Separate from rooting, these two cost us a day to isolate — here it is to spare
you the same:

- **Both apps' 1080p settings are overridden by console-side negotiation.**
  Xbox (Oct 2026+ firmware) streams Remote Play at 1440p whenever the *console
  display resolution* is above 1080p — the device-side "1080p" setting is ignored,
  you just get `2560x1440` H.264 sessions, which exceed the MT8168's hard decode
  limit (2048×1088) → MediaCodec `-22` / `0xffffffea` configure failures,
  12-instance codec-pool exhaustion, black screen with working audio.
- **Fix:** console → Settings → General → TV & display options → **1080p**.
  Then 1920×1080 H.264 configures fine.
- XBXPlay 2.1.0 top option is `1080p HQ` (no 1440p option exists yet); same top
  option in XStreaming.
- Moonlight on this device runs 1080p60 **HEVC** smoothly to a Sunshine/Moonlight
  host regardless (same decoder, low-latency configure keys).

---

## Restore / unroot

- Unroot: `mtk w boot_b dumps/boot_b.img` (active slot's original boot).
- Reset a frozen package: `pm enable <pkg>`.
- Module gone: uninstall in Magisk.
- Everything else byte-identical: dumps from step 1.
