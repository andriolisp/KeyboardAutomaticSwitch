#!/usr/bin/env bash
set -euo pipefail

UNIT_NAME="keyboard-layout-autoswitch.service"
UNIT_PATH="$HOME/.config/systemd/user/$UNIT_NAME"
BIN_PATH="$HOME/.local/bin/keyboard-layout-autoswitch.sh"
CONF_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/kb-autoswitch"
SUDOERS_FILE="/etc/sudoers.d/kb-autoswitch-$USER"

echo "[1/4] Stop and disable service"
systemctl --user stop "$UNIT_NAME" || true
systemctl --user disable "$UNIT_NAME" || true
systemctl --user daemon-reload || true

echo "[2/4] Remove files"
rm -f "$UNIT_PATH"
rm -f "$BIN_PATH"
rm -rf "$CONF_DIR"

echo "[3/4] Remove sudoers entry"
if [[ -f "$SUDOERS_FILE" ]]; then
  sudo rm -f "$SUDOERS_FILE"
fi

echo "[4/4] Done"
