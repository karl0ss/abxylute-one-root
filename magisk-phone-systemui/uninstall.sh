#!/system/bin/sh
# Runs when the module is removed in Magisk. The overlays disappear with the module;
# restore the default lock-screen behaviour.
locksettings set-disabled false
