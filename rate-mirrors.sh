#!/bin/bash
repolist=(arch archarm archlinuxcn artix cachyos chaotic-aur endeavouros manjaro rebornos)

NONE='\e[0m'
LRED='\e[1;31m'
LGREEN='\e[1;32m'
LBLUE='\e[1;34m'
if [ "$1" = help ] || [ "$1" = --help ] || [[ -z "$1" ]] || [[ ! "${repolist[*]}" =~ ${1} ]]; then
    printf "%s""$LRED""No $LGREEN$1$LRED repo found! Avaiable options are:""\n""%s""$LBLUE${repolist[*]}$NONE"
    exit
fi

MIRRORLIST_TEMP="$(mktemp)"

repo=$1

rate-mirrors --allow-root --save="$MIRRORLIST_TEMP" "$repo"
grep -qe "^Server = http" "$MIRRORLIST_TEMP" 

if [ "$repo" = arch ]; then
    sudo install -m644 "$MIRRORLIST_TEMP" /etc/pacman.d/mirrorlist
else
    sudo install -m644 "$MIRRORLIST_TEMP" "/etc/pacman.d/$repo-mirrorlist"
    if ! grep -q "\[$repo]" "/etc/pacman.conf"; then
        echo 'Do you want to trust mirrors without signature. This may fix some issues(Y/n) '
        read -r choice
        if [ "$choice" = n ]; then
            printf "\n""%s""[$repo]""\nInclude = ""%s""/etc/pacman.d/$repo-mirrorlist" | sudo tee -a /etc/pacman.conf > /dev/null
        else
            printf "\n""%s""[$repo]""\nInclude = ""%s""/etc/pacman.d/$repo-mirrorlist""\nSigLevel = Optional TrustAll" | sudo tee -a /etc/pacman.conf > /dev/null
        fi
    fi
fi

sudo pacman -Syy
rm "$MIRRORLIST_TEMP"
printf "%s""$LGREEN""Done!""$NONE"