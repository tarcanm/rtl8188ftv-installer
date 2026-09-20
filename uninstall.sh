#!/usr/bin/env bash
#
# RTL8188FTV / RTL8188FU USB WiFi adapter — uninstaller
# Removes the DKMS module, firmware, and config files created by install.sh.
#
# Usage:  sudo bash uninstall.sh
#
set -euo pipefail

SRC_DIR="/usr/src/rtl8188fu"
FIRMWARE_DIR="/lib/firmware/rtlwifi"
FIRMWARE_FILE="rtl8188fufw.bin"
CONF="/etc/modprobe.d/rtl8188fu.conf"
ALIAS_CONF="/etc/modprobe.d/rtl8xxxu-8188fu-alias.conf"

echo "=== RTL8188FTV uninstaller — $(date '+%F %T') ==="
if [ "$(id -u)" -ne 0 ]; then
  echo "ERROR: this script needs root.  Run:  sudo bash $0"
  exit 1
fi

NAME="rtl8188fu"
VER="1.0"
if [ -f "$SRC_DIR/dkms.conf" ]; then
  parsed=$(sed -n 's/^PACKAGE_NAME="\(.*\)"/\1/p' "$SRC_DIR/dkms.conf" | head -1)
  [ -n "$parsed" ] && NAME="$parsed"
  parsed=$(sed -n 's/^PACKAGE_VERSION="\(.*\)"/\1/p' "$SRC_DIR/dkms.conf" | head -1)
  [ -n "$parsed" ] && VER="$parsed"
fi

echo "--- unload module ---"
modprobe -r "$NAME" 2>/dev/null || true

echo "--- remove DKMS ${NAME}/${VER} ---"
if command -v dkms >/dev/null 2>&1; then
  dkms remove -m "$NAME" -v "$VER" --all 2>&1 | tail -5 || echo "WARNING: dkms remove reported an error (continuing)"
  dkms status 2>/dev/null | grep -i 8188 && echo "WARNING: an rtl8188fu entry is still in dkms status" || echo "dkms status is clean"
fi

echo "--- remove files ---"
for f in "$CONF" "$ALIAS_CONF" "$FIRMWARE_DIR/$FIRMWARE_FILE"; do
  if [ -e "$f" ]; then rm -f "$f" && echo "removed $f"; fi
done
if [ -d "$SRC_DIR" ]; then rm -rf "$SRC_DIR" && echo "removed $SRC_DIR"; fi
rm -f "/usr/src/${NAME}-${VER}" 2>/dev/null || true

depmod -a 2>/dev/null || true
echo "=== done ==="
echo "On kernels >= 6.2 the built-in rtl8xxxu driver takes over after a re-plug;"
echo "on older kernels the adapter will stop working until install.sh is run again."
