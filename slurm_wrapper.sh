#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# This wrapper contains functions for interacting with the SLURM energy 
# accounting plugin.
# ------------------------------------------------------------------------------

# Get the directory where this file is located to load dependencies.
BASEDIR=$(cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd)
. "$BASEDIR/utils.sh"

# Returns the value of a given parameter from the SLURM config file.
get_conf_value() {
    # Get value from config.
    local line=$(scontrol show config | grep "$1")
    
    # Remove all before "=", then strip whitespace on both ends.
    local value=$(echo "$line" | sed 's/^[^=]*=[[:space:]]*//;s/[[:space:]]*$//')
    echo "$value"
}

# Returns the energy gatherer type.
slurm_profiler_type() {
    get_conf_value AcctGatherEnergyType
}

# Returns the sample frequency.
slurm_profiler_freq() {
    # Try to get frequency for energy specifically.
    local p_freq=$(get_conf_value JobAcctGatherFrequency)

    if [ -n "$p_freq" ]; then
        # Get energy frequency from string, if present.
        IFS=',' set -- $p_freq
        for part; do
            case "$part" in
                energy=*) 
                    echo "${part#*=}"
                    return 0
                    ;;
            esac
        done
    fi

    # Otherwise default to node frequency.
    get_conf_value AcctGatherNodeFreq
}

# Returns 0 if SLURM is available, 1 otherwise.
slurm_available() {
    verbose_echo print_info "Checking for SLURM availability.."
    
    # Check if the plugin is set within the SLURM config.
    if ! function_exists scontrol; then
        print_warning "Function 'scontrol' not available."
        return 1
    fi

    # Check if the gather type and frequency are non-zero.
    local p_type=$(slurm_profiler_type)
    local p_freq=$(slurm_profiler_freq)

    if [ -z "$p_type" ] || [ -z "$p_freq" ]; then
        echo 1
        return 1
    fi

    # If everything is present, than the energy accounting is enabled.
    echo 0
    return 0
}

# Convert a ConsumedEnergy string (e.g. "123.45K") to integer joules.
convert_to_joules() {
    # Strip whitespace
    local string=$(printf "%s" "$1" | tr -d ' ')

    # Catch empty lines.
    if [ -z "$string" ]; then
        echo "0"
        return
    fi

    # Separate numeric value and unit
    local num=$(printf "%s" "$string" | sed 's/[KMG]$//')
    local unit=$(printf "%s" "$string" | sed 's/^[0-9.]*//')

    # Choose multiplier based on unit
    case "$unit" in
        "")  mult=1 ;;
        K)   mult=1000 ;;
        M)   mult=1000000 ;;
        G)   mult=1000000000 ;;
        *)   echo "Unknown unit: $unit" >&2; return 1 ;;
    esac

    # Convert to integer joules.
    printf "%.0f" "$(echo "$num * $mult" | bc)"
}

# Convert integer joules into human readable unit (J, K, M, G).
convert_from_joules() {
    local joules="$1"

    if [ "$joules" -ge 1000000000 ]; then
        local unit="G"
        local divisor=1000000000
    elif [ "$joules" -ge 1000000 ]; then
        local unit="M"
        local divisor=1000000
    elif [ "$joules" -ge 1000 ]; then
        local unit="K"
        local divisor=1000
    else
        local unit=""
        local divisor=1
    fi

    local value=$(echo "scale=2; $joules / $divisor" | bc)
    printf "%s %sJ" "$value" "$unit"
}

# Get the current energy consumption of a given job.
slurm_get_energy_consumed() {
    local jobid="$1"
    local values=$(sacct -j "$jobid" --format=ConsumedEnergy -nP)

    # Loop through the collected values and save the maximum.
    local max_joules=0

    while IFS= read -r line; do
        # Filter out empty lines.
        value_joules=$(convert_to_joules "$line") || continue
        if [ "$value_joules" -gt "$max_joules" ]; then
            max_joules=$value_joules
        fi
    done <<< "$values"

    # Convert maximum to kilojoules.
    local max_human=$(convert_from_joules "$max_joules")
    echo "${max_human}"
}

# Profile given application with SLURM and return the total consumed energy.
slurm_profile() {
    verbose_echo print_info "Profiling using SLURM.."
    local jobid="$1"

    # Check if we are inside a running SLURM job.
    if [ -z "$jobid" ]; then
        print_error "No dependency job id."
        exit 1
    fi

    # Log what job is profiled.
    verbose_echo print_info "Profiling jobid '$jobid'.."

    # Get energy consumed value.
    local energy=$(slurm_get_energy_consumed $jobid)
    echo -e "Energy consumption:\t$energy"
}
