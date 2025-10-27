# ------------------------------------------------------------------------------
# This file contains common utils to be used.
# ------------------------------------------------------------------------------

# Checks if the passed function exists.
function_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if the provided number is numerical.
#   Usage:  is_numerical <input>
is_numerical() {
    case "$1" in
        # Reject empty strings or invalid characters.
        *[!0-9.+-]* | '') return 1 ;;
        # March floats.
        *.*)
            # Valid patterns:
            #   [+|-]digits.digits
            #   [+|-]digits.
            #   [+|-].digits
            case "$1" in
                [+-]*[0-9]*.[0-9]*) return 0 ;;
                *) return 1 ;;
            esac
            ;;
        # Match ints.
        *)
            case "$1" in
                [+-]*[0-9]*) return 0 ;;
                *) return 1 ;;
            esac
            ;;
    esac
}

# Check if given string consists of only alphanumeric characters.
#   Usage:  is_alphanumerical <input>
is_alphanumerical() {
    case "$1" in
        # Reject empty strings or invalid characters.
        *[!A-Za-z0-9_\/]* | '') return 1 ;;
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
    local base
    local exp

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
