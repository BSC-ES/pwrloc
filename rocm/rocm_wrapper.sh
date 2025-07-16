#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# This wrapper contains functions for interacting with the ROCM energy 
# profiling module for AMD GPUs.
# ------------------------------------------------------------------------------

# Get the directory where this file is located to load dependencies.
ROCMDIR=$(cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd)
. "$ROCMDIR/../utils/utils.sh"

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
    rocm-smi --showpower --csv | tail -n +2 | while IFS=',' read -r device power; do
        if [[ "$power" != "N/A"* ]]; then
            echo "$device $power"
        fi
    done
}

# Profile the provided binary with NVML.
rocm_profile() {
    # Make sure rocm-smi is available.
    if ! rocm_available 2>&1 > /dev/null; then
        print_error "rocm-smi is not available."
        return
    fi

    # Initialize arrays for trackig energy consumption.
    local devices=()
    local energy=()
    local i=0
    while read -r device power; do
        devices[i]="$device"
        energy[i]=0
        ((i++))
    done < <(_get_rocm_power_measurement)

    # Launch the application and store PID for tracking.
    "$@" &
    local child_pid=$!

    # Poll with a set frequency until the child process is finished.
    local poll_time_s=0.2
    local watts=0.0

    while kill -0 "$PID" 2>/dev/null; do
        i=0
        while read -r device power; do
            # strip W and convert to float
            watts=$(echo "$power")
            energy_consumed=$(echo "$watts * $INTERVAL" | bc -l)
            energy[i]=$(echo "${energy[i]} + $energy_consumed" | bc -l)
            ((i++))
        done < <(_get_rocm_power_measurement)

        # Poll with a fixed frequency.
        sleep $poll_time_s
    done

    # Report energy consumption per GPU and in total
    local total_energy=0.0
    for i in "${!devices[@]}"; do
        echo -e "GPU ${devices[i]}:\t${energy[i]} J"
        total_energy=$(echo "$total_energy + ${energy[i]}" | bc -l)
    done
    echo -e "Total:\t${energy[i]} J"
}
