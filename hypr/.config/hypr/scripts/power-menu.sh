#!/usr/bin/env bash
# Fuzzel power menu.

choice=$(printf '󰌾  Lock\n󰍃  Log out\n󰤄  Suspend\n󰜉  Reboot\n󰐥  Shut down\n' \
  | fuzzel --dmenu -p "power> " -w 22 -l 5)

case "$choice" in
  *Lock*)     hyprlock ;;
  *"Log out"*) command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()' ;;
  *Suspend*)  systemctl suspend ;;
  *Reboot*)   systemctl reboot ;;
  *"Shut down"*) systemctl poweroff ;;
esac
