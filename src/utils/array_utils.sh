#!/usr/bin/env sh
# ------------------------------------------------------------------------------
# A POSIX compliant array implementation that allows for a minimal set of
# operations. Arrays are indexed from 0 and are represented as newline-separated
# strings. Thus creating a new array is simply creating an empty string. Note
# that elements of the array cannot be only whitespace (e.g. space, tab,
# newline).
#
# Syntax:
#   - Get array length:             array_len <array>
#   - Add value to top:             array_push <array> <value>
#   - Delete and export top value:  array_pop <array>
#   - Get last value:               array_get_last <array>
#   - Get the value at a index:     array_get <array> <index>
#   - Set the value at a index:     array_set <array> <index> <new_value>
#   - Delete array value:           array_delete <array> <index>
#   - Foreach over values:          array_foreach <array> <command>
# ------------------------------------------------------------------------------

# Get the directory where this file is located to load dependencies.
UTILSDIR="$SRCDIR/utils"
. "$UTILSDIR/print_utils.sh"


# Get the length of a array.
#   Usage:  array_len <array>
array_len() {
    # Sanitize input.
    if [ -z "$1" ]; then
        print_error "<array_len> No array passed."
        return 1
    fi

    # Get number of elements by separating string using RS='\n'.
    printf '%s' "$1" | awk 'length($0) > 0 { n++ } END { print n+0 }'
}

# Push a value to the top of the array.
#   Usage:    array_push <array> <value>
array_push() {
    # Sanitize input.
    if [ -z "$2" ]; then
        print_error "<array_push> No value passed."
        return 1
    elif is_whitespace "$2"; then
        print_warning "<array_push> Value is empty! Ignoring.."
        return 1
    fi

    # Strip input from whitespaces, tabs, and newlines.
    clean_str=$(strip_whitespace "$2")

    # Push the value to the string and print.
    # Ignore the given string if it's empty.
    if [ -n "$1" ]; then
        printf '%s\n%s' "$1" "$clean_str"
    else
        printf '%s' "$clean_str"
    fi
}

# Deletes the last array value and pritns the remaining array.
#   Usage:    array_pop <array>
array_pop() {
    # Sanitize input.
    if [ -z "$1" ]; then
        print_error "<array_pop> No array passed."
        return 1
    fi

    # Get and remove the last element.
    printf '%s' "$1" | awk '
        {
            # Print previous line if not empty.
            if (length(prev) > 0) print prev
            # Store current line as previous.
            prev = $0
        }
        END {
            # do not print the last non-empty line, which is what we remove.
        }
    '
}

# Gets the last array value.
#   Usage:    array_get_last <array>
array_get_last() {
    # Sanitize input.
    if [ -z "$1" ]; then
        print_error "<array_get> No array passed."
        return 1
    fi

    # Print only last element.
    printf '%s\n' "$1" | awk '
        length($0) { last = $0 }
        END { if (length(last)) print last }
    '
}

# Gets the array value at the provided index.
#   Usage:    array_get <array> <index>
array_get() {
    # Sanitize input.
    if [ -z "$1" ]; then
        print_error "<array_get> No array passed."
        return 1
    elif [ -z "$2" ]; then
        print_error "<array_get> No index passed."
        return 1
    elif ! is_numerical "$2"; then
        print_error "<array_get> Index is not numerical."
        return 1
    fi

    # Convert the 0-based index to 1-based.
    idx=$(( $2 + 1 ))

    # Print only the requested line.
    printf '%s\n' "$1" | awk -v idx="$idx" '
        NR == idx {
            print
            exit
        }
    '
}

# Sets the array value at the provided index.
#   Usage:    array_set <array> <index> <new_value>
array_set() {
    # Sanitize input.
    if [ -z "$1" ]; then
        print_error "<array_set> No array passed."
        return 1
    elif [ -z "$2" ]; then
        print_error "<array_set> No index passed."
        return 1
    elif ! is_numerical "$2"; then
        print_error "<array_set> Index is not numerical."
        return 1
    elif [ -z "$3" ]; then
        print_error "<array_set> No new value passed."
        return 1
    elif is_whitespace "$3"; then
        print_warning "<array_set> New value is empty! Ignoring.."
        return 1
    fi

    # Convert the 0-based index to 1-based.
    idx=$(( $2 + 1 ))

    # Rebuild the string, replacing the idx-th line
    printf '%s\n' "$1" | awk -v idx="$idx" -v val="$3" '
        # Replace the value at the given index.
        NR == idx {
            print val
            next
        }
        # Print the element normally otherwise.
        { print }
    '
}

# Deletes a array value at the given index.
#   Usage:    array_delete <array> <index>
array_delete() {
    # Sanitize input.
    if [ -z "$1" ]; then
        print_error "<array_delete> No array passed."
        return 1
    elif [ -z "$2" ]; then
        print_error "<array_delete> No index passed."
        return 1
    elif ! is_numerical "$2"; then
        print_error "<array_delete> Index is not numerical."
        return 1
    fi

    # Convert the 0-based index to 1-based.
    idx=$(( $2 + 1 ))

    # Rebuild the string, replacing the idx-th line
    printf '%s\n' "$1" | awk -v idx="$idx" '
        # Print everything except the value at the given index.
        NR != idx { print }
    '
}

# Iterate over all array elements and execute given command.
#   Usage:    array_foreach <array> <command>
array_foreach() {
    # Sanitize input.
    if [ -z "$1" ]; then
        print_error "<array_foreach> No array passed."
        return 1
    elif [ -z "$2" ]; then
        print_error "<array_foreach> No command passed."
        return 1
    fi

    printf '%s\n' "$1" | while IFS= read -r line; do
        # Call the provided function with the line as argument
        "$2" "$line"
    done
}
