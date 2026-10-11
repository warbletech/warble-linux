#!/bin/bash
# Warble Linux welcome (interactive login shells). Lists only what is installed.
# Runs after warble-tutorial.sh (profile.d is sourced in name order).
case $- in *i*) ;; *) return 0 2>/dev/null || exit 0 ;; esac
[ -n "$WARBLE_MOTD_SHOWN" ] && return 0
export WARBLE_MOTD_SHOWN=1

variant=minimal; version=
if [ -r /etc/warble-release ]; then
  variant=$(sed -n 's/^VARIANT=//p' /etc/warble-release)
  version=$(sed -n 's/^VERSION=//p' /etc/warble-release)
fi
case $variant in
  developer)    bird="Starling";    blurb="mimics any language: a polyglot dev toolbox" ;;
  cloud-native) bird="Heron";       blurb="watches the stream: containers and Kubernetes" ;;
  full)         bird="Murmuration"; blurb="the whole flock, moving as one" ;;
  *)            bird="Warble";      blurb="a clear signal: small and quick" ;;
esac

c=$'\e[1;36m'; v=$'\e[1;35m'; y=$'\e[1;33m'; d=$'\e[2m'; b=$'\e[1m'; r=$'\e[0m'
printf '%s\n' \
  "${c}       __       ${v})${r}" \
  "${c}   ___( o)${y}>${c}    ${v}))${r}    ${b}Warble Linux${r} ${d}${version}${r}" \
  "${c}   \\ <_. )    ${v})))${r}   ${variant} edition ${d}· ${bird}: ${blurb}${r}" \
  "${c}    \`---'      ${v}))${r}    ${d}disposable live sandbox: everything lives in RAM${r}" \
  "${d}  ====|=|====   ${v})${r}"

have() { command -v "$1" >/dev/null 2>&1; }
tools=""
add() { have "$1" && tools="$tools $2"; }
add git git; add vim vim; add nano nano; add curl curl
add go go; add rustc rust; add python3 python; add node node; add nvim neovim; add tmux tmux
add docker docker; add kubectl kubectl; add helm helm
gui=""; have startx && have openbox && gui="openbox (run ${b}startx${r})"; have firefox && gui="$gui, firefox"; have terminator && gui="$gui, terminator"
echo
echo "  ${b}tools${r} :${tools}"
[ -n "$gui" ] && echo "  ${b}desktop${r}: $gui"
if have nft && nft list chain inet filter input 2>/dev/null | grep -q 'policy drop'; then
  echo "  ${b}firewall${r}: inbound blocked, outbound allowed (nftables)"
fi
echo "  ${b}help${r}  : https://github.com/warbletech/warble-linux"
echo
