#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN_TARGET="$HOME/.local/bin/keyboard-layout-autoswitch.sh"
UNIT_TARGET_DIR="$HOME/.config/systemd/user"
UNIT_NAME="keyboard-layout-autoswitch.service"
CONF_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/kb-autoswitch"
CONF_FILE="$CONF_DIR/config.env"
SUDOERS_FILE="/etc/sudoers.d/kb-autoswitch-$USER"

need_cmd() { command -v "$1" >/dev/null 2>&1; }

echo "[1/8] Installing dependencies (gawk, libinput-tools, python3 if needed)"
PKG_OK=0
if need_cmd apt-get; then
  sudo apt-get update -y
  sudo apt-get install -y gawk libinput-tools python3
  PKG_OK=1
elif need_cmd dnf; then
  sudo dnf install -y gawk libinput-tools python3
  PKG_OK=1
elif need_cmd pacman; then
  sudo pacman -S --noconfirm gawk libinput python
  PKG_OK=1
elif need_cmd zypper; then
  sudo zypper install -y gawk libinput-tools python3
  PKG_OK=1
fi
if [[ "$PKG_OK" -ne 1 ]]; then
  echo "Please install: gawk libinput-tools python3"
fi

echo "[2/8] Detecting keyboards"
# Collect devices: name and whether it looks like internal
DEVS=$(gawk -v RS="" -v ORS="\n\n" '
  /N: Name=/ && /H: Handlers=/ {
    name=""; handlers="";
    if (match($0, /N: Name="([^"]+)"/, m)) name=m[1];
    if (match($0, /H: Handlers=.*$/, h)) handlers=h[0];
    if (name=="") next;
    # consider keyboards with kbd handler
    if (handlers ~ /kbd/) {
      print name;
    }
  }' /proc/bus/input/devices | sort -u)

echo "Detected keyboard-like devices:"
echo "$DEVS" | nl -ba

# Guess laptop keyboard
LAPTOP_GUESS=""
if echo "$DEVS" | grep -qx "AT Translated Set 2 keyboard"; then
  LAPTOP_GUESS="AT Translated Set 2 keyboard"
else
  # fallback: first device in list
  LAPTOP_GUESS="$(echo "$DEVS" | head -n1)"
fi

read -rp "Laptop keyboard name [${LAPTOP_GUESS}]: " LAPTOP_NAME
LAPTOP_NAME=${LAPTOP_NAME:-$LAPTOP_GUESS}

read -rp "External keyboard name (exact, as listed) [MX KEYS B]: " EXTERNAL_NAME
EXTERNAL_NAME=${EXTERNAL_NAME:-"MX KEYS B"}

echo "[3/8] Reading your current GNOME input source"
SOURCES_RAW="$(gsettings get org.gnome.desktop.input-sources sources || echo "[]")"
CURRENT_IDX="$(gsettings get org.gnome.desktop.input-sources current 2>/dev/null || echo "0")"
CURRENT_IDX="${CURRENT_IDX//[^0-9]/}"
# Extract the layout at current index
OS_DEFAULT_LAYOUT=$(python3 - <<'PY' "$SOURCES_RAW" "$CURRENT_IDX"
import ast,sys
src=sys.argv[1]; cur=int(sys.argv[2]) if len(sys.argv)>2 and sys.argv[2].isdigit() else 0
try:
  lst=ast.literal_eval(src)
  print(lst[cur][1] if 0<=cur<len(lst) else "gb+intl")
except Exception:
  print("gb+intl")
PY
)
OS_DEFAULT_LAYOUT=${OS_DEFAULT_LAYOUT:-gb+intl}
echo "Detected current GNOME layout: $OS_DEFAULT_LAYOUT"

echo "[4/8] Pick layouts"
read -rp "Laptop layout (eg. gb, gb+intl, us, us+intl) [${OS_DEFAULT_LAYOUT}]: " INTERNAL_LAYOUT
INTERNAL_LAYOUT=${INTERNAL_LAYOUT:-$OS_DEFAULT_LAYOUT}
read -rp "External layout for \"$EXTERNAL_NAME\" [us+intl]: " EXTERNAL_LAYOUT
EXTERNAL_LAYOUT=${EXTERNAL_LAYOUT:-us+intl}

echo "[5/8] Writing config to $CONF_FILE"
mkdir -p "$CONF_DIR"
cat >"$CONF_FILE" <<EOF
# keyboard-layout-autoswitch config
EXTERNAL_NAME="$EXTERNAL_NAME"
INTERNAL_NAME="$LAPTOP_NAME"
EXTERNAL_LAYOUT="$EXTERNAL_LAYOUT"
INTERNAL_LAYOUT="$INTERNAL_LAYOUT"
SWITCH_COOLDOWN="0.25"
EOF

echo "[6/8] Installing runtime to $BIN_TARGET"
mkdir -p "$(dirname "$BIN_TARGET")"
install -m 0755 "$REPO_DIR/scripts/keyboard-layout-autoswitch.sh" "$BIN_TARGET"

echo "[7/8] Installing sudoers entry for libinput debug-events"
LIBINPUT_PATH="$(command -v libinput || echo /usr/bin/libinput)"
TMP_SUDOERS="$(mktemp)"
cat >"$TMP_SUDOERS" <<EOF
# Allow $USER to run libinput debug-events without password
$USER ALL=(root) NOPASSWD: $LIBINPUT_PATH debug-events *
EOF
sudo visudo -cf "$TMP_SUDOERS"
sudo install -m 0440 "$TMP_SUDOERS" "$SUDOERS_FILE"
rm -f "$TMP_SUDOERS"

echo "[8/8] Installing and starting systemd user service"
mkdir -p "$UNIT_TARGET_DIR"
# Fill template and write unit
sed "s#@@SCRIPT@@#$BIN_TARGET#g" "$REPO_DIR/systemd/$UNIT_NAME" > "$UNIT_TARGET_DIR/$UNIT_NAME"
systemctl --user daemon-reload
systemctl --user enable --now "$UNIT_TARGET_DIR/$UNIT_NAME"

echo
echo "Done."
echo "Current sources:"
gsettings get org.gnome.desktop.input-sources sources
echo
echo "Logs:"
echo "  journalctl --user -u $UNIT_NAME -f"
