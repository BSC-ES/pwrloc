#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# This wrapper contains functions for interacting with the perf stat energy 
# events.
# ------------------------------------------------------------------------------

# Get the directory where this file is located to load dependencies.
BASEDIR=$(cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd)
. "$BASEDIR/utils.sh"

# Returns 0 if perf is available, 1 otherwise.
perf_available() {
    verbose_echo print_info "Checking for perf availability.."

    # Check if the perf command is available.
    if ! function_exists perf; then
        echo "1"
        return 1
    fi

    echo "0"
    return 0
}

# Returns the sample frequency.
perf_events() {
    echo "$(perf list | grep energy | awk '{print $1}')"
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

    echo "$energy"
}

# Reads energy values from given file and prints them sanitized.
sanitize_energy_values() {
    local energy_input=$(cat "$1")
    readarray -t energy_array <<< "$energy_input"

    # Replace any non-numerical items with 0 as fallback.
    for i in "${!energy_array[@]}"; do
        if ! is_numerical "${energy_array[i]}"; then
            energy_array[i]=0
        fi
    done

    echo "${energy_array[@]}"
}

# Gather all collected results and delete the temporary directory.
#   !! This function should only be called by rank 0. !!
gather_results() {
    local tmp_dir="$1"
    local num_ranks=${OMPI_COMM_WORLD_SIZE:-${PMI_SIZE:-${SLURM_NTASKS:-1}}}
    local file_count=0

    # Wait for all files to appear.
    while true; do
        file_count=$(find "$tmp_dir" -maxdepth 1 -type f | wc -l)
        if (( file_count >= num_ranks )); then
            break
        fi
        sleep 0.5
    done

    # Merge the energy logs into one, starting by own file.
    local energy_total=( $(sanitize_energy_values "$tmp_dir/rank_0.out") )
    local energy_input=()

    for ((i=2; i<=num_ranks; i++)); do
        energy_input=( $(sanitize_energy_values "$tmp_dir/rank_$((i - 1)).out") )
        for i in "${!energy_input[@]}"; do
            energy_total[i]="$(echo "${energy_total[i]} + ${energy_input[i]}" | bc)"
        done
    done

    # Remove the tmp directory and print the totals.
    # rm -rd "$tmp_dir"
    echo "${energy_total[@]}"
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
    echo "$energy" > "$tmp_dir/rank_$rank.out"

    # Only rank 0 combines the results.
    if [ "$rank" -eq "0" ]; then
        # Wait for all result files, then gather values and remove the files.
        local energy_total=( $(gather_results "$tmp_dir") )

        # Get the events and print the values side-by-side.
        local events=$(perf_events)
        local event_array=()
        readarray -t event_array <<< "$events"

        # Find the longest event name for aligning the print.
        local max_len=0
        for event in "${event_array[@]}"; do
            (( ${#event} > max_len )) && max_len=${#event}
        done

        # Print events with collected values side by side.
        echo "Energy consumption:"
        for i in "${!event_array[@]}"; do
            printf "\t%-${max_len}s\t%s\n" "${event_array[$i]}:" \
                "${energy_total[$i]}"
        done
    fi
}
