#!/usr/bin/env bash
# Fuzzel wifi picker built on nmcli.

notify() { notify-send -a wifi "$@"; }

nmcli device wifi rescan >/dev/null 2>&1

if [ "$(nmcli radio wifi)" = "disabled" ]; then
  choice=$(printf '󰖩  Turn wifi on\n' | fuzzel --dmenu -p "wifi> ")
  [ -n "$choice" ] && nmcli radio wifi on
  exit 0
fi

list=$(nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY device wifi list | awk -F: '
  $2 != "" && !seen[$2]++ {
    mark = ($1 == "*") ? "󰄬" : " "
    sec = ($4 == "") ? "" : ""
    printf "%s %s  %s%%  %s\n", mark, $2, $3, sec
  }')

choice=$(printf '%s\n󰖪  Turn wifi off\n' "$list" | fuzzel --dmenu -p "wifi> " -w 40)
[ -z "$choice" ] && exit 0

if [[ "$choice" == *"Turn wifi off"* ]]; then
  nmcli radio wifi off
  exit 0
fi

# Strip the leading mark and the trailing "  NN%  icon" to recover the SSID.
ssid=$(sed -E 's/^. //; s/  [0-9]+%  ?.*$//' <<< "$choice")

# Known network: just connect.
if nmcli -t -f NAME connection show | grep -Fxq "$ssid"; then
  nmcli connection up id "$ssid" >/dev/null 2>&1 \
    && notify "Connected to $ssid" || notify "Failed to connect to $ssid"
  exit 0
fi

# Open network.
if [[ "$choice" != *""* ]]; then
  nmcli device wifi connect "$ssid" >/dev/null 2>&1 \
    && notify "Connected to $ssid" || notify "Failed to connect to $ssid"
  exit 0
fi

# Secured, new network: ask for the password.
pass=$(fuzzel --dmenu --password -p "password> " -l 0 </dev/null)
[ -z "$pass" ] && exit 0
nmcli device wifi connect "$ssid" password "$pass" >/dev/null 2>&1 \
  && notify "Connected to $ssid" || notify "Failed to connect to $ssid"
