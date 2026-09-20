#!/usr/bin/env bash
# Fuzzel bluetooth menu built on bluetoothctl.

notify() { notify-send -a bluetooth "$@"; }
menu() { fuzzel --dmenu -p "bt> " -w 36 "$@"; }

if ! bluetoothctl show | grep -q "Powered: yes"; then
  choice=$(printf '󰂯  Turn bluetooth on\n' | menu)
  [ -n "$choice" ] && bluetoothctl power on >/dev/null
  exit 0
fi

# Paired devices, marked when connected. Lines look like "MAC|mark name".
paired=$(bluetoothctl devices Paired | while read -r _ mac name; do
  if bluetoothctl info "$mac" | grep -q "Connected: yes"; then mark="󰂱"; else mark=" "; fi
  printf '%s|%s %s\n' "$mac" "$mark" "$name"
done)

entries=$(cut -d'|' -f2- <<< "$paired")
choice=$(printf '%s\n󰀝  Scan for new devices\n󰂲  Turn bluetooth off\n' "$entries" | sed '/^$/d' | menu)
[ -z "$choice" ] && exit 0

case "$choice" in
  *"Turn bluetooth off"*)
    bluetoothctl power off >/dev/null
    exit 0 ;;
  *"Scan for new devices"*)
    notify "Scanning..." "Put your device in pairing mode"
    bluetoothctl --timeout 10 scan on >/dev/null 2>&1
    # Only devices with a real name (skip bare-address noise), and not already paired.
    new=$(comm -23 \
      <(bluetoothctl devices | grep -vE "Device ([0-9A-F]{2}[:-]){5}[0-9A-F]{2} ([0-9A-F]{2}[:-]){5}[0-9A-F]{2}$" | sort) \
      <(bluetoothctl devices Paired | sort))
    pick=$(sed -E 's/^Device ([^ ]+) (.*)$/\1|\2/' <<< "$new" | cut -d'|' -f2- | sed '/^$/d' | menu)
    [ -z "$pick" ] && exit 0
    mac=$(grep -F " $pick" <<< "$new" | head -1 | awk '{print $2}')
    if bluetoothctl pair "$mac" >/dev/null 2>&1 \
       && bluetoothctl trust "$mac" >/dev/null 2>&1 \
       && bluetoothctl connect "$mac" >/dev/null 2>&1; then
      notify "Connected to $pick"
    else
      notify "Failed to pair $pick"
    fi
    exit 0 ;;
esac

# A paired device: toggle its connection.
name=$(sed -E 's/^. //' <<< "$choice")
mac=$(grep -F "$name" <<< "$paired" | head -1 | cut -d'|' -f1)
if bluetoothctl info "$mac" | grep -q "Connected: yes"; then
  bluetoothctl disconnect "$mac" >/dev/null 2>&1 \
    && notify "Disconnected from $name" || notify "Failed to disconnect $name"
else
  bluetoothctl connect "$mac" >/dev/null 2>&1 \
    && notify "Connected to $name" || notify "Failed to connect $name"
fi
