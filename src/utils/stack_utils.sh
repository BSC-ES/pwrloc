#!/usr/bin/env sh
# ------------------------------------------------------------------------------
# A POSIX compliant stack implementation that allows for a minimal set of
# operations. All stacks are indexed from 0.
# All user input is limited to being "alphanumerical" to (relatively) safely use
# eval expressions.
#
# Syntax:
#   - Check stack existence:        stack_exists <stack_name>
#   - Create stack:                 stack_create <stack_name>
#   - Get stack length:             stack_len <stack_name>
#   - Add value to top:             stack_push <stack_name> <value>
#   - Delete and return top value:  stack_pop <stack_name>
#   - Delete stack value:           stack_delete <stack_name> <index>
#   - Foreach over values:          stack_foreach <stack_name> <command>
#   - Destroy entire stack:         stack_destory <stack_name>
# ------------------------------------------------------------------------------

# Get the directory where this file is located to load dependencies.
UTILSDIR="$SRCDIR/utils"
. "$UTILSDIR/print_utils.sh"

# Prefix for internal variables to ensure uniqueness.
STACK_PREFIX="__stack__"

# Check if a given stack already exists.
#   Usage:  stack_exists <stack_name>
stack_exists() {
    # Sanitize input.
    if [ -z "$1" ]; then
        print_error "<stack_exists> No stack name passed."
        return 1
    elif ! is_alphanumerical "$1"; then
        print_error "<stack_exists> Stack name is not alphanumerical."
        return 1
    fi

    # Check if the stack has a length variable, clean up, and return.
    eval "_check_stack_exists=\${$STACK_PREFIX${1}_len+set}"
    if [ "$_check_stack_exists" = "set" ]; then
        unset _check_stack_exists
        return 0
    else
        unset _check_stack_exists
        return 1
    fi
}

# Creates an empty stack.
#   Usage:    stack_create <stack_name>
stack_create() {
    # Sanitize input.
    if [ -z "$1" ]; then
        print_error "<stack_create> No stack name passed."
        return 1
    elif ! is_alphanumerical "$1"; then
        print_error "<stack_create> Stack name is not alphanumerical."
        return 1
    fi

    # Make sure stack does not exist yet.
    if stack_exists "$1"; then
        print_warning "<stack_create> Stack already exists, ignoring.."
        return 1
    fi

    # Set length variable to indicate existence.
    eval "$STACK_PREFIX${1}_len=0"
}

# Get the length of a stack.
#   Usage:  stack_len <stack_name>
stack_len() {
    # Sanitize input.
    if [ -z "$1" ]; then
        print_error "<stack_len> No stack name passed."
        return 1
    elif ! is_alphanumerical "$1"; then
        print_error "<stack_len> Stack name is not alphanumerical."
        return 1
    fi

    # Print length of stack.
    eval "printf '%s\\n' \${$STACK_PREFIX${1}_len}"
}

# Push a value to the top of the stack.
#   Usage:    stack_push <stack_name> <value>
stack_push() {
    # Sanitize input.
    if [ -z "$1" ]; then
        print_error "<stack_push> No stack name passed."
        return 1
    elif ! is_alphanumerical "$1"; then
        print_error "<stack_push> Stack name is not alphanumerical."
        return 1
    elif [ -z "$2" ]; then
        print_error "<stack_push> No value passed."
        return 1
    elif ! is_alphanumerical "$2"; then
        print_error "<stack_push> Value is not alphanumerical."
        return 1
    fi

    # Push the value on len+1.
    eval "_i_stack_push=\${$STACK_PREFIX${1}_len}"
    eval "$STACK_PREFIX${1}_$_i_stack_push=\$2"
    eval "$STACK_PREFIX${1}_len=\$((_i_stack_push + 1))"

    # Clean up.
    unset _i_stack_push
}

# Deletes and returns the top stack value.
#   Usage:    stack_pop <stack_name>
stack_pop() {
    # Sanitize input.
    if [ -z "$1" ]; then
        print_error "<stack_push> No stack name passed."
        return 1
    elif ! is_alphanumerical "$1"; then
        print_error "<stack_push> Stack name is not alphanumerical."
        return 1
    fi

    # Get and return top element.
    eval "_i_stack_pop=\$((\${$STACK_PREFIX${1}_len} - 1))"
    eval "_val_stack_pop=\${$STACK_PREFIX${1}_$_i_stack_pop}"
    printf "%s\n" "$_val_stack_pop"

    # Remove the top element.
    eval "$STACK_PREFIX${1}_len=$_i_stack_pop"
    eval "unset $STACK_PREFIX${1}_$_i_stack_pop"

    # Clean up.
    unset _i_stack_pop _val_stack_pop
}

# Gets the stack value at the provided index.
#   Usage:    stack_get <stack_name> <index>
stack_get() {
    # Sanitize input.
    if [ -z "$1" ]; then
        print_error "<stack_get> No stack name passed."
        return 1
    elif ! is_alphanumerical "$1"; then
        print_error "<stack_get> Value is not alphanumerical."
        return 1
    elif [ -z "$2" ]; then
        print_error "<stack_get> No index passed."
        return 1
    elif ! is_numerical "$2"; then
        print_error "<stack_get> Index is not numerical."
        return 1
    fi

    # Print stack value at given index.
    eval "printf '%s\\n' \${$STACK_PREFIX${1}_$2}"
}

# Deletes a stack value at the given index.
#   Usage:    stack_delete <stack_name> <index>
stack_delete() {
    # Sanitize input.
    if [ -z "$1" ]; then
        print_error "<stack_delete> No stack name passed."
        return 1
    elif ! is_alphanumerical "$1"; then
        print_error "<stack_delete> Stack name is not alphanumerical."
        return 1
    elif [ -z "$2" ]; then
        print_error "<stack_delete> No index passed."
        return 1
    elif ! is_numerical "$2"; then
        print_error "<stack_delete> Index is not numerical."
        return 1
    fi

    # Get current length and index for checks.
    eval "_len_stack_delete=\${${STACK_PREFIX}${1}_len}"
    _idx_stack_delete=$2

    # Bounds check.
    if [ "$_idx_stack_delete" -lt 0 ] || \
       [ "$_idx_stack_delete" -ge "$_len_stack_delete" ]; then
        print_error "<stack_delete> Index out of range"
        return 1
    fi

    # Shift all elements 1 index to the left from idx+1.
    _i_stack_delete=$_idx_stack_delete
    while [ "$_i_stack_delete" -lt $((_len_stack_delete - 1)) ]; do
        _j_stack_delete=$((_i_stack_delete + 1))
        eval "_val_stack_delete=\${$STACK_PREFIX${1}_\$_j_stack_delete}"
        eval "$STACK_PREFIX${1}_$_i_stack_delete=\"\$_val_stack_delete\""
        _i_stack_delete=$((_i_stack_delete + 1))
    done

    # Unset last element.
    eval "unset $STACK_PREFIX${1}_$((_len_stack_delete - 1))"

    # Update length.
    eval "$STACK_PREFIX${1}_len=\$((_len_stack_delete - 1))"

    # Clean up.
    unset _len_stack_delete _idx_stack_delete _i_stack_delete _j_stack_delete \
        _val_stack_delete
}

# Iterate over all stack elements and execute given command.
#   Usage:    stack_foreach <stack_name> <command>
stack_foreach() {
    # Sanitize input.
    if [ -z "$1" ]; then
        print_error "<stack_foreach> No stack name passed."
        return 1
    elif ! is_alphanumerical "$1"; then
        print_error "<stack_foreach> Stack name is not alphanumerical."
        return 1
    elif [ -z "$2" ]; then
        print_error "<stack_foreach> No command passed."
        return 1
    elif ! is_alphanumerical "$2"; then
        print_error "<stack_foreach> Command is not alphanumerical."
        return 1
    fi

    # Get stack length and loop over items.
    eval "_len_stack_foreach=\${${STACK_PREFIX}${1}_len}"
    _i_stack_foreach=0
    while [ "$_i_stack_foreach" -lt "$_len_stack_foreach" ]; do
        eval "val=\${$STACK_PREFIX$1_$_i_stack_foreach}"
        eval "$2 \"\$val\""
        _i_stack_foreach=$((_i_stack_foreach + 1))
    done
    unset _len_stack_foreach _i_stack_foreach val
}

# Destroy and clean up an entire stack.
#   Usage:      stack_destory <stack_name>
stack_destroy() {
    printf "NOT IMPLEMENTED.\n"
}
