#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# This file contains common utils to be used.
# ------------------------------------------------------------------------------

# Transform boolean numbers into text.
bool_to_text() {
    if [[ "$1" -eq "0" ]]; then
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
                "$1" "$2" 1>&2
            else
                echo -e "$2" 1>&2
            fi
        else
            echo -e "$1" 1>&2
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
    echo -e "${COLOR_INFO}[INFO] $1${COLOR_RESET}" >&2
}

# Success message.
print_success() {
    echo -e "${COLOR_SUCCESS}[SUCCESS] $1${COLOR_RESET}" >&2
}

# Warning message.
print_warning() {
    echo -e "${COLOR_WARNING}[WARNING] $1${COLOR_RESET}" >&2
}

# Error message.
print_error() {
    echo -e "${COLOR_ERROR}[ERROR] $1${COLOR_RESET}" >&2
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

# Convert a ConsumedEnergy string (e.g. "123.45K") to integer joules.
convert_to_joules() {
    # Strip whitespace
    local string=$(printf "%s" "$1" | tr -d ' ')

    # Catch empty lines.
    if [ -z "$string" ]; then
        echo "0"
        return
    fi

    # Separate numeric value and unit
    local num=$(printf "%s" "$string" | sed 's/[KMG]$//')
    local unit=$(printf "%s" "$string" | sed 's/^[0-9.]*//')

    # Choose multiplier based on unit
    case "$unit" in
        "")  mult=1 ;;
        K)   mult=1000 ;;
        M)   mult=1000000 ;;
        G)   mult=1000000000 ;;
        *)   echo "Unknown unit: $unit" >&2; return 1 ;;
    esac

    # Convert to integer joules.
    printf "%.0f" "$(echo "$num * $mult" | bc)"
}

# Convert integer joules into human readable unit (J, K, M, G).
convert_from_joules() {
    local joules="$1"

    if [ "$joules" -ge 1000000000 ]; then
        local unit="G"
        local divisor=1000000000
    elif [ "$joules" -ge 1000000 ]; then
        local unit="M"
        local divisor=1000000
    elif [ "$joules" -ge 1000 ]; then
        local unit="K"
        local divisor=1000
    else
        local unit=""
        local divisor=1
    fi

    local value=$(echo "scale=2; $joules / $divisor" | bc)
    printf "%s %sJ" "$value" "$unit"
}

# Check if the provided number is numerical.
is_numerical() {
    if [[ "$1" =~ ^[-+]?[0-9]*\.?[0-9]+$ ]]; then
        return 0
    else
        return 1
    fi
}
