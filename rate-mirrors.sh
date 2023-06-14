#!/bin/bash

arch=$(uname -m)

# Repo list from rate-mirrors
repolist=(arch archarm archlinuxcn "artix" cachyos chaotic-aur endeavouros "manjaro" rebornos)

# Convert all arguments to lowercase
args=("$@")
for (( i=0; i<${#args[@]}; i++ ));
do
    args[$i]=${args[$i],,}
done

# Use lowercase arguments for processing
repo=${args[0]}
second=${args[1]}

# Colors
NONE='\e[0m'
LRED='\e[1;31m'
LGREEN='\e[1;32m'
LBLUE='\e[1;34m'

# Help
if [[ "${args[0]}" == help ]] || [[ "${args[0]}" == --help ]] || [[ -z "${args[0]}" ]] || [[ ! "${repolist[*]}" =~ ${args[0]} ]]; then
    printf "%s""$LRED""No $LGREEN${args[0]}$LRED repo found! Available options are:""\n""%s""$LBLUE{${repolist[*]}} $LRED{remove}$NONE"
    exit 1
fi

# Temp file
MIRRORLIST_TEMP="$(mktemp)"

# ${args[0]}, ${args[1]}, ${args[2]}... stands for arguments, for example: ${args[0]} = first argument ${args[1]} = second argument ${args[2]} = third argument and so on
if [[ "${args[0]}" == arch ]] && [[ "${args[1]}" == remove ]] || [[  "${args[0]}" == archarm ]] && [[ "${args[1]}" == remove ]]; then
    printf "%s""$LRED""Can't delete arch repositories!""\n"
    exit 1
fi

if [[ "${args[0]}" == artix ]] && [[ ! "${args[1]}" == remove ]] || [[ "${args[0]}" == manjaro ]] && [[ ! "${args[1]}" == remove ]]; then
    printf "%s""$LRED""Artix and Manjaro repositories aren't supported yet!""\n"
    exit 1
fi

# Remove repo
if [[ "${args[1]}" == remove ]]; then
    # Check if repo is configured
    if grep -q "\[$repo]" "/etc/pacman.conf"; then
        # Remove repo
        sudo sed -i "/$repo/{N;d;}" /etc/pacman.conf
        sudo rm /etc/pacman.d/"$repo"-mirrorlist
        exit
    fi
    # If not configured
    printf "%s""$LRED""There is no $repo repo configured!""\n""Check /etc/pacman.conf to get configured repos"
    exit 1
fi

# Arm support
if [[ $arch == arm* ]] || [[ $arch = aarch64 ]]; then
    if [[ "${args[0]}" == arch ]]; then
        repo=archarm
    fi
fi


# Rate mirrors
printf "\n""%s""$LGREEN""Rating mirrors...""$NONE""\n"
if [ ! -x "$(command -v rate-mirrors)" ]; then
    printf "%s""$LRED""rate-mirrors is not installed!""$NONE"
    read -p "Do you want to install it? (Y/n) " choice
    if [ "$choice" = n ]; then
        exit 1
    else
        sudo pacman -S rate-mirrors
        printf "%s""$LGREEN""Done!""$NONE"
        printf "\n""%s""$LGREEN""Rating mirrors...""$NONE""\n"
    fi
fi
rate-mirrors --allow-root --save="$MIRRORLIST_TEMP" "$repo" > /dev/null

# Adapt to Reborn-OS naming (instead of rebornos.db they have Reborn-OS.db)
if [ "${args[0]}" == rebornos ]; then
    repo=Reborn-OS
fi

# Get mirrors from the rate-mirrors temp file
grep -qe "^Server = http" "$MIRRORLIST_TEMP" 

# Add mirrors to corresponding mirrorlist
if [[ "${args[0]}" == arch ]] || [[ "${args[0]}" == archarm ]]; then
    sudo install -m644 "$MIRRORLIST_TEMP" /etc/pacman.d/mirrorlist
else
    sudo install -m644 "$MIRRORLIST_TEMP" "/etc/pacman.d/$repo-mirrorlist"
    # Check if repo is configured and add if not
    if ! grep -q "\[$repo]" "/etc/pacman.conf"; then
        # Ask to trust without signature
        read -p "Do you want to trust mirrors without signature. This may fix some issues(Y/n) " choice
        if [ "$choice" = n ]; then
            printf "\n""%s""[$repo]""\nInclude = ""%s""/etc/pacman.d/$repo-mirrorlist" | sudo tee -a /etc/pacman.conf > /dev/null
        else
            printf "\n""%s""[$repo]""\nInclude = ""%s""/etc/pacman.d/$repo-mirrorlist""\nSigLevel = Optional TrustAll" | sudo tee -a /etc/pacman.conf > /dev/null
        fi
    fi
fi

# Update mirrors
printf "\n""%s""$LGREEN""Updating mirrors...""$NONE""\n"
sudo pacman -Syyu

# Remove temp file
rm "$MIRRORLIST_TEMP"

printf "%s""$LGREEN""Done!""$NONE"