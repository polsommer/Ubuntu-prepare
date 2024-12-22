#!/bin/bash

# Menu Function
function menu() {
    local prompt="$1" outvar="$2"
    shift
    shift
    local options=("$@") cur=0 count=${#options[@]} index=0
    local esc=$(echo -en "\e") # Cache ESC for handling arrow keys
    printf "$prompt\n"
    while true
    do
        # Display all options
        index=0
        for o in "${options[@]}"
        do
            if [ "$index" == "$cur" ]; then
                echo -e " >\e[7m$o\e[0m" # Highlight the current option
            else
                echo "  $o"
            fi
            index=$((index + 1))
        done

        read -s -n3 key # Wait for user input
        if [[ $key == $esc[A ]]; then # Up arrow
            cur=$((cur - 1))
            [ "$cur" -lt 0 ] && cur=0
        elif [[ $key == $esc[B ]]; then # Down arrow
            cur=$((cur + 1))
            [ "$cur" -ge $count ] && cur=$((count - 1))
        elif [[ $key == "" ]]; then # ENTER key
            break
        fi
        echo -en "\e[${count}A" # Move back up to re-render options
    done
    printf -v $outvar "${options[$cur]}"
}

# Define Options
selections=(
    "Single Server Install"
)

# Welcome Message
echo -e "\n####################"
echo -e "\nWelcome to the SWG Server Preparation Script!"
echo -e "\n####################\n"
echo -e "\nPlease choose your options carefully and refer to the GitHub guide.\n"

# Call Menu
menu "Choose Installation Option:" selected_choice "${selections[@]}"

# Process Selection
echo -e "\nSelected choice: $selected_choice\n"

if [ "$selected_choice" = "Single Server Install" ]; then
    bash ~/swg-prepare/single_server_install.sh
fi
