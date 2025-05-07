#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# This wrapper contains functions for interacting with the SLURM energy 
# accounting subsystem.
# ------------------------------------------------------------------------------

# Get the directory where this file is located to load dependencies.
BASEDIR="$(cd "$(dirname "$0")" && pwd)"

. "$BASEDIR/utils.sh"

# Returns 0 if SLURM is available, 1 otherwise.
slurm_available() {
    verbose_echo print_info "Checking for SLURM availability.."
    
    # Check if the plugin is set within the SLURM config.
    if function_exists scontrol; then
        # TODO: CHANGE TO JobAcctGatherEnergy to actually check for it being
        #   enabled.
        ETYPE=$(scontrol show config | grep AcctGatherEnergyType)
        [ -n "$ETYPE" ] && return 0
        # Get sample frequency, then strip till =, and lastly strip whitespace.
        FREQ=$(scontrol show config | grep AcctGatherNodeFreq)
        FREQ=$(echo "$FREQ" | sed 's/^[^=]*=[[:space:]]*//;s/[[:space:]]*$//')
    else
        print_warning "Function 'scontrol' not available."
    fi

    return 1
}
