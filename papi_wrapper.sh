#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# This wrapper contains functions for interacting with the PAPI energy 
# profiling options.
# ------------------------------------------------------------------------------

# Get the directory where this file is located to load dependencies.
BASEDIR=$(cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd)
. "$BASEDIR/utils.sh"

PAPI_PROFILER="$BASEDIR/papi_profiler.o"

# Returns 0 if papi is available, 1 otherwise.
papi_available() {
    verbose_echo print_info "Checking for papi availability.."

    # Check if the papi_avail command is available.
    if ! function_exists papi_avail; then
        echo "1"
        return 1
    fi

    echo "0"
    return 0
}

_compile_papi_profiler() {
    # Check if the binary exists, if so remove.
    if [ -f "$PAPI_PROFILER" ]; then
        rm "$PAPI_PROFILER"
    fi

    # Compile the code.
    cc "$BASEDIR/papi_profiler.c" -o "$PAPI_PROFILER" -lpapi
    chmod +x "$PAPI_PROFILER"
}

# Return the set of energy events supported by this system.
papi_events() {
   # Make sure the papi_profiler is updated and compiled.
    _compile_papi_profiler

    # Print supported events to stdout.
    "$PAPI_PROFILER" get_events
}

# Profile the provided binary with PAPI counters.
# Detects and switches to PM_Counters if profiling on a Cray system.
papi_profile() {
    # Make sure the papi_profiler is updated and compiled.
    _compile_papi_profiler

    # Profile binary with supported events.
    "$PAPI_PROFILER" profile $@
}
