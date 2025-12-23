#!/usr/bin/env sh
# ------------------------------------------------------------------------------
# This file contains common utils to be used.
# ------------------------------------------------------------------------------

# Checks if the passed function exists.
function_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if the provided string only contains whitespaces, tabs, or newlines.
#   Usage:  is_whitespace <input>
is_whitespace() {
    printf '%s' "$1" | awk '
        /[^[:space:]]/ { found = 1 }
        END { exit found ? 1 : 0 }
    '
}

# Strip whitespaces, tabs, or newlines from the input string.
#   Usage:  strip_whitespace <input>
strip_whitespace() {
    printf '%s' "$1" | awk '
    {
        if (length($0)) {
            if (length(prev)) print prev
            prev = $0
        } else {
            if (length(prev)) print prev
            prev = ""
        }
    }
    END {
        if (length(prev)) print prev
    }'
}

# Check if the provided number is numerical.
#   Usage:  is_numerical <input>
is_numerical() {
    case "$1" in
        # Reject empty strings or invalid characters.
        *[!0-9.+-]* | '') return 1 ;;
        # Match floats.
        *.*)
            # Parse unsigned floats.
            case "$1" in
                [0-9]*.[0-9]*) return 0 ;;
            esac

            # Parse signed floats.
            case "$1" in
                [+-]*[0-9]*.[0-9]*) return 0 ;;
            esac

            # Default behavior when there are no matches.
            return 1
            ;;
        # Match ints.
        *)
            case "$1" in
                [+-][0-9]* | [0-9]*) return 0 ;;
                *) return 1 ;;
            esac
            ;;
    esac
}

# Check if given string consists of only alphanumeric characters, including:
# '_', and '/'.
#   Usage:  is_alphanumerical <input>
is_alphanumerical() {
    case "$1" in
        # Reject characters not in whitelist and empty strings.
        *[!A-Za-z0-9_/:=\ \'%\\-]* | '') return 1 ;;
        *) return 0 ;;
    esac
}

# Check if the provided number is in scientific format.
# Standard scientific notation: [±]num[.num][eE][±]exp
is_scientific() {
    case $1 in
        # Return on empty string.
        "") return 1 ;;
        # Parse argument.
        *)
            printf "%s\n" "$1" | grep -Eq '^[+-]?[0-9]+([.][0-9]*)?([eE][+-]?[0-9]+)?$' \
                && return 0
            printf "%s\n" "$1" | grep -Eq '^[0-9.]+\^-?[0-9]+$' \
                && return 0
            return 1
            ;;
    esac
}

# Get the base and exponent of a scientific notation.
split_scientific_notation() {
    # Get and return base and exponent.
    case $1 in
        # Detect caret-style notation.
        *^*)
            expr "$1" : '\([0-9.][0-9.]*\)\^\(-\{0,1\}[0-9][0-9]*\)$' >/dev/null || return 1
            base=$(expr "$1" : '\([0-9.][0-9.]*\)\^')
            exp=$(expr "$1" : '[0-9.][0-9.]*\^\(-\{0,1\}[0-9][0-9]*\)')
            printf "%s\n" "$base"
            printf "%s\n" "$exp"
            return 0
            ;;
        # Detect exponent-style notation.
        *[eE]*)
            expr "$1" : '^[+-]*[0-9.][0-9.]*[eE][+-]*[0-9][0-9]*$' >/dev/null 2>&1 || return 1
            base=$(expr "$1" : '\([+-]*[0-9.][0-9.]*\)[eE]')
            exp=$(expr "$1" : '.*[eE]\([+-]*[0-9][0-9]*\)$')
            printf "%s\n" "$base"
            printf "%s\n" "$exp"
            return 0
            ;;
        # If no caret or exponent notation, simply return false.
        *)
            return 1
            ;;
    esac
}

# Zip the items of two newline-separated strings which are of the same length.
#   Usage:      zip_strings <list_1> <list_2>
zip_strings() {
    tmp1=$(mktemp)
    tmp2=$(mktemp)
    printf '%s\n' "$1" > "$tmp1"
    printf '%s\n' "$2" > "$tmp2"
    paste -d ' ' "$tmp1" "$tmp2"
    rm -f "$tmp1" "$tmp2"
}

# Find the longest element from newline-separated string.
#   Usage:      get_max_len <input>
get_max_len() {
    string="$1"
    max_len=0
    while IFS= read -r element; do
        len=$(printf '%s' "$element" | wc -c)
        [ "$len" -gt "$max_len" ] && max_len=$len
    done <<EOF
$string
EOF
    printf "%s\n" "$max_len"
}
