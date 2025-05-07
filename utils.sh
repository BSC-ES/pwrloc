#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# This file contains common utils to be used.
# ------------------------------------------------------------------------------

# Checks if the passed function exists.
function_exists() {
    type "$1" 2>/dev/null | grep -q 'function'
}

# Default VERBOSE value for verbose_echo() function.
VERBOSE=0

# Only echo the passed string if VERBOSE is set.
verbose_echo() {
    if [ "$VERBOSE" -eq 1 ]; then
        # If two arguments are passed, interpret first as pretty print option.
        if [ "$#" -eq 2 ]; then
            # Make sure the function exists, otherwise resort to a normal echo.
            if function_exists "$1"; then
                "$1" "$2"
            else
                echo "$2"
            fi
        else
            echo "$1"
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
