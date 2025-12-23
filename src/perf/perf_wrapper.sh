#!/usr/bin/env sh
# ------------------------------------------------------------------------------
# This wrapper contains functions for interacting with the perf stat energy
# events.
# ------------------------------------------------------------------------------

# Get the directory where this file is located to load dependencies.
PERFDIR="$SRCDIR/perf"
. "$PERFDIR/../utils/general_utils.sh"
. "$PERFDIR/../utils/print_utils.sh"
. "$PAPIDIR/../utils/mpi_utils.sh"

# Get all available perf energy events.
_perf_get_energy_events() {
    perf list | grep energy | awk '{print $1}'
}

# Returns the sample frequency.
perf_get_events() {
    # Create a temp file for stderr.
    tmpfile=$(mktemp 2>/dev/null || echo "/tmp/catch.$$")
    events=$(_perf_get_energy_events 2>"$tmpfile")
    errors=$(cat "$tmpfile")
    rm "$tmpfile"

    # Print found events.
    if [ -z "$events" ]; then
        printf "NO EVENTS AVAILABLE\n"
    else
        printf "%s\n" "$events"
    fi

    # Print potential errors if in verbose mode.
    if [ -n "$errors" ]; then
        verbose_echo print_warning "<perf_get_events> $errors"
    fi
}

# Get the consumed energy for this rank (which can be total execution).
#   Usage:      _get_energy_consumed <bin> <args>
_get_energy_consumed() {
    # Get events.
    events=$(perf_get_events)
    perf_stat_events=$(echo "$events" | awk '{print " -e " $0}')
    perf_stat_events=$(echo "$perf_stat_events" | tr '\n' ' ')

    # Profile the binary with perf and store in stdout.
    perf_out=$(perf stat $perf_stat_events -- "$@" 2>&1)

    # Log if workload failed, and set energy to debug value.
    if printf "%s\n" "$perf_out" | grep -q 'Workload failed'; then
        print_error "Workload failed. Is the program available?"
        exit 1
    # Otherwise, process consumed energy normally.
    else
        # Extract the energy values from the perf output.
        energy=$(echo "$perf_out" | sed -n 's/^\(.*\) Joules.*/\1/p')

        # Strip whitespaces from the numbers.
        energy=$(echo "$energy" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')

        # Log if an event is not supported on machine.
        if printf "%s\n" "$energy" | grep -q '<not supported>'; then
            verbose_echo print_warning \
                "'<not supported>' found, is perfparanoid correctly set?"
        fi
    fi

    printf "%s\n" "$energy"
}

# Profile given application with perf and print the total consumed energy.
# Utilizes multiple ranks, if configured.
perf_profile() {
    # Get the perf events to be used as labels for printing totals.
    events=$(perf_get_events)

    # Acquire energy consumed for this rank.
    energy=$(_get_energy_consumed "$@")

    # Print total energy consumption per event, and merge ranks if needed.
    mpi_gather "combine" "$events" "$energy"
}

# Prints a list of perf events and whether they are supported.
perf_get_status_energy_events() {
    # Get list of events and the energy values.
    events=$(perf_get_events)
    energies=$(_get_energy_consumed sleep 0.001)

    # Get max element length for aligned printing.
    max_len=$(get_max_len "$events")

    # Print events and whether they are supported side-by-side, ignore actual
    # energy values.
    zip_strings "$events" "$energies" |
    while IFS=' ' read -r event energy; do
        if [ "$energy" = "<not supported>" ]; then
            printf "%-${max_len}s  <not supported>\n" "$event"
        else
            printf "%-${max_len}s\n" "$event"
        fi
    done
}

# Returns 1 if there are no supported events, 0 otherwise.
_perf_exist_supported_event() {
    energies=$(_get_energy_consumed sleep 0.001)
    printf '%s\n' "$energies" | grep -qv '^<not supported>$'
}

# Returns 0 if perf is available, 1 otherwise.
perf_available() {
    verbose_echo print_info "Checking for perf availability.."

    # Check if the perf command is available and there are supported events.
    if ! function_exists perf || ! _perf_exist_supported_event; then
        printf "1\n"
        return 1
    fi

    # Return True by default.
    printf "0\n"
    return 0
}
