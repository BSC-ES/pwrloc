#!/usr/bin/env sh
# ------------------------------------------------------------------------------
# Unit tests for the stack functionality inside utils.
#   NOTE: All tests' names should start with "test_".
# ------------------------------------------------------------------------------

. "$SRCDIR/utils/stack_utils.sh"


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
    stack_push "stack" "val"
    if [ "$(stack_len "stack")" -ne 1 ]; then
        printf "Pushing a value does not increase stack length to 1.\n" >&2
        return 1
    fi
    stack_push "stack" "val2"
    if [ "$(stack_len "stack")" -ne 2 ]; then
        printf "Pushing a value does not increase stack length to 2.\n" >&2
        return 1
    fi
}

# Test stack_pop.
test_stack_pop() {
    # Setup stack.
    stack_create "stack"
    stack_push "stack" "1"
    stack_push "stack" "2"
    stack_push "stack" "3"

    # Make sure the starting length is correct.
    if [ "$(stack_len "stack")" -ne 3 ]; then
        printf "Created stack does not have length 3.\n" >&2
        return 1
    fi

    # Check for first pop.
    stack_pop "stack"
    top_val=$STACK_POP_RESULT
    if [ "$top_val" != "3" ]; then
        printf "Top value incorrect: '%s' != 3.\n" "$top_val" >&2
        return 1
    elif [ "$(stack_len "stack")" -ne 2 ]; then
        printf "Stack length is incorrect after first pop: '%s' != 2.\n" \
            "$(stack_len "stack")" >&2
        return 1
    fi

    # Check for second pop.
    stack_pop "stack"
    top_val=$STACK_POP_RESULT
    if [ "$top_val" != "2" ]; then
        printf "Top value incorrect: '%s' != 2.\n" "$top_val" >&2
        return 1
    elif [ "$(stack_len "stack")" -ne 1 ]; then
        printf "Stack length is incorrect after second pop: '%s' != 1.\n" \
            "$(stack_len "stack")" >&2
        return 1
    fi

    # Check for third pop.
    stack_pop "stack"
    top_val=$STACK_POP_RESULT
    if [ "$top_val" != "1" ]; then
        printf "Top value incorrect: '%s' != 1.\n" "$top_val" >&2
        return 1
    elif [ "$(stack_len "stack")" -ne 0 ]; then
        printf "Stack length is incorrect after third pop: '%s' != 0.\n" \
            "$(stack_len "stack")" >&2
        return 1
    fi
}

# Test stack_get.
test_stack_get() {
    # Setup stack with 3 values.
    stack_create "stack"
    stack_push "stack" "val1"
    stack_push "stack" "val2"
    stack_push "stack" "val3"

    # Make sure the starting length is correct.
    if [ "$(stack_len "stack")" -ne 3 ]; then
        printf "Created stack does not have length 3.\n" >&2
        return 1
    fi

    # Check for the first value.
    val=$(stack_get "stack" "0")
    if [ "$val" != "val1" ]; then
        printf "The first value is incorrect: '%s' != val1.\n" "$val" >&2
        return 1
    fi

    # Check for the second value.
    val=$(stack_get "stack" "1")
    if [ "$val" != "val2" ]; then
        printf "The second value is incorrect: '%s' != val2.\n" "$val" >&2
        return 1
    fi

    # Check for the third value.
    val=$(stack_get "stack" "2")
    if [ "$val" != "val3" ]; then
        printf "The third value is incorrect: '%s' != val3.\n" "$val" >&2
        return 1
    fi
}

# Test stack_set.
test_stack_set() {
    # Setup stack with 3 values.
    stack_create "stack"
    stack_push "stack" "val1"
    stack_push "stack" "val2"
    stack_push "stack" "val3"

    # Make sure the starting length is correct.
    if [ "$(stack_len "stack")" -ne 3 ]; then
        printf "Created stack does not have length 3.\n" >&2
        return 1
    fi

    # Make sure the 2nd value is correct.
    val=$(stack_get "stack" "1")
    if [ "$val" != "val2" ]; then
        printf "The second value is incorrect: '%s' != val2.\n" "$val" >&2
        return 1
    fi

    # Overwrite the 2nd value.
    stack_set "stack" "1" "new2"

    # Check it has been properly overwritten.
    val=$(stack_get "stack" "1")
    if [ "$val" != "new2" ]; then
        printf "The second value is incorrect: '%s' != 'new2'.\n" "$val" >&2
        return 1
    fi
}

# Test stack_delete.
test_stack_delete() {
    # TODO: Implement!
    printf ""
}

# Test stack_foreach.
test_stack_foreach() {
    # TODO: Implement!
    printf ""
}

# Test stack_destroy.
test_stack_destroy() {
    # TODO: Implement!
    printf ""
}
