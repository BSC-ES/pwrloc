#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# This wrapper contains functions for interacting with the SLURM energy 
# accounting plugin.
# ------------------------------------------------------------------------------

# Get the directory where this file is located to load dependencies.
SLURM_DIR="$(cd "$(dirname "$0")" && pwd)"

. "$SLURM_DIR/utils.sh"

# Returns the value of a given parameter from the SLURM config file.
get_conf_value() {
    # Get value from config.
    line=$(scontrol show config | grep "$1")
    
    # Remove all before "=", then strip whitespace on both ends.
    value=$(echo "$line" | sed 's/^[^=]*=[[:space:]]*//;s/[[:space:]]*$//')
    echo "$value"
}

# Returns the energy gatherer type.
slurm_profiler_type() {
    get_conf_value AcctGatherEnergyType
}

# Returns the sample frequency.
slurm_profiler_freq() {
    # Try to get frequency for energy specifically.
    P_FREQ=$(get_conf_value JobAcctGatherFrequency)

    if [ -n "$P_FREQ" ]; then
        # Get energy frequency from string, if present.
        IFS=',' set -- $P_FREQ
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
    P_TYPE=$(slurm_profiler_type)
    P_FREQ=$(slurm_profiler_freq)

    if [ -z "$P_TYPE" ] || [ -z "$P_FREQ" ]; then
        echo 1
        return 1
    fi

    # If everything is present, than the energy accounting is enabled.
    echo 0
    return 0
}

# Get the current energy consumption of a given job.
slurm_get_energy_consumed() {
    JOBID="$1"
    VALUES=$(sacct -j "$JOBID" --format=ConsumedEnergy -nP)
    SUM=$(echo $VALUES | paste -sd+ | bc)
    echo "SUM: $SUM"

    # Go line by line and sum up the values.
    # if [ -n "$P_FREQ" ]; then
    #     # Get energy frequency from string, if present.
    #     IFS='\n' set -- $P_FREQ
    #     for part; do
    #         case "$part" in
    #             energy=*) 
    #                 echo "${part#*=}"
    #                 return 0
    #                 ;;
    #         esac
    #     done
    # fi
}

# Profile given application with SLURM and return the total consumed energy.
slurm_profile() {
    verbose_echo print_info "Profiling using SLURM.."

    # Check if we are inside a running SLURM job.
    if [ -z "$SLURM_JOB_ID" ]; then
        print_error "Not in a SLURM job."
        exit 1
    fi

    # Get starting energy consumed value of currently running job.
    E_START="$(slurm_get_energy_consumed $SLURM_JOB_ID)"
    verbose_echo print_info "Start energy consumed:  $E_START"

    # Execute the program.
    "$@"
    local retval=$?
    verbose_echo "Application finished with return value: $retval"

    # Get new energy consumed value.
    E_END=$(slurm_get_energy_consumed $SLURM_JOB_ID)
    verbose_echo print_info "End energy consumed:  $E_END"

    # Report the consumed energy.
    echo "Energy Profile:"
    echo -e "\tStart:     $E_START"
    echo -e "\tEnd:       $E_END"
    echo -e "\tConsumed:  $E_CONSUMED"
}
