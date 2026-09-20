#!/usr/bin/env bash
#
# RTL8188FTV / RTL8188FU USB WiFi adapter — one-command installer
# Tested on MX Linux 23 (Debian 12, kernel 6.1, SysVinit, Fluxbox).
# Works via DKMS on kernels 4.15 – 7.x; on kernel >= 6.2 the built-in rtl8xxxu
# also supports this chip, and this script makes the DKMS module win.
#
# Usage:
#   sudo bash install.sh            install / update
#   sudo bash install.sh --check    report only, change nothing
#   sudo bash install.sh --force    install even if an interface already works
#
set -euo pipefail

DRIVER_REPO="https://github.com/kelebek333/rtl8188fu"
SRC_DIR="/usr/src/rtl8188fu"
FIRMWARE_DIR="/lib/firmware/rtlwifi"
FIRMWARE_FILE="rtl8188fufw.bin"
CONF="/etc/modprobe.d/rtl8188fu.conf"
ALIAS_CONF="/etc/modprobe.d/rtl8xxxu-8188fu-alias.conf"
LOG="/var/log/rtl8188ftv-install.log"

VID="0bda"          # Realtek
PID="f179"          # RTL8188FTV / RTL8188FU (1x1, 2.4 GHz)

MODE="install"
for arg in "$@"; do
  case "$arg" in
    --check) MODE="check" ;;
    --force) MODE="force" ;;
    -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
    *) echo "Unknown option: $arg (see --help)"; exit 2 ;;
  esac
done

if [ "$MODE" != "check" ]; then
  touch "$LOG" 2>/dev/null || true
  exec > >(tee -a "$LOG") 2>&1
fi

echo "=== RTL8188FTV installer — $(date '+%F %T') — mode: $MODE ==="
echo "kernel: $(uname -r)  |  distro: $( (. /etc/os-release 2>/dev/null && echo "${PRETTY_NAME:-unknown}") || echo unknown)  |  init: $(ps -p 1 -o comm= 2>/dev/null)"

if [ "$MODE" != "check" ] && [ "$(id -u)" -ne 0 ]; then
  echo "ERROR: this script needs root.  Run:  sudo bash $0"
  exit 1
fi

# ---------------------------------------------------------------- 1/7 device
echo "--- 1/7 device on USB ---"
DEV_PATH=""
for d in /sys/bus/usb/devices/*/; do
  [ -r "$d/idVendor" ] || continue
  if [ "$(cat "$d/idVendor" 2>/dev/null)" = "$VID" ] && [ "$(cat "$d/idProduct" 2>/dev/null)" = "$PID" ]; then
    DEV_PATH="${d%/}"; break
  fi
done
if [ -n "$DEV_PATH" ]; then
  echo "found at $DEV_PATH"
  if command -v lsusb >/dev/null 2>&1; then lsusb | grep -iE "${VID}:${PID}" || true; fi
else
  echo "WARNING: no adapter ${VID}:${PID} found on USB."
  echo "         Plug it in first — a direct rear port is more reliable than a hub —"
  echo "         then run this script again (or attach it and re-run)."
  if [ "$MODE" = "install" ]; then exit 1; fi
fi

# ------------------------------------------------------- 2/7 already working?
echo "--- 2/7 existing interface ---"
ifaces=""
for d in /sys/bus/usb/devices/*/; do
  [ -r "$d/idVendor" ] || continue
  [ "$(cat "$d/idVendor" 2>/dev/null)" = "$VID" ] || continue
  [ "$(cat "$d/idProduct" 2>/dev/null)" = "$PID" ] || continue
  for n in "$d"*/net/*; do
    if [ -e "$n" ]; then ifaces="$ifaces $(basename "$n")"; fi
  done
  echo "usb path: ${d%/}  driver: $(basename "$(readlink -f "$d/driver" 2>/dev/null)" 2>/dev/null || echo none)"
done
if [ -n "$ifaces" ]; then
  echo "adapter already provides interface(s):$ifaces — nothing to install."
  if [ "$MODE" != "force" ]; then
    echo "(re-run with --force to install the DKMS driver anyway)"
    exit 0
  fi
else
  echo "no network interface for this adapter yet — installing the driver."
fi

# --------------------------------------------------- check mode: report only
if [ "$MODE" = "check" ]; then
  echo "--- report only, nothing will be changed ---"
  echo "dkms:            $(command -v dkms >/dev/null 2>&1 && dkms --version 2>/dev/null | head -1 || echo 'not installed')"
  echo "build-essential: $(dpkg-query -W -f='${Status} ${Version}\n' build-essential 2>/dev/null || echo 'not installed')"
  echo "headers $(uname -r): $(dpkg-query -W -f='${Status} ${Version}\n' "linux-headers-$(uname -r)" 2>/dev/null || echo 'not installed')"
  echo "source tree:     $([ -d "$SRC_DIR" ] && echo "$SRC_DIR (present)" || echo 'not downloaded yet')"
  echo "dkms status:     $(dkms status 2>/dev/null | grep -i 8188 || echo 'no rtl8188fu entry')"
  echo "firmware:        $([ -f "$FIRMWARE_DIR/$FIRMWARE_FILE" ] && echo "installed" || echo 'not installed')"
  echo "loaded module: $(lsmod 2>/dev/null | grep -i rtl8188fu || echo 'NOT loaded')"
  echo "module options:  $([ -f "$CONF" ] && cat "$CONF" || echo 'none')"
  echo "To install: sudo bash install.sh"
  exit 0
fi

# --------------------------------------------------------- 3/7 dependencies
echo "--- 3/7 build tools + kernel headers ---"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq 2>&1 | tail -2 || echo "WARNING: apt-get update failed (offline?) — continuing"
if ! apt-get install -y build-essential git dkms "linux-headers-$(uname -r)"; then
  echo "ERROR: could not install build-essential/git/dkms/linux-headers-$(uname -r)."
  echo "       On MX Linux make sure a linux-headers package for the running kernel"
  echo "       is installed (MX Package Installer -> Kernels), then run this again."
  exit 1
fi

# ----------------------------------------------------------- 4/7 driver source
echo "--- 4/7 driver source ---"
if [ -d "$SRC_DIR/.git" ]; then
  git -C "$SRC_DIR" pull --ff-only 2>&1 | tail -2 || echo "WARNING: git pull failed — using the existing checkout"
else
  rm -rf "$SRC_DIR"
  git clone --depth 1 "$DRIVER_REPO" "$SRC_DIR" || { echo "ERROR: git clone failed (network?)"; exit 1; }
fi

# ---------------------------------------------------------------- 5/7 DKMS
echo "--- 5/7 DKMS build + install ---"
if dkms install "$SRC_DIR"; then
  echo "dkms install OK"
else
  NAME=$(sed -n 's/^PACKAGE_NAME="\(.*\)"/\1/p' "$SRC_DIR/dkms.conf" | head -1)
  VER=$(sed -n 's/^PACKAGE_VERSION="\(.*\)"/\1/p' "$SRC_DIR/dkms.conf" | head -1)
  echo "fallback: dkms add/build/install ${NAME}/${VER}"
  ln -sfn "$SRC_DIR" "/usr/src/${NAME}-${VER}"
  dkms add     -m "$NAME" -v "$VER"
  dkms build   -m "$NAME" -v "$VER"
  dkms install -m "$NAME" -v "$VER"
fi
dkms status 2>/dev/null | grep -i 8188 || echo "WARNING: no rtl8188fu entry in dkms status"

# ------------------------------------------- 6/7 firmware + module options
echo "--- 6/7 firmware + module options ---"
mkdir -p "$FIRMWARE_DIR"
if [ -f "$SRC_DIR/firmware/$FIRMWARE_FILE" ]; then
  if install -m 644 "$SRC_DIR/firmware/$FIRMWARE_FILE" "$FIRMWARE_DIR/"; then
    echo "firmware -> $FIRMWARE_DIR/$FIRMWARE_FILE"
  else
    echo "WARNING: could not copy the firmware file"
  fi
else
  echo "WARNING: $FIRMWARE_FILE not found in the source tree — driver may fail to load."
fi

# Disable power management: fixes drop-outs and plug/re-plug problems (upstream recommendation)
echo 'options rtl8188fu rtw_power_mgnt=0 rtw_enusbss=0 rtw_ips_mode=0' > "$CONF"
echo "module options -> $CONF"

KMaj=$(uname -r | cut -d. -f1)
KMin=$(uname -r | cut -d. -f2)
if [ "$KMaj" -gt 6 ] || { [ "$KMaj" -eq 6 ] && [ "$KMin" -ge 2 ]; }; then
  echo 'alias usb:v0BDApF179d*dc*dsc*dp*icFFiscFFipFFin* rtl8188fu' > "$ALIAS_CONF"
  echo "kernel >= 6.2: built-in rtl8xxxu also claims this chip -> alias written to $ALIAS_CONF"
  if command -v update-initramfs >/dev/null 2>&1; then
    update-initramfs -u -k all 2>&1 | tail -2 || echo "WARNING: update-initramfs failed (not fatal)"
  fi
fi

# ------------------------------------------------------- 7/7 load + verify
echo "--- 7/7 load module and verify ---"
if [ "$MODE" != "check" ]; then
  modprobe -r rtl8188fu 2>/dev/null || true
  depmod -a
  if ! modprobe rtl8188fu; then
    echo "ERROR: 'modprobe rtl8188fu' failed. Check the build log above and: dmesg | tail -30"
    exit 1
  fi
  sleep 3
fi

"$(lsmod 2>/dev/null | grep -i rtl8188fu || echo 'NOT loaded')"
echo "wireless interfaces:"
ip -br link | grep -E '^wl' || echo "  (none yet — replug the adapter, then check dmesg)"
if [ -x /sbin/iw ] || command -v iw >/dev/null 2>&1; then
  iw dev 2>/dev/null | head -24 || true
fi
if command -v nmcli >/dev/null 2>&1; then
  echo "NetworkManager:"; nmcli device status 2>&1 | grep -Ei 'wifi|DEVICE' || true
fi
if command -v rfkill >/dev/null 2>&1; then
  echo "rfkill:"; rfkill list 2>/dev/null | head -8 || true
fi

echo "=== done — log: $LOG ==="
echo "Next steps:"
echo "  nmcli dev wifi list                 # list networks (no root needed)"
echo "  nmcli dev wifi connect \"SSID\" password \"PASSWORD\""
echo "Uninstall:  sudo bash uninstall.sh"
