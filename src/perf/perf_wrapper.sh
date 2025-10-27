# ------------------------------------------------------------------------------
# This wrapper contains functions for interacting with the perf stat energy
# events.
# ------------------------------------------------------------------------------

# Get the directory where this file is located to load dependencies.
PERFDIR="$BASEDIR/perf"
. "$PERFDIR/../utils/general_utils.sh"
. "$PERFDIR/../utils/print_utils.sh"

# Returns 0 if perf is available, 1 otherwise.
perf_available() {
    verbose_echo print_info "Checking for perf availability.."

    # Check if the perf command is available.
    if ! function_exists perf; then
        printf "1\n"
        return 1
    fi

    printf "0\n"
    return 0
}

# Wrapper function for the pipeline of getting perf energy events.
_perf_get_energy_events() {
    perf list | grep energy | awk '{print $1}'
}

# Returns the sample frequency.
perf_events() {
    local events
    local errors
    local tmpfile

    # Create a temp file for stderr.
    tmpfile=$(mktemp 2>/dev/null || echo "/tmp/catch.$$")
    events=$(_perf_get_energy_events 2>"$tmpfile")
    errors=$(cat "$tmpfile")
    rm "$tmpfile"

    # Print found events.
    if [ -z "$events" ]; then
        printf "NO EVENTS AVAILABLE\n"
    else
        printf "%s\n" "$events"
    fi

    # Print potential errors if in verbose mode.
    if [ -n "$errors" ]; then
        verbose_echo print_warning "<perf_events> $errors"
    fi
}

# Get the consumed energy for this rank (which can be total execution).
_get_energy_consumed() {
    local events perf_stat_events perf_out energy

    # Get events.
    events=$(perf_events)
    perf_stat_events=$(echo "$events" | awk '{print " -e " $0}')
    perf_stat_events=$(echo "$perf_stat_events" | tr '\n' ' ')

    # Profile the binary with perf and store in stdout.
    # TODO: What are $bin and $args doing here??? Variables??
    perf_out=$(perf stat -e "$perf_stat_events" -- "$bin" "$args" 2>&1)

    # Extract the energy values from the perf output.
    energy=$(echo "$perf_out" | sed -n 's/^\(.*\) Joules.*/\1/p')

    # Strip whitespaces from the numbers.
    energy=$(echo "$energy" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')

    # Throw warning in verbose mode if perf signifies not supported.
    if printf "%s\n" "$energy" | grep -q '<not supported>'; then
        verbose_echo print_warning \
            "'<not supported>' found, is perfparanoid correctly set?"
    fi

    printf "%s\n" "$energy"
}

# Reads energy values from given file and prints them sanitized.
_sanitize_energy_values() {
    local energy_input
    energy_input=$(cat "$1")
    readarray -t energy_array <<<"$energy_input"

    # Replace any non-numerical items with 0 as fallback.
    for i in "${!energy_array[@]}"; do
        if ! is_numerical "${energy_array[i]}"; then
            energy_array[i]=0
        fi
    done
    printf "%s\n" "${energy_array[@]}"
}

# Gather all collected results and delete the temporary directory.
#   !! This function should only be called by rank 0. !!
_gather_results() {
    local tmp_dir="$1"
    local num_ranks=${OMPI_COMM_WORLD_SIZE:-${PMI_SIZE:-${SLURM_NTASKS:-1}}}
    local file_count=0

    # Wait for all files to appear.
    while true; do
        file_count=$(find "$tmp_dir" -maxdepth 1 -type f | wc -l)
        if ((file_count >= num_ranks)); then
            break
        fi
        sleep 0.5
    done

    # Merge the energy logs into one, starting by own file.
    local energy_total=($(_sanitize_energy_values "$tmp_dir/rank_0.out"))
    local energy_input=()

    for ((i = 2; i <= num_ranks; i++)); do
        energy_input=($(_sanitize_energy_values "$tmp_dir/rank_$((i - 1)).out"))
        for j in "${!energy_input[@]}"; do
            energy_total[j]="$(echo "${energy_total[j]} + ${energy_input[j]}" | bc)"
        done
    done

    # Remove the tmp directory and print the totals.
    rm -rd "$tmp_dir"
    echo "${energy_total[@]}"
}

# Profile given application with perf and return the total consumed energy.
perf_profile() {
    # Acquire energy consumed for this rank (or total execution without MPI).
    energy=$(_get_energy_consumed)

    # Get job and rank ID and write to output file.
    local job=${SLURM_JOB_ID:-${PBS_JOBID:-${JOB_ID:-"r$RANDOM"}}}
    local rank=${OMPI_COMM_WORLD_RANK:-${PMI_RANK:-${SLURM_PROCID:-${MPI_RANK:-0}}}}
    local tmp_dir="tmp.$job"
    mkdir -p "$tmp_dir"
    printf "%s\n" "$energy" >"$tmp_dir/rank_$rank.out"

    # Only rank 0 combines the results.
    if [ "$rank" -eq "0" ]; then
        local energy_total events event_array max_len

        # Wait for all result files, then gather values and remove the files.
        energy_total=($(_gather_results "$tmp_dir"))

        # Get the events and print the values side-by-side.
        events=$(perf_events)
        event_array=()
        readarray -t event_array <<<"$events"

        # Find the longest event name for aligning the print.
        max_len=0
        for event in "${event_array[@]}"; do
            ((${#event} > max_len)) && max_len=${#event}
        done

        # Print events with collected values side by side.
        for i in "${!event_array[@]}"; do
            printf "%-${max_len}s %s J\n" "${event_array[$i]}" \
                "${energy_total[$i]}"
        done
    fi
}
