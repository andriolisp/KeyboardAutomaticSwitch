#!/usr/bin/env bash
set -euo pipefail

echo "Keyboard-like devices from /proc/bus/input/devices:"
/usr/bin/gawk -v RS="" -v ORS="\n\n" '
  /N: Name=/ && /H: Handlers=/ {
    name=""; handlers="";
    if (match($0, /N: Name="([^"]+)"/, m)) name=m[1];
    if (match($0, /H: Handlers=.*$/, h)) handlers=h[0];
    if (name=="" || handlers=="") next;
    if (handlers ~ /kbd|event/) {
      print "- " name;
    }
  }' /proc/bus/input/devices
