#!/bin/bash
# One-time welcome dialog on the live console (interactive login shells only).

if [ -n "$PS1" ] && [ -z "$WARBLE_TUTORIAL_SEEN" ] && [ -t 0 ] \
   && command -v dialog >/dev/null 2>&1 && [ "$(tty)" = "/dev/tty1" ]; then
    export WARBLE_TUTORIAL_SEEN=1

    tools="- Terminator, Firefox, Openbox (run 'startx')\n- git, vim, nano, curl"
    command -v go >/dev/null 2>&1 && tools="$tools\n- Go, Rust, Python, Node.js, Neovim, tmux"
    command -v docker >/dev/null 2>&1 && tools="$tools\n- Docker, docker-compose, kubectl, helm"

    dialog --backtitle "Warble Linux live sandbox" \
           --title "Welcome to Warble Linux" \
           --msgbox "This is an ephemeral live sandbox.\n\nEverything you change lives in RAM and is gone after reboot.\n\nFirewall: inbound connections are blocked; outbound network access is allowed." 12 64
    dialog --backtitle "Warble Linux live sandbox" \
           --title "Included tools" \
           --msgbox "$tools" 12 64
    clear
fi
