#!/usr/bin/env sh
# ------------------------------------------------------------------------------
# Unit tests for the stack functionality inside utils.
#   NOTE: All tests' names should start with "test_".
# ------------------------------------------------------------------------------

. "$SRCDIR/utils/stack_utils.sh"


# Setup function to be used for setting up a stack uniformly after the internal
# functions have been verified separately.
#   Usage:      _setup_test_stack <stack_name>
_setup_test_stack() {
    # Setup stack.
    stack_create "$1"
    stack_push "$1" "val0"
    stack_push "$1" "val1"
    stack_push "$1" "val2"

    # Make sure the starting length is correct.
    if [ "$(stack_len "$1")" -ne 3 ]; then
        printf "<_setup_test_stack> Created stack does not have length 3.\n" >&2
        return 1
    fi
}


# Test stack_exist and stack_create.
test_stack_creation() {
    # Test if stack_exists correctly detects non-existing stacks.
    if stack_exists "stack"; then
        printf "Stack exists without being created.\n" >&2
        return 1
    fi

    # Test if stack_create works without errors.
    stack_create "stack"

    # Test if stack_exists correctly detects existing stacks.
    if ! stack_exists "stack"; then
        printf "Created stack does not exist.\n" >&2
        return 1
    fi
}

# Test stack_len.
test_stack_len() {
    stack_create "stack"
    if [ "$(stack_len "stack")" -ne 0 ]; then
        printf "Newly created stack does not have length 0.\n" >&2
        return 1
    fi
}

# Test stack_push.
test_stack_push() {
    # Check correctness of initialized stack.
    stack_create "stack"
    if [ "$(stack_len "stack")" -ne 0 ]; then
        printf "Newly created stack does not have length 0.\n" >&2
        return 1
    fi

    # Check stack length after two pushes.
    stack_push "stack" "val0"
    if [ "$(stack_len "stack")" -ne 1 ]; then
        printf "Pushing a value does not increase stack length to 1.\n" >&2
        return 1
    fi
    stack_push "stack" "val1"
    if [ "$(stack_len "stack")" -ne 2 ]; then
        printf "Pushing a value does not increase stack length to 2.\n" >&2
        return 1
    fi
}

# Test stack_pop.
test_stack_pop() {
    # Setup default stack.
    _setup_test_stack "stack"

    # Check for first pop.
    stack_pop "stack"
    top_val=$STACK_POP_RESULT
    if [ "$top_val" != "val2" ]; then
        printf "Top value incorrect: '%s' != val2.\n" "$top_val" >&2
        return 1
    elif [ "$(stack_len "stack")" -ne 2 ]; then
        printf "Stack length is incorrect after first pop: '%s' != 2.\n" \
            "$(stack_len "stack")" >&2
        return 1
    fi

    # Check for second pop.
    stack_pop "stack"
    top_val=$STACK_POP_RESULT
    if [ "$top_val" != "val1" ]; then
        printf "Top value incorrect: '%s' != val1.\n" "$top_val" >&2
        return 1
    elif [ "$(stack_len "stack")" -ne 1 ]; then
        printf "Stack length is incorrect after second pop: '%s' != 1.\n" \
            "$(stack_len "stack")" >&2
        return 1
    fi

    # Check for third pop.
    stack_pop "stack"
    top_val=$STACK_POP_RESULT
    if [ "$top_val" != "val0" ]; then
        printf "Top value incorrect: '%s' != val0.\n" "$top_val" >&2
        return 1
    elif [ "$(stack_len "stack")" -ne 0 ]; then
        printf "Stack length is incorrect after third pop: '%s' != 0.\n" \
            "$(stack_len "stack")" >&2
        return 1
    fi
}

# Test stack_get.
test_stack_get() {
    # Setup default stack.
    _setup_test_stack "stack"

    # Check for the first value.
    val=$(stack_get "stack" "0")
    if [ "$val" != "val0" ]; then
        printf "The first value is incorrect: '%s' != val0.\n" "$val" >&2
        return 1
    fi

    # Check for the second value.
    val=$(stack_get "stack" "1")
    if [ "$val" != "val1" ]; then
        printf "The second value is incorrect: '%s' != val1.\n" "$val" >&2
        return 1
    fi

    # Check for the third value.
    val=$(stack_get "stack" "2")
    if [ "$val" != "val2" ]; then
        printf "The third value is incorrect: '%s' != val2.\n" "$val" >&2
        return 1
    fi
}

# Test stack_set.
test_stack_set() {
    # Setup default stack.
    _setup_test_stack "stack"

    # Make sure the 2nd value is correct.
    val=$(stack_get "stack" "1")
    if [ "$val" != "val1" ]; then
        printf "The second value is incorrect: '%s' != val1.\n" "$val" >&2
        return 1
    fi

    # Overwrite the 2nd value.
    stack_set "stack" "1" "new1"

    # Check it has been properly overwritten.
    val=$(stack_get "stack" "1")
    if [ "$val" != "new1" ]; then
        printf \
            "The overwritten value is incorrect: '%s' != 'new1'.\n" "$val" >&2
        return 1
    fi
}

# Test stack_delete.
test_stack_delete() {
    # Setup default stack.
    _setup_test_stack "stack"

    # Make sure the 2nd value is correct.
    val=$(stack_get "stack" "1")
    if [ "$val" != "val1" ]; then
        printf "The second value is incorrect: '%s' != val1.\n" "$val" >&2
        return 1
    fi

    # Delete the 2nd value, making the 3rd value the 2nd value.
    stack_delete "stack" "1"

    # Check it has been properly overwritten.
    val=$(stack_get "stack" "1")
    if [ "$val" != "val2" ]; then
        printf "The value is incorrect after delete: '%s' != 'val2'.\n" "$val" >&2
        return 1
    fi
}

# Test stack_foreach.
test_stack_foreach() {
    # Setup default stack.
    _setup_test_stack "stack"

    # Print all values.
    values=$(stack_foreach "stack" "printf '%s\n'")
    expected_values="val0
val1
val2"
    if [ "$values" != "$expected_values" ]; then
        printf "Printed values are not as expected.\n" >&2
        return 1
    fi
}

# Test stack_destroy.
test_stack_destroy() {
    # Setup default stack.
    _setup_test_stack "stack"

    # Check for correctly detecting the stack's length.
    eval "stack_length=\${${STACK_PREFIX}stack_len}"
    if [ "$stack_length" -ne 3 ]; then
        printf "Wrongly detecting stack length." >&2
        return 1
    fi

    # Check for correctly detecting the stack's items.
    eval "value0=\${${STACK_PREFIX}stack_0}"
    eval "value1=\${${STACK_PREFIX}stack_1}"
    eval "value2=\${${STACK_PREFIX}stack_2}"
    if [ "$value0" != "val0" ]; then
        printf "Wrongly detecting value at index 0." >&2
        return 1
    elif [ "$value1" != "val1" ]; then
        printf "Wrongly detecting value at index 1." >&2
        return 1
    elif [ "$value2" != "val2" ]; then
        printf "Wrongly detecting value at index 2." >&2
        return 1
    fi

    # Destroy stack and check if all variables have correctly been removed.
    stack_destroy "stack"
    eval "stack_length=\${${STACK_PREFIX}stack_len}"
    eval "value0=\${${STACK_PREFIX}stack_0}"
    eval "value1=\${${STACK_PREFIX}stack_1}"
    eval "value2=\${${STACK_PREFIX}stack_2}"

    if [ -n "$stack_length" ]; then
        printf "Stack length not reset: '%s'." "$stack_length" >&2
        return 1
    elif [ -n "$value0" ]; then
        printf "Stack value at index 0 did not reset: '%s'." "$value0" >&2
        return 1
    elif [ -n "$value1" ]; then
        printf "Stack value at index 1 did not reset: '%s'." "$value1" >&2
        return 1
    elif [ -n "$value2" ]; then
        printf "Stack value at index 2 did not reset: '%s'." "$value2" >&2
        return 1
    fi
}
