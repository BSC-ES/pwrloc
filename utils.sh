#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# This file contains common utils to be used.
# ------------------------------------------------------------------------------

# Transform boolean numbers into text.
bool_to_text() {
    if [ "$1" -eq "0" ]; then
        echo "TRUE"
    else
        echo "FALSE"
    fi
}

# Checks if the passed function exists.
function_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Only echo the passed string if VERBOSE is set. type "$1" 2
verbose_echo() {
    # Turn VERBOSE output off by default.
    [ -z "$VERBOSE" ] && VERBOSE=0

    # Print if VERBOSE is set.
    if [ "$VERBOSE" -eq 1 ]; then
        # If two arguments are passed, interpret first as pretty print option.
        if [ "$#" -eq 2 ]; then
            # Make sure the function exists, otherwise resort to a normal echo.
            if function_exists "$1"; then
                "$1" "$2"
            else
                echo -e "$2"
            fi
        else
            echo -e "$1"
        fi
    fi
}

# Color codes for print_*() functions.
COLOR_RESET='\033[0m'       # Reset to default color
COLOR_INFO='\033[1;34m'     # Blue
COLOR_SUCCESS='\033[1;32m'  # Green
COLOR_WARNING='\033[1;33m'  # Yellow
COLOR_ERROR='\033[1;31m'    # Red

# Info message.
print_info() {
    echo -e "${COLOR_INFO}[INFO] $1${COLOR_RESET}"
}

# Success message.
print_success() {
    echo -e "${COLOR_SUCCESS}[SUCCESS] $1${COLOR_RESET}"
}

# Warning message.
print_warning() {
    echo -e "${COLOR_WARNING}[WARNING] $1${COLOR_RESET}"
}

# Error message.
print_error() {
    echo -e "${COLOR_ERROR}[ERROR] $1${COLOR_RESET}"
}

# Print the given sequence repeated in full terminal width or 80 characters.
print_full_width() {
    # Return if no character was provided.
    if [ $# -eq 0 ]; then
        return
    fi

    # Set width for printing.
    local max_width=80
    local term_width=$(tput cols 2>/dev/null || echo $max_width)
    [ "$term_width" -gt "$max_width" ] && term_width=$max_width
    
    # Print in terminal width.
    printf '%*s\n' "$term_width" '' | tr ' ' "$1"
}
