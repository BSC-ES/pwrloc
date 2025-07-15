#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# This wrapper contains functions for interacting with the SLURM energy 
# accounting plugin.
# ------------------------------------------------------------------------------

# Get the directory where this file is located to load dependencies.
SLURMDIR=$(cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd)
. "$SLURMDIR/../utils.sh"

# Returns the value of a given parameter from the SLURM config file.
get_conf_value() {
    # Get value from config.
    local line=$(scontrol show config | grep "$1")
    
    # Remove all before "=", then strip whitespace on both ends.
    local value=$(
        echo "$line" | sed 's/^[^=]*=[[:space:]]*//;s/[[:space:]]*$//'
    )
    echo "$value"
}

# Returns the energy gatherer type.
slurm_profiler_type() {
    local type=$(get_conf_value AcctGatherEnergyType)
    echo "${type#*/}"
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
        echo "1"
        return 1
    fi

    # Check if the gather type and frequency are non-zero.
    local p_type=$(slurm_profiler_type)
    local p_freq=$(slurm_profiler_freq)

    if [ -z "$p_type" ] || [ "$p_type" = "none" ] || [ -z "$p_freq" ]; then
        echo "1"
        return 1
    fi

    # If everything is present, than the energy accounting is enabled.
    echo "0"
    return 0
}

# Get the current energy consumption of a given job.
_slurm_get_energy_consumed() {
    local jobid="$1"
    local values=$(sacct -j "$jobid" --format=ConsumedEnergy -nP)

    # Print more detailed energy measurements in verbose mode.
    local verbose_values=$(
        sacct -j "$jobid" --format=JobId%25,JobName%25,ConsumedEnergy,Elapsed
    )
    verbose_echo print_info "Energy measurements:\n$verbose_values\n"

    # Loop through the collected values and save the maximum.
    local max_joules=0

    while IFS= read -r line; do
        # Filter out empty lines.
        value_joules=$(convert_to_joules "$line") || continue
        if [ "$value_joules" -gt "$max_joules" ]; then
            max_joules=$value_joules
        fi
    done <<< "$values"

    # Convert maximum to kilojoules and print if verbose.
    local max_human=$(convert_from_joules "$max_joules")
    verbose_echo print_info "Human readable:  ${max_human}"
    echo "$max_joules J"
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

    # Verify that the job id is fully numerical.
    if ! is_numerical "$jobid"; then
        print_error "Passed argument '$jobid' is not a valid job id."
        exit 1
    fi

    # Log what job is profiled.
    verbose_echo print_info "Profiling jobid '$jobid'.."

    # Get energy consumed value.
    echo -e "$(_slurm_get_energy_consumed $jobid)"
}
