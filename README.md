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
pm disable-user -k com.levelinfinite.southpole.gamepad.settings.mtk
pm disable-user -k com.levelinfinite.southpole.gamepad.quicksetting.mtk

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

Result on ours: MemAvailable went ~1.2GB → 1.8-2.1GB, swap from ~700MB → ~80MB,
and the "sluggish device" problem was mostly **memory pressure + kswapd churn**,
not CPU or Wi-Fi.

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
