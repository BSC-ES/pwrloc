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
. "$PAPIDIR/../utils/array_utils.sh"


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

    # Initialize arrays for trackig energy consumption over time.
    devices=""
    energies=""
    while IFS=' ' read -r device power; do
        devices=$(array_push "$devices" "$device")
        energies=$(array_push "$energies" "0")
    done <<EOF
$(_get_rocm_power_measurement)
EOF

    # Launch the application and store PID for tracking.
    "$@" &
    child_pid=$!
    verbose_echo print_info "Application PID: $child_pid"

    # Poll with a set frequency until the child process is finished.
    poll_time_s=0.2

    while kill -0 "$child_pid" 2>/dev/null; do
        i=0
        while IFS=' ' read -r device power; do
            watts="$power"
            energy_consumed=$(echo "$watts * $poll_time_s" | bc -l)
            cur_energy=$(array_get "$energies" "$i")
            energies=$(array_set "$energies" "$i" \
                "$(echo "$cur_energy + $energy_consumed" | bc -l)")
            i=$((i+1))
        done <<EOF
$(_get_rocm_power_measurement)
EOF

        # Poll with a fixed frequency.
        sleep $poll_time_s
    done

    # Compute total of GPUs.
    total_energy=0.0
    num_devices=$(array_len "$devices")

    i=0
    while [ "$i" -lt "$num_devices" ]; do
        energy=$(array_get "$energies" "$i")
        total_energy=$(echo "$total_energy + $energy" | bc -l)
        i=$(( i + 1 ))
    done

    # Add total energy to arrays.
    devices=$(array_push "$devices" "Total")
    energies=$(array_push "$energies" "$total_energy")

    # Print total energy consumption per event, and gather ranks if needed.
    mpi_gather "$MPI_MODE" "$devices" "$energies"
}
