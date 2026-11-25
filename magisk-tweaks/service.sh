#!/system/bin/sh
MODDIR=${0%/*}
LOG=/data/local/tmp/abxytweaks.log
exec >> "$LOG" 2>&1
echo "=== $(date) abxytweaks boot"

# --- adb root, once per install. Magisk rejects su from uid 2000 (adb shell) without
# a prompt when its root_access setting excludes ADB; the app UI for it can be hard
# to find, so set it here. Revoking it later in the Magisk app sticks.
if [ ! -f /data/adb/.abxytweaks-adbroot-done ]; then
  echo "magisk settings before:"; magisk --sqlite "SELECT key,value FROM settings"
  echo "magisk policies before:"; magisk --sqlite "SELECT uid,policy,until FROM policies"
  # root_access: 0 disabled, 1 apps only, 2 adb only, 3 apps and adb
  magisk --sqlite "REPLACE INTO settings (key,value) VALUES('root_access',3)"
  # policy 2 = allow, until 0 = forever
  magisk --sqlite "REPLACE INTO policies (uid,policy,until,logging,notification) VALUES(2000,2,0,1,1)"
  echo "magisk settings after:"; magisk --sqlite "SELECT key,value FROM settings"
  touch /data/adb/.abxytweaks-adbroot-done
fi

until [ "$(getprop sys.boot_completed)" = "1" ]; do sleep 2; done

# --- vendor settings app: keep the settings screen, drop its background processes
P=com.levelinfinite.southpole.gamepad.settings.mtk
for c in com.levelinfinite.southpole.gamepad.ota.OTAService \
         com.levelinfinite.southpole.gamepad.settings.report.SettingsDailyCollectReceiver \
         com.levelinfinite.southpole.gamepad.feature.model.FeatureProvider; do
  pm disable "$P/$c" >/dev/null && echo "disabled $c"
done
for p in $P:ota $P:feature; do pid=$(pidof "$p") && kill "$pid" && echo "killed $p"; done

# --- CPU governor: the firmware pins all 4 cores at 2.0GHz ('performance').
# schedutil still ramps to 2.0GHz under load but idles at 850MHz (~70% of idle time).
for g in /sys/devices/system/cpu/cpufreq/policy*/scaling_governor; do
  echo schedutil > "$g" && echo "$g -> schedutil"
done

# --- recents: the vendor "gamepad mode" flag (left at 1 by their console launcher) makes
# the vendor SystemUI skip binding Launcher3's recents service, so swipe-up-and-hold shows
# nothing. SystemUI only reads the flag at start, so if it was set, clear it and restart
# SystemUI. Clearing it can make the vendor app switch Home to Launcher3, so put Lawnchair back.
if [ "$(settings get system gamepad_launcher_style)" != "0" ]; then
  settings put system gamepad_launcher_style 0 && echo "gamepad_launcher_style -> 0"
  sleep 3
  if pm path app.lawnchair >/dev/null 2>&1 && \
     [ "$(cmd role get-role-holders android.app.role.HOME)" != "app.lawnchair" ]; then
    cmd role add-role-holder android.app.role.HOME app.lawnchair 0 && echo "home -> lawnchair"
  fi
  pid=$(pidof com.android.systemui) && kill "$pid" && echo "restarted systemui"
fi

# --- wireless adb on a fixed port (legacy tcpip mode, still needs an authorised key)
if [ "$(getprop service.adb.tcp.port)" != "5555" ]; then
  setprop service.adb.tcp.port 5555
  setprop ctl.restart adbd
  echo "adb tcp port 5555"
fi
chmod 644 "$LOG"
