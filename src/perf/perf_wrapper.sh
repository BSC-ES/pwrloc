#!/usr/bin/env sh
# ------------------------------------------------------------------------------
# This wrapper contains functions for interacting with the perf stat energy
# events.
# ------------------------------------------------------------------------------

# Get the directory where this file is located to load dependencies.
PERFDIR="$SRCDIR/perf"
. "$PERFDIR/../utils/general_utils.sh"
. "$PERFDIR/../utils/print_utils.sh"
. "$PAPIDIR/../utils/stack_utils.sh"


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
#   Usage:      _get_energy_consumed <bin> <args>
_get_energy_consumed() {
    # Get events.
    events=$(perf_events)
    perf_stat_events=$(echo "$events" | awk '{print " -e " $0}')
    perf_stat_events=$(echo "$perf_stat_events" | tr '\n' ' ')

    # Profile the binary with perf and store in stdout.
    perf_out=$(perf stat -e "$perf_stat_events" -- "$@" 2>&1)

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
    energy_input=$(cat "$1")

    # Replace any non-numerical items with 0 as fallback.
    printf '%s\n' "$energy_input" \
    | while IFS= read -r line; do
        if is_numerical "$line"; then
            printf '%s\n' "$line"
        else
            printf '0\n'
        fi
    done
}

# Gather all collected results and delete the temporary directory.
# Reports the energy for all events as a newline-separated string.
#   !! This function should only be called by rank 0. !!
_gather_results() {
    tmp_dir="$1"
    num_ranks=${OMPI_COMM_WORLD_SIZE:-${PMI_SIZE:-${SLURM_NTASKS:-1}}}
    file_count=0

    # Throw error if no number of ranks detected.
    if [ "$num_ranks" -eq -1 ]; then
        print_error \
            "<_gather_results> No ranks found to merge PERF energy values."
        printf "\n"
        return 1
    fi

    # Wait for all files to appear.
    while true; do
        file_count=$(find "$tmp_dir" -maxdepth 1 -type f | wc -l)
        if [ "$file_count" -ge "$num_ranks" ]; then
            break
        fi
        sleep 0.5
    done

    # Merge the energy logs into one, starting by own file.
    energy_total=$(_sanitize_energy_values "$tmp_dir/rank_0.out")
    stack_create "perf_total_energy"
    printf '%s\n' "$energy_total" \
    | while IFS= read -r line; do
        stack_push "perf_total_energy" "$line"
    done

    # Aggregate the collecting values of all ranks.
    i=1
    while [ "$i" -lt "$num_ranks" ]; do
        energy_input=$(_sanitize_energy_values "$tmp_dir/rank_$((i - 1)).out")

        # Aggregate the values of this rank for each event.
        j=0
        printf '%s\n' "$energy_input" \
        | while IFS= read -r line; do
            cur_energy=$(stack_get "perf_total_energy" "$j")
            stack_set "perf_total_energy" "$j" \
                "$(echo "$cur_energy + $line" | bc -l)"
            j=$((j + 1))
        done

        i=$((i + 1))
    done

    # Remove the tmp directory.
    rm -rd "$tmp_dir"

    # Print the totals as a newline-separated string.
    stack_foreach "perf_total_energy" "printf '%s\n'"

    # Clean up.
    stack_destroy "perf_total_energy"
}

# Profile given application with perf and return the total consumed energy.
# The function is made to be executed by multiple processes concurrently.
perf_profile() {
    # Acquire energy consumed for this rank (or total execution without MPI).
    energy=$(_get_energy_consumed "$@")

    # Get job and rank ID and write to output file.
    job=${SLURM_JOB_ID:-${PBS_JOBID:-${JOB_ID:-"<NO JOB>"}}}
    rank=${OMPI_COMM_WORLD_RANK:-${PMI_RANK:-${SLURM_PROCID:-${MPI_RANK:-0}}}}

    # Only write tmp files if job detected.
    if [ "$job" != "<NO JOB>" ]; then
        tmp_dir="tmp.$job"
        mkdir -p "$tmp_dir"
        printf "%s\n" "$energy" >"$tmp_dir/rank_$rank.out"
    fi

    # Only rank 0 combines the results.
    if [ "$rank" -eq "0" ]; then
        # If job detected, wait for results, gather values, and remove files.
        if [ "$job" != "<NO JOB>" ]; then
            energy_total=$(_gather_results "$tmp_dir")
        else
            energy_total=$energy
        fi

        # Get the events and print the values side-by-side.
        events=$(perf_events)

        # Find the longest event name for aligning the print.
        max_len=0
        while IFS= read -r event; do
            len=$(printf '%s' "$event" | wc -c)
            [ "$len" -gt "$max_len" ] && max_len=$len
        done <<EOF
$events
EOF

        # Print events with collected values side by side.
        zip_strings "$events" "$energy_total" |
        while IFS=' ' read -r event energy; do
            printf "%-${max_len}s %s J\n" "$event" "$energy"
        done
    fi
}
