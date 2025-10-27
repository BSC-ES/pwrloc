# ------------------------------------------------------------------------------
# This wrapper contains functions for interacting with the SLURM energy
# accounting plugin.
# ------------------------------------------------------------------------------

# Get the directory where this file is located to load dependencies.
SLURMDIR="$BASEDIR/slurm"
. "$SLURMDIR/../utils/energy_utils.sh"
. "$SLURMDIR/../utils/general_utils.sh"
. "$SLURMDIR/../utils/print_utils.sh"


# Returns the value of a given parameter from the SLURM config file.
get_conf_value() {
    local line value

    # Get value from config.
    line=$(scontrol show config | grep "$1")

    # Remove all before "=", then strip whitespace on both ends.
    value=$(echo "$line" | sed 's/^[^=]*=[[:space:]]*//;s/[[:space:]]*$//')
    echo "$value"
}

# Returns the energy gatherer type.
slurm_profiler_type() {
    local type
    type=$(get_conf_value AcctGatherEnergyType)
    echo "${type#*/}"
}

# Returns the sample frequency.
slurm_profiler_freq() {
    # Try to get frequency for energy specifically.
    local p_freq
    p_freq=$(get_conf_value JobAcctGatherFrequency)

    if [ -n "$p_freq" ]; then
        # Get energy frequency from string, if present.
        IFS=',' set -- "$p_freq"
        for part; do
            case "$part" in
            energy=*)
                printf "%s\n" "${part#*=}"
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
        print_warning "<slurm_available> Function 'scontrol' not available."
        printf "1\n"
        return 1
    fi

    # Check if the gather type and frequency are non-zero.
    local p_type p_freq
    p_type=$(slurm_profiler_type)
    p_freq=$(slurm_profiler_freq)

    if [ -z "$p_type" ] || [ "$p_type" = "none" ] || [ -z "$p_freq" ]; then
        printf "1\n"
        return 1
    fi

    # If everything is present, than the energy accounting is enabled.
    printf "0\n"
    return 0
}

# Get the current energy consumption of a given job.
_slurm_get_energy_consumed() {
    local jobid values verbose_values max_joules value_joules max_human
    jobid="$1"
    values=$(sacct -j "$jobid" --format=ConsumedEnergy -nP)

    # Print more detailed energy measurements in verbose mode.
    verbose_values=$(
        sacct -j "$jobid" --format=JobId%25,JobName%25,ConsumedEnergy,Elapsed
    )
    verbose_echo print_info "Energy measurements:\n$verbose_values\n"

    # Loop through the collected values and save the maximum.
    max_joules=0

    while IFS= read -r line; do
        # Filter out empty lines.
        value_joules=$(convert_to_joules "$line") || continue
        if [ "$value_joules" -gt "$max_joules" ]; then
            max_joules=$value_joules
        fi
    done <<<"$values"

    # Convert maximum to kilojoules and print if verbose.
    max_human=$(convert_from_joules "$max_joules")
    verbose_echo print_info "Human readable:  ${max_human}"
    printf "%s J\n" "$max_joules"
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
    printf "%s\n" "$(_slurm_get_energy_consumed "$jobid")"
}
