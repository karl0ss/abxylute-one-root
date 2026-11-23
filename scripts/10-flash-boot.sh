#!/usr/bin/env bash
# 10-flash-boot.sh — flash a Magisk-patched boot to the ACTIVE slot.
# USAGE: ./10-flash-boot.sh <slot a|b> <magisk_patched_boot.img>
# WARNING: writes to eMMC. Keep the original dump handy.
set -euo pipefail
SLOT="${1:?slot required: a or b}"
IMG="${2:?magisk patched boot image required}"
MTK="${MTK:-mtk}"
PART="boot_${SLOT}"
echo "flashing $IMG -> $PART"
# device must be powered OFF; when mtk prints "Waiting for PreLoader", plug the cable in
"$MTK" w "$PART" "$IMG"
