# ------------------------------------------------------------------------------
# An POSIX compliant array implementation that allows for a minimal set of
# operations.
# ------------------------------------------------------------------------------

# Get the directory where this file is located to load dependencies.
UTILSDIR="$BASEDIR/utils"
. "$UTILSDIR/print_utils.sh"

ARRAY_PREFIX="__array__"

# Check if a given array already exists.
#   Usage:  array_exists <array_name>
array_exists() {
    # Sanitize input.
    if [ -z "$1" ]; then
        print_error "<array_exists> No array name passed."
        return 1
    elif ! is_alphanumerical "$1"; then
        print_error "<array_exists> Array name is not alphanumerical."
        return 1
    fi

    # Check if the array has a length variable.
    eval "val=\${${ARRAY_PREFIX}${1}_len+set}"
    [ "${val}" = "set" ]
}

# Sets an array value.
#   Usage:    array_create <array_name>
array_create() {
    # Sanitize input.
    if [ -z "$1" ]; then
        print_error "<array_create> No array name passed."
        return 1
    elif ! is_alphanumerical "$1"; then
        print_error "<array_create> Array name is not alphanumerical."
        return 1
    fi

    # Make sure array does not exist yet.
    if array_exists "$1"; then
        print_warning "<array_create> Array already exists, ignoring.."
        return 1
    fi

    # Set length variable to indicate existence.
    eval "${ARRAY_PREFIX}$1_len=0"
}

# Push an array value.
#   Usage:    array_push <array_name> <value>
array_push() {
    # Sanitize input.
    if [ -z "$1" ]; then
        print_error "<array_push> No array name passed."
        return 1
    elif ! is_alphanumerical "$1"; then
        print_error "<array_push> Array name is not alphanumerical."
        return 1
    elif [ -z "$2" ]; then
        print_error "<array_push> No value passed."
        return 1
    elif ! is_alphanumerical "$2"; then
        print_error "<array_push> Value is not alphanumerical."
        return 1
    fi

    # Push the value on len+1.
    eval "i=\${${ARRAY_PREFIX}$1_len}"
    eval "${ARRAY_PREFIX}$1_$i=\$2"
    eval "${ARRAY_PREFIX}$1_len=\$((i + 1))"
}

# Gets an array value.
#   Usage:    array_get <array_name> <index>
array_get() {
    # Sanitize input.
    if [ -z "$1" ]; then
        print_error "<array_get> No array name passed."
        return 1
    elif ! is_alphanumerical "$1"; then
        print_error "<array_get> Value is not alphanumerical."
        return 1
    elif [ -z "$2" ]; then
        print_error "<array_get> No index passed."
        return 1
    elif ! is_numerical "$2"; then
        print_error "<array_get> Index is not numerical."
        return 1
    fi

    # Print array value at given index.
    eval "printf '%s\\n' \${${ARRAY_PREFIX}$1_$2}"
}

# Get the length of an array.
#   Usage:  array_len <array_name>
array_len() {
    # Sanitize input.
    if [ -z "$1" ]; then
        print_error "<array_len> No array name passed."
        return 1
    elif ! is_alphanumerical "$1"; then
        print_error "<array_len> Array name is not alphanumerical."
        return 1
    fi

    # Print length of array.
    eval "printf '%s\\n' \${${ARRAY_PREFIX}$1_len}"
}

# Deletes an array value.
#   Usage:    array_delete <array_name> <index>
array_delete() {
    # Sanitize input.
    if [ -z "$1" ]; then
        print_error "<array_delete> No array name passed."
        return 1
    elif ! is_alphanumerical "$1"; then
        print_error "<array_delete> Array name is not alphanumerical."
        return 1
    elif [ -z "$2" ]; then
        print_error "<array_delete> No index passed."
        return 1
    elif ! is_numerical "$2"; then
        print_error "<array_delete> Index is not numerical."
        return 1
    fi

    # Get current length and index for checks.
    local len idx i j val
    eval "len=\${${ARRAY_PREFIX}$1_len}"
    idx=$2

    # Bounds check.
    if [ "$idx" -lt 0 ] || [ "$idx" -ge "$len" ]; then
        print_error "<array_delete> Index out of range"
        return 1
    fi

    # Shift all elements left from idx+1.
    i=$idx
    while [ "$i" -lt $((len - 1)) ]; do
        j=$((i + 1))
        eval "val=\${${ARRAY_PREFIX}$1_\$j}"
        eval "${ARRAY_PREFIX}$1_$i=\"\$val\""
        i=$((i + 1))
    done

    # Unset last element.
    eval "unset ${ARRAY_PREFIX}$1_$((len - 1))"

    # Update length.
    eval "${ARRAY_PREFIX}$1_len=\$((len - 1))"
}

# Iterate over all elements and execute given command.
#   Usage:    array_foreach <array_name> <command>
array_foreach() {
    # Sanitize input.
    if [ -z "$1" ]; then
        print_error "<array_foreach> No array name passed."
        return 1
    elif ! is_alphanumerical "$1"; then
        print_error "<array_foreach> Array name is not alphanumerical."
        return 1
    elif [ -z "$2" ]; then
        print_error "<array_foreach> No command passed."
        return 1
    elif ! is_alphanumerical "$2"; then
        print_error "<array_foreach> Command is not alphanumerical."
        return 1
    fi

    # Get array length and loop over items.
    eval "len=\${${ARRAY_PREFIX}$1_len}"
    i=0
    while [ "$i" -lt "$len" ]; do
        eval "val=\${${ARRAY_PREFIX}$1_$i}"
        eval "$2 \"\$val\""
        i=$((i + 1))
    done
}
