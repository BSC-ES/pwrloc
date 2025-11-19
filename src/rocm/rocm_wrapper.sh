#!/usr/bin/env sh
# ------------------------------------------------------------------------------
# This wrapper contains functions for interacting with the ROCM energy
# profiling module for AMD GPUs.
# ------------------------------------------------------------------------------

# Get the directory where this file is located to load dependencies.
ROCMDIR="$SRCDIR/rocm"
. "$ROCMDIR/../utils/energy_utils.sh"
. "$ROCMDIR/../utils/general_utils.sh"
. "$ROCMDIR/../utils/print_utils.sh"


# Returns 0 if papi is available, 1 otherwise.
rocm_available() {
    verbose_echo print_info "Checking for rocm-smi availability.."

    # Check if the papi_avail command is available.
    if ! function_exists rocm-smi; then
        echo "1"
        return 1
    fi

    echo "0"
    return 0
}

# Get a ROCM power measurement for non-N/A cards.
_get_rocm_power_measurement() {
    rocm-smi --showpower --csv \
    | tail -n +2 \
    | head -n -1 \
    | while IFS=',' read -r device power; do
        # Skip N/A value.
        case $power in
            N/A*) ;;
            *) printf '%s %s\n' "$device" "$power" ;;
        esac
    done
}

# Profile the provided binary with NVML.
rocm_profile() {
    # Make sure rocm-smi is available.
    if ! rocm_available >/dev/null 2>&1; then
        print_error "rocm-smi is not available."
        return 1
    fi

    # Make sure that the cards are ready for power sampling.
    sample=$(rocm-smi --showpower 2>&1)
    if echo "$sample" | grep -q "ERROR:root:Driver not initialized"; then
        print_error "Failed to sample GPU power, are you on a compute node?"
        return 1
    fi

    # Initialize stacks for trackig energy consumption over time.
    stack_create "devices"
    stack_create "energies"
    _get_rocm_power_measurement | while IFS=' ' read -r device power; do
        stack_push "devices" "$device"
        stack_push "energies" "0"
    done

    # Launch the application and store PID for tracking.
    "$@" &
    child_pid=$!
    verbose_echo print_info "Application PID: $child_pid"

    # Poll with a set frequency until the child process is finished.
    poll_time_s=0.2

    while kill -0 "$child_pid" 2>/dev/null; do
        i=0
        _get_rocm_power_measurement | while IFS=' ' read -r device power; do
            watts="$power"
            energy_consumed=$(echo "$watts * $poll_time_s" | bc -l)
            cur_energy=$(stack_get "energies" "$i")
            stack_set "energies" "$i" \
                "$(echo "$cur_energy + $energy_consumed" | bc -l)"
            i=$((i+1))
        done

        # Poll with a fixed frequency.
        sleep $poll_time_s
    done

    # Report energy consumption per GPU and in total
    total_energy=0.0

    while [ "$(stack_len "devices")" -ne 0 ]; do
        stack_pop "devices"
        device=$STACK_POP_RESULT
        stack_pop "energies"
        energy=$STACK_POP_RESULT
        printf "GPU %s:\t%s J" "$device" "$energy"
        total_energy=$(echo "$total_energy + $energy" | bc -l)
    done

    printf "Total:\t%s J" "$total_energy"
}
