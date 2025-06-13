#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# This wrapper contains functions for interacting with the perf stat energy 
# events.
# ------------------------------------------------------------------------------

# Get the directory where this file is located to load dependencies.
BASEDIR=$(cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd)
. "$BASEDIR/utils.sh"

# Returns the sample frequency.
perf_events() {
    local events=$(perf list | grep energy | awk '{print $1}')
    echo "$events"
}

# Returns 0 if perf is available, 1 otherwise.
perf_available() {
    verbose_echo print_info "Checking for perf availability.."

    # Check if the plugin is set within the SLURM config.
    if ! function_exists perf; then
        echo 1
        return 1
    fi

    echo 0
    return 0
}

# Get the consumed energy for this rank (which can be total execution).
get_energy_consumed() {
    local events=$(perf_events)
    local perf_stat_events=$(echo "$events" | awk '{print " -e " $0}')
    perf_stat_events=$(echo $perf_stat_events | tr '\n' ' ')
    
    # Profile the binary with perf and store in stdout.
    local perf_out=$(perf stat -e $perf_stat_events -- "$bin" "$args" 2>&1)
    
    # Extract the energy values from the perf output.
    local energy=$(echo "$perf_out" | sed -n 's/^\(.*\) Joules.*/\1/p')

    # Strip whitespaces from the numbers.
    energy=$(echo "$energy" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')

    # Throw warning in verbose mode if perf signifies not supported.
    if echo "$energy" | grep -q '<not supported>'; then
        verbose_echo print_warning \
            "'<not supported>' found, is perfparanoid correctly set?"
    fi

    # Read newline-separated strings into arrays
    readarray -t event_array <<< "$events"
    readarray -t energy_array <<< "$energy"

    # Find the longest event name for aligning the print.
    local max_len=0
    for event in "${event_array[@]}"; do
        (( ${#event} > max_len )) && max_len=${#event}
    done

    # Print events with collected values side by side.
    echo "Energy consumption:"
    for i in "${!event_array[@]}"; do
        printf "\t%-${max_len}s\t%s\n" "${event_array[$i]}:" \
            "${energy_array[$i]}"
    done
}

# Function called by rank 0 to gather all collected results and remove the dir.
gather_results() {
    tmp_dir="$1"
    num_ranks=${OMPI_COMM_WORLD_SIZE:-${PMI_SIZE:-${SLURM_NTASKS:-1}}}

    while true; do
        file_count=$(find "$tmp_dir" -maxdepth 1 -type f | wc -l)
        if (( file_count >= num_ranks )); then
            echo "Found $file_count files. Proceeding..."
            break
        fi
        sleep 0.5
    done
}

# Profile given application with perf and return the total consumed energy.
perf_profile() {
    # Acquire energy consumed for this rank (or total exection without MPI).
    energy=$(get_energy_consumed)

    # Get job and rank ID and write to output file.
    local job=${SLURM_JOB_ID:-${PBS_JOBID:-${JOB_ID:-"r$RANDOM"}}}
    local rank=${OMPI_COMM_WORLD_RANK:-${PMI_RANK:-${SLURM_PROCID:-${MPI_RANK:-0}}}}
    local tmp_dir="tmp.$job"
    mkdir -p "$tmp_dir"
    echo "$energy" > "$tmp_dir/rank_$rank.tmp"

    # If rank 0, wait for all files, then gather values and remove them.
    if [ "$rank" -eq "0" ]; then
        energy_total=$(gather_results "$tmp_dir")
        echo "$energy_total"
    fi
}
