#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# This file contains common utils to be used.
# ------------------------------------------------------------------------------

# Default VERBOSE value in case it is not set elsewhere.
VERBOSE=0

# Only echo given string if VERBOSE is set.
function verbose_echo() {
    if [ "$VERBOSE" -eq 1 ]; then
        echo "$1"
    fi
}
