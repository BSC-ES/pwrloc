#!/usr/bin/env sh
# ------------------------------------------------------------------------------
# Main entrypoint for running the test suite.
# Simply run the run_test_suite() function to execute all tests.
# ------------------------------------------------------------------------------

# Get the directory where this file is located to load dependencies.
TESTSDIR="$SRCDIR/../tests"
. "$TESTSDIR/test_utils_stack.sh"

# Import general utils.
. "$SRCDIR/utils/print_utils.sh"

# Global counters and track of error logs.
TESTS_PASS=0
TESTS_FAIL=0
TESTS_FAIL_LOG=""

# Try enabling color printing.
TESTS_COLOR=0
if command -v tput >/dev/null 2>&1 && \
   [ "$(tput colors 2>/dev/null)" -ge 8 ]; then
    TESTS_COLOR=1
fi


# Show test suite preamble.
show_tests_preamble() {
    print_full_width "="
    print_centered "Welcome to  pwrloc's test suite!"
    print_full_width "="
}

# Color text for failure, if coloring is supported.
color_fail() {
    if [ $TESTS_COLOR -eq 1 ]; then
        printf '\033[31m%s\033[0m' "$1"
    else
        printf '%s' "$1"
    fi
}

# Color text for success, if coloring is supported.
color_pass() {
    if [ $TESTS_COLOR -eq 1 ]; then
        printf '\033[32m%s\033[0m' "$1"
    else
        printf '%s' "$1"
    fi
}

# Color text for names, if coloring is supported.
color_name() {
    if [ $TESTS_COLOR -eq 1 ]; then
        printf '\033[36m%s\033[0m' "$1"
    else
        printf '%s' "$1"
    fi
}

# Run a single test.
#   Usage:    run_test <test_name> <test_function>
run_test() {
    test_name=$1
    func=$2

    # Make temporary file for capturing errors.
    tmp=$(mktemp 2>/dev/null || echo "/tmp/pwrloc-test.$$")

    # Run the test in a subshell and catch stderr.
    ( $func ) 2>"$tmp"
    retval=$?

    # Report test results.
    if [ $retval -eq 0 ]; then
        TESTS_PASS=$((TESTS_PASS+1))
        if [ "$VERBOSE" -eq 1 ]; then
            printf "%s %s\n" "$(color_pass 'TESTS_PASS')" \
                "$(color_name "$test_name")"
        else
            printf "%s" "$(color_pass '.')"
        fi
    else
        TESTS_FAIL=$((TESTS_FAIL+1))
        err="$(cat "$tmp")"
        if [ "$VERBOSE" -eq 1 ]; then
            printf "%s %s\n" "$(color_fail 'TESTS_FAIL')" \
                "$(color_name "$test_name")"
        else
            printf "%s" "$(color_fail 'F')"
        fi
        TESTS_FAIL_LOG="$TESTS_FAIL_LOG

$(color_fail "TEST FAILED: $(basename "$test_name")")
$err"
    fi

    # Clean up.
    rm -f "$tmp"
}

# Discover tests inside a file and execute them.
discover_tests_in_file() {
    # Get test filename and load it.
    file=$1
    . "$file"

    # Lead test results with filename.
    printf "%s: " "$(basename "$file")"
    if [ "$VERBOSE" -eq 1 ]; then
        printf "\n"
    fi

    # List functions starting with "test_".
    _tmp_tests=$(mktemp 2>/dev/null || echo "/tmp/posix-test.$$")
    grep -E '^test_[a-zA-Z0-9_]* *\(\)' "$file" | sed 's/().*//' > "$_tmp_tests"

    # Execute found tests.
    while IFS= read -r fn; do
        run_test "$file:$fn" "$fn"
    done < "$_tmp_tests"
    printf "\n"
}

# Discover test files in "tests/test_*.sh" and execute them.
discover_and_run_all() {
    for file in "$TESTSDIR"/test_*.sh; do
        [ -f "$file" ] || continue
        discover_tests_in_file "$file"
    done
}

# Run the test suite.
run_test_suite() {
    # Print preamble.
    show_tests_preamble

    # Discover and run all tests within the suite.
    discover_and_run_all

    # Print failure logs.
    if [ $TESTS_FAIL -gt 0 ]; then
        printf "\n========\nFAIL LOG\n========%s\n" "$TESTS_FAIL_LOG"
    fi

    # Print final summary.
    printf "\n%d passed, %d failed\n" "$TESTS_PASS" "$TESTS_FAIL"

    # Exit with error equals number of failed tests.
    exit $TESTS_FAIL
}
