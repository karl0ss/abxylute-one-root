#!/usr/bin/env bash
# 20-restore.sh — put the active slot back to stock (unroot / recover from vbmeta bootloop).
# USAGE: ./20-restore.sh <slot a|b> <dumps-dir>
set -euo pipefail
SLOT="${1:?slot: a or b}"
DIR="${2:?dumps dir}"
MTK="${MTK:-mtk}"
echo "restoring boot_${SLOT} and vbmeta_${SLOT} from $DIR"
"$MTK" w "boot_${SLOT},vbmeta_${SLOT}" "$DIR/boot_${SLOT}.img,$DIR/vbmeta_${SLOT}.img"
