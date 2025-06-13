#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# This wrapper contains functions for interacting with the perf stat energy 
# events.
# ------------------------------------------------------------------------------

# Get the directory where this file is located to load dependencies.
BASEDIR=$(cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd)
. "$BASEDIR/utils.sh"

# Returns the sample frequency.
perf_events() {
    local events=$(perf list | grep energy | awk '{print $1}')
    echo "$events"
}

# Returns 0 if perf is available, 1 otherwise.
perf_available() {
    verbose_echo print_info "Checking for perf availability.."

    # Check if the plugin is set within the SLURM config.
    if ! function_exists perf; then
        echo 1
        return 1
    fi

    echo 0
    return 0
}

# Profile given application with perf and return the total consumed energy.
perf_profile() {
    local events=$(perf_events)
    local perf_stat_events=$(echo "$events" | awk '{print " -e " $0}')
    perf_stat_events=$(echo $perf_stat_events | tr '\n' ' ')
    
    # Profile the binary with perf and store in stdout.
    local perf_out=$(perf stat -e $perf_stat_events -- "$bin" "$args" 2>&1)
    
    # Extract the energy values from the perf output.
    local energy=$(echo "$perf_out" | sed -n 's/^\(.*\) Joules.*/\1/p')

    # Strip whitespaces from the numbers.
    energy=$(echo "$energy" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')

    # Throw warning in verbose mode if perf signifies not supported.
    if echo "$energy" | grep -q '<not supported>'; then
        verbose_echo print_warning \
            "'<not supported>' found, is perfparanoid correctly set?"
    fi

    # Read newline-separated strings into arrays
    readarray -t event_array <<< "$events"
    readarray -t energy_array <<< "$energy"

    # Find the longest event name for aligning the print.
    local max_len=0
    for event in "${event_array[@]}"; do
        (( ${#event} > max_len )) && max_len=${#event}
    done

    # Print events with collected values side by side.
    echo "Energy consumption:"
    for i in "${!event_array[@]}"; do
        printf "\t%-${max_len}s\t%s\n" "${event_array[$i]}:" \
            "${energy_array[$i]}"
    done
}
