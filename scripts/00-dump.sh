#!/usr/bin/env bash
# 00-dump.sh — read-only dump of the abxylute One's key partitions via mtkclient.
# Usage: ./00-dump.sh [output-dir]   (default: ./dumps)
set -euo pipefail
OUT="${1:-./dumps}"
MTK="${MTK:-mtk}"
mkdir -p "$OUT"
for p in boot_a boot_b vbmeta_a vbmeta_b lk_a lk_b vendor_boot_a vendor_boot_b dtbo_a dtbo_b seccfg proinfo para; do
  echo "== dumping $p"
  # each invocation does its own BROM/preloader handshake — if it waits, replug the cable
  "$MTK" r "$p" "$OUT/$p.img" 2>&1 | tail -2 || true
done
md5sum "$OUT"/*.img
