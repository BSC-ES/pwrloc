#!/usr/bin/env sh
# ------------------------------------------------------------------------------
# Utils functions related to printing.
# ------------------------------------------------------------------------------

# Color codes for print_*() functions.
COLOR_RESET='\033[0m'       # Reset to default color
COLOR_INFO='\033[1;34m'     # Blue
COLOR_SUCCESS='\033[1;32m'  # Green
COLOR_WARNING='\033[1;33m'  # Yellow
COLOR_ERROR='\033[1;31m'    # Red

# Info message.
print_info() {
    printf "%b[INFO] %s%b\n" "${COLOR_INFO}" "$1" "${COLOR_RESET}" >&2
}

# Success message.
print_success() {
    printf "%b[SUCCESS] %s%b\n" "${COLOR_SUCCESS}" "$1" "${COLOR_RESET}" >&2
}

# Warning message.
print_warning() {
    printf "%b[WARNING] %s%b\n" "${COLOR_WARNING}" "$1" "${COLOR_RESET}" >&2
}

# Error message.
print_error() {
    printf "%b[ERROR] %s%b\n" "${COLOR_ERROR}" "$1" "${COLOR_RESET}" >&2
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
                printf "%s\n" "$2" 1>&2
            fi
        else
            printf "%s\n" "$1" 1>&2
        fi
    fi
}

# Print the given string repeated in full terminal width or 80 characters.
print_full_width() {
    # Return if no character was provided.
    if [ $# -eq 0 ]; then
        return
    fi

    # Set width for printing.
    max_width=80
    term_width=$(tput cols 2>/dev/null || echo $max_width)
    [ "$term_width" -gt "$max_width" ] && term_width=$max_width

    # Print in terminal width.
    printf '%*s\n' "$term_width" '' | tr ' ' "$1"
}

# Print the given string centered in full terminal width or 80 characters.
print_centered() {
    # Return if no character was provided.
    if [ $# -eq 0 ]; then
        return
    fi

    max_width=80
    text=$1

    # Set width for printing.
    term_width=$(tput cols 2>/dev/null || echo "$max_width")
    [ "$term_width" -gt "$max_width" ] && term_width=$max_width

    # Get the length of the text.
    text_len=$(printf '%s' "$text" | wc -c)

    # Just print the text if longer than the terminal width.
    if [ "$text_len" -ge "$term_width" ]; then
        printf '%s\n' "$text"
        return
    fi

    # Compute the left padding: floor((term_width - text_len) / 2)
    padding=$(( term_width - text_len ))
    left_pad=$(( padding / 2 ))

    # Print left padding + text.
    printf '%*s%s\n' "$left_pad" '' "$text"
}

# Transform boolean numbers into text.
bool_to_text() {
    if [ "$1" -eq 0 ]; then
        printf "TRUE\n"
    else
        printf "FALSE\n"
    fi
}
