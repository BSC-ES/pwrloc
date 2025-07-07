#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# This wrapper contains functions for interacting with the PAPI energy 
# profiling options.
# ------------------------------------------------------------------------------

# Get the directory where this file is located to load dependencies.
BASEDIR=$(cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd)
. "$BASEDIR/utils.sh"

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

# Parser that transforms papi_command_line output into a returned boolean int.
parse_papi_command_line() {
    # 
}

# Return the set of energy events supported by this system.
papi_events() {
    # Make sure we can test for validity of counters.
    if ! function_exists papi_command_line; then
        print_error "Command 'papi_command_line' unavailable."
        return 1
    fi

    # Predefined sets of counters to test for.
    local intel_amd_events=("rapl::RAPL_ENERGY_PKG" "rapl::RAPL_ENERGY_DRAM")
    local cray_events=("cray_rapl:::PACKAGE_ENERGY" "cray_rapl:::PP0_ENERGY")

    # Test for Intel/AMD-RAPL events.
    local found_event=1
    local supported_events=()

    for event in "${intel_amd_events[@]}"; do
        if parse_papi_command_line "$event"; then
            found_event=0
            supported_events+=("$event")
        fi
    done

    # Only test for Cray-RAPL if no events were found.
    if [ "$found_event" -eq "1" ]; then
        for event in "${cray_events[@]}"; do
            if parse_papi_command_line "$event"; then
                found_event=0
                supported_events+=("$event")
            fi
        done
    fi
}

# Profile the provided binary with PAPI counters.
# Detects and switches to PM_Counters if profiling on a Cray system.
papi_profile() {
    # Get supported events, and return if none were found.
    local events=$(papi_events)
    if [[ "${#events[@]}" -eq 0 ]]; then
        print_warning "No supported PAPI events were found."
        return 1
    fi

    # Compile papi_profiler.c.
    cc "$BASEDIR/papi_profiler.c" -o "$BASEDIR/papi_profiler" -lpapi
    chmod +x "$BASEDIR/papi_profiler"

    # Profile binary with supported events.
    ./papi_profiler "$found_events" $@
    return 0
}
