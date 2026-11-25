#!/system/bin/sh
# First boot after install: enable both overlays (they are mutable, so they start
# disabled), turn off the lock screen (the vendor one is no longer bound), then reboot
# once so SystemUI and the keyguard binding pick them up. Runs only once per install:
# disabling the overlays later via adb stays respected.
MODDIR=${0%/*}
FLAG="$MODDIR/.activated"
LOG=/data/local/tmp/phonesysui.log
[ -f "$FLAG" ] && exit 0

until [ "$(getprop sys.boot_completed)" = "1" ]; do sleep 2; done
sleep 5
{
  echo "$(date) phonesystemui first-run activation"
  locksettings set-disabled true
  cmd overlay enable uk.karl.phonesystemui.frameworkoverlay
  cmd overlay enable uk.karl.phonesystemui.overlay
  cmd overlay list | grep uk.karl.phonesystemui
} >> "$LOG" 2>&1
chmod 644 "$LOG"
if cmd overlay list | grep -q "\[x\] uk.karl.phonesystemui.overlay" && \
   cmd overlay list | grep -q "\[x\] uk.karl.phonesystemui.frameworkoverlay"; then
  touch "$FLAG"
  echo "$(date) activated, rebooting" >> "$LOG"
  sleep 2
  reboot
else
  # No flag and no reboot: the next boot retries, and there's no reboot loop.
  echo "$(date) overlays did not enable; not rebooting" >> "$LOG"
fi
