#!/bin/bash

# Get the system architecture (e.g. x86_64, armv7l)
arch=$(uname -m)

# List of repository names to choose from
repolist=(arch archarm archlinuxcn "artix" cachyos chaotic-aur endeavouros "manjaro" rebornos)

# Convert all arguments to lowercase
args=("$@")
for (( i=0; i<${#args[@]}; i++ ));
do
    args[$i]=${args[$i],,}
done

# Use lowercase arguments for processing
repo=${args[0]}

# ANSI color codes for output
NONE='\e[0m'
LRED='\e[1;31m'
LGREEN='\e[1;32m'
LBLUE='\e[1;34m'

# Check if repo is configured in /etc/pacman.conf
function check_repo_configured {
    if grep -qF "\[$1\]" "/etc/pacman.conf"; then
        return 1    # Repo is configured, return true (1)
    else
        return 0    # Repo is not configured, return false (0)
    fi
}

# Update mirrors
function update_mirrors {
    printf "\n""$LGREEN""Updating mirrors...""$NONE""\n"
    sudo pacman -Syyu
}

# Cleanup function for handling SIGINT (CTRL+C)
function cleanup {
    printf "\n""$LGREEN""Cleaning up and exiting gracefully...""$NONE""\n"
    if [[ -n "$MIRRORLIST_TEMP" ]]; then
        rm "$MIRRORLIST_TEMP"
    fi
    exit
}

# Help function for printing usage
function print_usage {
    printf "${LGREEN}Usage:${NONE} {${LBLUE}repo${NONE}} ${LGREEN}[remove]${NONE} - add or remove mirrorlist for a given repository

If ${LGREEN}'remove'${NONE} is specified, the specified repo and its mirrorlist will be removed from ${LGREEN}pacman.conf${NONE} and ${LGREEN}/etc/pacman.d${NONE}.

Available repos: ${LBLUE}${repolist[*]}${NONE}

Examples:
- ${LBLUE}arch${NONE}         # update Arch mirrors
- ${LBLUE}cachyos${NONE}      # add/update CachyOS mirrors
- ${LBLUE}endeavouros${NONE}   # add/update Endeavouros mirrors
- ${LBLUE}chaotic-aur remove${NONE}      # remove Chaotic-AUR mirrors from ${LGREEN}pacman.conf${NONE} and ${LGREEN}/etc/pacman.d/chaotic-aur-mirrors${NONE}

"

    exit 0
}

# Trap SIGINT and call cleanup function
trap cleanup SIGINT

# Create temporary file for storing mirror list
MIRRORLIST_TEMP="$(mktemp)"

# Help
if [[ "${args[0]}" == help ]] || [[ "${args[0]}" == --help ]] || [[ -z "${args[0]}" ]] || [[ ! "${repolist[*]}" =~ ${args[0]} ]]; then
    print_usage "$repo"
fi
# Check if trying to remove Arch or Arch ARM repositories (these cannot be removed)
if [[ "${args[0]}" == arch ]] && [[ "${args[1]}" == remove ]] || [[  "${args[0]}" == archarm ]] && [[ "${args[1]}" == remove ]]; then
    printf "$LRED""Can't delete Arch repositories!""\n"
    exit 1
fi

# Check if trying to use Artix or Manjaro repositories (these are not yet supported)
if [[ "${args[0]}" == artix ]] && [[ ! "${args[1]}" == remove ]] || [[ "${args[0]}" == manjaro ]] && [[ ! "${args[1]}" == remove ]]; then
    printf "$LRED""Artix and Manjaro repositories aren't supported yet!""\n"
    exit 1
fi

# Remove a repo
if [[ "${args[1]}" == remove ]]; then
    # Check if repo is configured
    if check_repo_configured "$repo"; then
        # Remove repo section from pacman.conf
        sudo sed -i "/$repo/{N;d;}" /etc/pacman.conf
        # Remove corresponding mirror list file
        sudo rm /etc/pacman.d/"$repo"-mirrorlist
        exit
    fi
    # If not configured, show error message and exit
    printf "$LRED""There is no $repo repo configured!""\n""Check /etc/pacman.conf to see configured repos."
    exit 1
fi

# Arm support - if running on ARM architecture, use archarm repo
if [[ $arch == arm* ]] || [[ $arch = aarch64 ]]; then
    if [[ "${args[0]}" == arch ]]; then
        repo=archarm
    fi
fi

# Rate mirrors using rate-mirrors tool and save to temporary file
printf "\n""$LGREEN""Rating mirrors...""$NONE""\n"
if [ ! -x "$(command -v rate-mirrors)" ]; then
    # Check if rate-mirrors tool is installed, if not, prompt to install it
    printf "$LRED""rate-mirrors is not installed!""$NONE""\n"
    printf "$LBLUE""Do you want to install it? (Y/n) "
    read choice
    if [ "$choice" = n ]; then
        exit 1
    else
        sudo pacman -S rate-mirrors
        printf "$LGREEN""Done!""$NONE"
        printf "\n""$LGREEN""Rating mirrors...""$NONE""\n"
    fi
fi
# Use --allow-root to support running as root (e.g. via sudo)
rate-mirrors --allow-root --save="$MIRRORLIST_TEMP" "$repo" > /dev/null

# Adapt to Reborn-OS naming (instead of rebornos.db they have Reborn-OS.db)
if [ "${args[0]}" == rebornos ]; then
    repo=Reborn-OS
fi

# Check if the temp file contains any mirrors, and add them to the corresponding mirrorlist
grep -qe "^Server = http" "$MIRRORLIST_TEMP" 
if [[ "${args[0]}" == arch ]] || [[ "${args[0]}" == archarm ]]; then
    # Add mirrors to Arch mirrorlist
    sudo install -m644 "$MIRRORLIST_TEMP" /etc/pacman.d/mirrorlist
else
    # Add mirrors to repo-specific mirrorlist
    sudo install -m644 "$MIRRORLIST_TEMP" "/etc/pacman.d/$repo-mirrorlist"
    # Check if repo is configured, and if not, ask to trust mirrors without signature
    if check_repo_configured "$repo" == 0; then
        read -p "Do you want to trust mirrors without signature? This may fix some issues. (Y/n) " choice
        if [ "$choice" = n ]; then
            printf "\n""%s""[$repo]""\nInclude = ""%s""/etc/pacman.d/$repo-mirrorlist" | sudo tee -a /etc/pacman.conf > /dev/null
        else
            printf "\n""%s""[$repo]""\nInclude = ""%s""/etc/pacman.d/$repo-mirrorlist""\nSigLevel = Optional TrustAll" | sudo tee -a /etc/pacman.conf > /dev/null
        fi
    fi
fi

# Update mirrors after adding new ones
update_mirrors

# Remove temporary file
rm "$MIRRORLIST_TEMP"

printf "$LGREEN""Done!""$NONE"