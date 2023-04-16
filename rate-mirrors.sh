#!/bin/bash

# Repo list from rate-mirrors
repolist=(arch archarm archlinuxcn artix cachyos chaotic-aur endeavouros manjaro rebornos)


# Colors
NONE='\e[0m'
LRED='\e[1;31m'
LGREEN='\e[1;32m'
LBLUE='\e[1;34m'

# Help
if [ "$1" = help ] || [ "$1" = --help ] || [[ -z "$1" ]] || [[ ! "${repolist[*]}" =~ ${1} ]]; then
    printf "%s""$LRED""No $LGREEN$1$LRED repo found! Avaiable options are:""\n""%s""$LBLUE{${repolist[*]}} $LRED{remove}$NONE"
    exit
fi

# Temp file
MIRRORLIST_TEMP="$(mktemp)"

# $1, $2, $3... stands for arguments, for example: $1 = first argument $2 = second argument $3 = third argument and so on
repo=$1

# Remove repo
if [ "$2" = remove ]; then
    # Check if repo is configured
    if grep -q "\[$repo]" "/etc/pacman.conf"; then
        # Remove repo
        sudo sed -i "/$repo/{N;d;}" /etc/pacman.conf
        sudo rm /etc/pacman.d/"$repo"-mirrorlist
        exit
    fi
    # If not configured
    printf "%s""$LRED""There is no $repo repo configured!""\n""Look in /etc/pacman.conf to get configured repos"
    exit
fi

# Rate mirrors
printf "\n""%s""$LGREEN""Rating mirrors...""$NONE""\n"
rate-mirrors --allow-root --save="$MIRRORLIST_TEMP" "$repo" > /dev/null

# Get mirrors from the rate-mirrors temp file
grep -qe "^Server = http" "$MIRRORLIST_TEMP" 

# Add mirrors to corresponding mirrorlist
if [ "$repo" = arch ]; then
    sudo install -m644 "$MIRRORLIST_TEMP" /etc/pacman.d/mirrorlist
else
    sudo install -m644 "$MIRRORLIST_TEMP" "/etc/pacman.d/$repo-mirrorlist"
    # Check if repo is configured and add if not
    if ! grep -q "\[$repo]" "/etc/pacman.conf"; then
        # Ask to trust without signature
        echo 'Do you want to trust mirrors without signature. This may fix some issues(Y/n) '
        read -r choice
        if [ "$choice" = n ]; then
            printf "\n""%s""[$repo]""\nInclude = ""%s""/etc/pacman.d/$repo-mirrorlist" | sudo tee -a /etc/pacman.conf > /dev/null
        else
            printf "\n""%s""[$repo]""\nInclude = ""%s""/etc/pacman.d/$repo-mirrorlist""\nSigLevel = Optional TrustAll" | sudo tee -a /etc/pacman.conf > /dev/null
        fi
    fi
fi

# Update mirrors
printf "\n""%s""$LGREEN""Updating mirrors...""$NONE""\n"
sudo pacman -Syyu --noconfirm

# Remove temp file
rm "$MIRRORLIST_TEMP"

printf "%s""$LGREEN""Done!""$NONE"