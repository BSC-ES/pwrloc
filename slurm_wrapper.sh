#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# This wrapper contains functions for interacting with the SLURM energy 
# accounting subsystem.
# ------------------------------------------------------------------------------

# Get the directory where this file is located to load dependencies.
BASEDIR="$(cd "$(dirname "$0")" && pwd)"

. "$BASEDIR/utils.sh"

# Returns the value of a given parameter from the SLURM config file.
get_conf_value() {
    # Get value from config.
    line=$(scontrol show config | grep "$1")
    
    # Remove all before "=", then strip whitespace on both ends.
    value=$(echo "$line" | sed 's/^[^=]*=[[:space:]]*//;s/[[:space:]]*$//')
    echo "$value"
}

# Returns 0 if SLURM is available, 1 otherwise.
slurm_available() {
    verbose_echo print_info "Checking for SLURM availability.."
    
    # Check if the plugin is set within the SLURM config.
    if function_exists scontrol; then
        P_ENABLED=$(get_conf_value JobAcctGatherEnergy)
        [ -n "$P_ENABLED" ] && return 0
    else
        print_warning "Function 'scontrol' not available."
    fi

    return 1
}

# Returns the energy gatherer type.
slurm_profiler_type() {
    get_conf_value AcctGatherEnergyType
}

# Returns the sample frequency.
slurm_profiler_freq() {
    get_conf_value AcctGatherNodeFreq
}
