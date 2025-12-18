#!/usr/bin/env sh
# ------------------------------------------------------------------------------
# Unit tests for the array functionality inside utils.
#   NOTE: All tests' names should start with "test_".
# ------------------------------------------------------------------------------

. "$SRCDIR/utils/array_utils.sh"


# Setup function to be used for setting up an array uniformly after the internal
# functions have been verified separately.
#   Usage:      _setup_test_array
_setup_test_array() {
    # Setup array.
    arr=$(array_push "" "val0")
    arr=$(array_push "$arr" "val1")
    arr=$(array_push "$arr" "val2")

    # Make sure the starting length is correct.
    if [ "$(array_len "$arr")" -ne 3 ]; then
        printf "<_setup_test_array> Created array does not have length 3.\n" >&2
        return 1
    fi

    # Print array to be used in tests.
    printf '%s' "$arr"
}

# Test array_len.
test_array_len() {
    # Create an empty array and test for length 0.
    arr=$(array_push "" "")
    if [ "$(array_len "$arr")" -ne 0 ]; then
        printf "Newly created array does not have length 0.\n" >&2
        return 1
    fi
}

# Test array_push.
test_array_push() {
    # Check array length after two pushes.
    arr=$(array_push "" "val0")
    if [ "$(array_len "$arr")" -ne 1 ]; then
        printf "Pushing a value does not increase array length to 1.\n" >&2
        return 1
    fi
   arr=$(array_push "$arr" "val1")
    if [ "$(array_len "$arr")" -ne 2 ]; then
        printf "Pushing a value does not increase array length to 2.\n" >&2
        return 1
    fi
}

# Test array_get_last.
test_array_get_last() {
    # Setup default array.
    arr="$(_setup_test_array)"

    # Check for first pop.
    top_val=$(array_get_last "$arr")
    if [ "$top_val" != "val2" ]; then
        printf "Top value incorrect: '%s' != val2.\n" "$top_val" >&2
        return 1
    fi
}

# Test array_pop.
test_array_pop() {
    # Setup default array.
    arr="$(_setup_test_array)"

    # Check for first pop.
    top_val=$(array_get_last "$arr")
    arr=$(array_pop "$arr")
    if [ "$top_val" != "val2" ]; then
        printf "Top value incorrect: '%s' != val2.\n" "$top_val" >&2
        return 1
    elif [ "$(array_len "$arr")" -ne 2 ]; then
        printf "array length is incorrect after first pop: '%s' != 2.\n" \
            "$(array_len "$arr")" >&2
        return 1
    fi

    # Check for second pop.
    top_val=$(array_get_last "$arr")
    arr=$(array_pop "$arr")
    if [ "$top_val" != "val1" ]; then
        printf "Top value incorrect: '%s' != val1.\n" "$top_val" >&2
        return 1
    elif [ "$(array_len "$arr")" -ne 1 ]; then
        printf "array length is incorrect after second pop: '%s' != 1.\n" \
            "$(array_len "$arr")" >&2
        return 1
    fi

    # Check for third pop.
    top_val=$(array_get_last "$arr")
    arr=$(array_pop "$arr")
    if [ "$top_val" != "val0" ]; then
        printf "Top value incorrect: '%s' != val0.\n" "$top_val" >&2
        return 1
    elif [ "$(array_len "$arr")" -ne 0 ]; then
        printf "array length is incorrect after third pop: '%s' != 0.\n" \
            "$(array_len "$arr")" >&2
        return 1
    fi
}

# Test array_get.
test_array_get() {
    # Setup default array.
    arr="$(_setup_test_array)"

    # Check for the first value.
    val=$(array_get "$arr" "0")
    if [ "$val" != "val0" ]; then
        printf "The first value is incorrect: '%s' != val0.\n" "$val" >&2
        return 1
    fi

    # Check for the second value.
    val=$(array_get "$arr" "1")
    if [ "$val" != "val1" ]; then
        printf "The second value is incorrect: '%s' != val1.\n" "$val" >&2
        return 1
    fi

    # Check for the third value.
    val=$(array_get "$arr" "2")
    if [ "$val" != "val2" ]; then
        printf "The third value is incorrect: '%s' != val2.\n" "$val" >&2
        return 1
    fi
}

# Test array_set.
test_array_set() {
    # Setup default array.
    arr="$(_setup_test_array)"

    # Make sure the 2nd value is correct.
    val=$(array_get "$arr" "1")
    if [ "$val" != "val1" ]; then
        printf "The second value is incorrect: '%s' != val1.\n" "$val" >&2
        return 1
    fi

    # Overwrite the 2nd value.
    arr="$(array_set "$arr" "1" "new1")"

    # Check it has been properly overwritten.
    val=$(array_get "$arr" "1")
    if [ "$val" != "new1" ]; then
        printf \
            "The overwritten value is incorrect: '%s' != 'new1'.\n" "$val" >&2
        return 1
    fi
}

# Test array_delete.
test_array_delete() {
    # Setup default array.
    arr="$(_setup_test_array)"

    # Make sure the 2nd value is correct.
    val=$(array_get "$arr" "1")
    if [ "$val" != "val1" ]; then
        printf "The second value is incorrect: '%s' != val1.\n" "$val" >&2
        return 1
    fi

    # Delete the 2nd value, making the 3rd value the 2nd value.
    arr="$(array_delete "$arr" "1")"

    # Check it has been properly overwritten.
    val=$(array_get "$arr" "1")
    if [ "$val" != "val2" ]; then
        printf "The value is incorrect after delete: '%s' != 'val2'.\n" "$val" >&2
        return 1
    fi
}

# Test array_foreach.
test_array_foreach() {
    # Define printing function to be used. Note it is globally defined!
    print_string() {
        printf '%s\n' "$1"
    }

    # Setup default array.
    arr="$(_setup_test_array)"

    # Print all values.
    values=$(array_foreach "$arr" print_string)
    expected_values="val0
val1
val2"
    if [ "$values" != "$expected_values" ]; then
        printf "Printed values are not as expected.\n" >&2
        return 1
    fi
}
