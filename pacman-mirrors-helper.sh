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
    if grep -q "\[$1\]" "/etc/pacman.conf"; then
        return 0    # Repo is configured, return success (0)
    else
        return 1    # Repo is not configured, return failure (1)
    fi
}

# Update mirrors
function update_mirrors {
    printf "\n%s" "$LGREEN" "Updating mirrors..." "$NONE" "\n"
    sudo pacman -Syyu
}

# Cleanup function for handling SIGINT (CTRL+C)
function cleanup {
    echo "Cleaning up and exiting gracefully..."
    if [[ -n "$MIRRORLIST_TEMP" ]]; then
        rm "$MIRRORLIST_TEMP"
    fi
    exit
}

# Trap SIGINT and call cleanup function
trap cleanup SIGINT

# Help function for printing available options
function print_available_options {
    printf "%s%s%s" "$LRED" "No $LGREEN$1$LRED repo found! Available options are:" "\n$LBLUE{${repolist[*]}} $LRED{remove}$NONE"
    exit 1
}

# Create temporary file for storing mirror list
MIRRORLIST_TEMP="$(mktemp)"

# Help
if [[ "${args[0]}" == help ]] || [[ "${args[0]}" == --help ]] || [[ -z "${args[0]}" ]] || [[ ! "${repolist[*]}" =~ ${args[0]} ]]; then
    print_available_options "$repo"
fi
# Check if trying to remove Arch or Arch ARM repositories (these cannot be removed)
if [[ "${args[0]}" == arch ]] && [[ "${args[1]}" == remove ]] || [[  "${args[0]}" == archarm ]] && [[ "${args[1]}" == remove ]]; then
    printf "%s""$LRED""Can't delete Arch repositories!""\n"
    exit 1
fi

# Check if trying to use Artix or Manjaro repositories (these are not yet supported)
if [[ "${args[0]}" == artix ]] && [[ ! "${args[1]}" == remove ]] || [[ "${args[0]}" == manjaro ]] && [[ ! "${args[1]}" == remove ]]; then
    printf "%s""$LRED""Artix and Manjaro repositories aren't supported yet!""\n"
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
    printf "%s""$LRED""There is no $repo repo configured!""\n""Check /etc/pacman.conf to see configured repos."
    exit 1
fi

# Arm support - if running on ARM architecture, use archarm repo
if [[ $arch == arm* ]] || [[ $arch = aarch64 ]]; then
    if [[ "${args[0]}" == arch ]]; then
        repo=archarm
    fi
fi

# Rate mirrors using rate-mirrors tool and save to temporary file
printf "\n""%s""$LGREEN""Rating mirrors...""$NONE""\n"
if [ ! -x "$(command -v rate-mirrors)" ]; then
    # Check if rate-mirrors tool is installed, if not, prompt to install it
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
    if check_repo_configured "$repo"; then
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

printf "%s""$LGREEN""Done!""$NONE"