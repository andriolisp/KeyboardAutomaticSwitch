#!/usr/bin/env bash
set -euo pipefail

# Load config
CONF_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/kb-autoswitch/config.env"
if [[ -f "$CONF_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$CONF_FILE"
fi

# Defaults if not set
EXTERNAL_NAME="${EXTERNAL_NAME:-MX KEYS B}"
INTERNAL_NAME="${INTERNAL_NAME:-AT Translated Set 2 keyboard}"
EXTERNAL_LAYOUT="${EXTERNAL_LAYOUT:-us+intl}"
INTERNAL_LAYOUT="${INTERNAL_LAYOUT:-gb+intl}"
SWITCH_COOLDOWN="${SWITCH_COOLDOWN:-0.25}"

US_TUPLE="('xkb', '$EXTERNAL_LAYOUT')"
GB_TUPLE="('xkb', '$INTERNAL_LAYOUT')"

log() { printf '[kb-auto] %s\n' "$*" >&2; }

set_sources_single() {
  gsettings set org.gnome.desktop.input-sources sources "[${1}]"
}

# Keep both visible in the GNOME menu, active first
set_sources_dual() {
  gsettings set org.gnome.desktop.input-sources sources "[${1}, ${2}]"
}

want_external() { set_sources_dual "$US_TUPLE" "$GB_TUPLE"; }
want_internal() { set_sources_dual "$GB_TUPLE" "$US_TUPLE"; }

# Return current active source string like "us+intl"
get_current_source() {
  python3 - <<'PY'
import ast, subprocess
try:
  sources = ast.literal_eval(subprocess.check_output(
      ['gsettings','get','org.gnome.desktop.input-sources','sources'], text=True).strip())
  cur = int(subprocess.check_output(
      ['gsettings','get','org.gnome.desktop.input-sources','current'], text=True).strip())
  if 0 <= cur < len(sources):
    print(sources[cur][1])
except Exception:
  pass
PY
}

declare -A EV2NAME
refresh_evmap() {
  EV2NAME=()
  while IFS=$'\t' read -r name ev; do
    [[ -n "${name:-}" && -n "${ev:-}" ]] || continue
    EV2NAME["$ev"]="$name"
  done < <(
    /usr/bin/gawk -v RS="" -v ORS="\n\n" '
      /N: Name=/ && /H: Handlers=/ {
        name=""; handlers="";
        if (match($0, /N: Name="([^"]+)"/, m)) name=m[1];
        if (match($0, /H: Handlers=.*$/, h)) handlers=h[0];
        while (match(handlers, /(event[0-9]+)/, e)) {
          print name "\t" e[1];
          handlers = substr(handlers, RSTART+RLENGTH);
        }
      }' /proc/bus/input/devices
  )
}

last_switch_time=0
should_switch() {
  local now dt
  now=$(date +%s.%N)
  dt=$(awk -v n="$now" -v l="$last_switch_time" 'BEGIN{print n-l}')
  awk -v x="$dt" -v c="$SWITCH_COOLDOWN" 'BEGIN{print (x>=c)?"1":"0"}'
}

# Start
refresh_evmap
log "External='$EXTERNAL_NAME' uses $EXTERNAL_LAYOUT"
log "Internal='$INTERNAL_NAME' uses $INTERNAL_LAYOUT"
log "Listening for key events..."

while IFS= read -r line; do
  # event id
  if [[ "$line" =~ ^[[:space:]]*(event[0-9]+)[[:space:]] ]]; then
    ev="${BASH_REMATCH[1]}"
  else
    continue
  fi
  # key action
  if [[ "$line" =~ [[:space:]](KEY_[A-Z0-9_]+)[[:space:]]\([0-9]+\)[[:space:]](pressed|repeat)$ ]]; then
    : # matches only
  else
    continue
  fi

  name="${EV2NAME[$ev]:-}"
  if [[ -z "$name" ]]; then
    refresh_evmap
    name="${EV2NAME[$ev]:-}"
    [[ -z "$name" ]] && continue
  fi

  current_source="$(get_current_source || true)"
  [[ -z "$current_source" ]] && continue

  if [[ "$name" == "$EXTERNAL_NAME" && "$current_source" != "$EXTERNAL_LAYOUT" ]]; then
    if [[ $(should_switch) -eq 1 ]]; then
      log "Switch to $EXTERNAL_LAYOUT (key from $EXTERNAL_NAME, $ev)"
      want_external
      last_switch_time=$(date +%s.%N)
    fi
  elif [[ "$name" == "$INTERNAL_NAME" && "$current_source" != "$INTERNAL_LAYOUT" ]]; then
    if [[ $(should_switch) -eq 1 ]]; then
      log "Switch to $INTERNAL_LAYOUT (key from $INTERNAL_NAME, $ev)"
      want_internal
      last_switch_time=$(date +%s.%N)
    fi
  fi
done < <(sudo -n "$(command -v libinput)" debug-events --show-keycodes 2>/dev/null)
