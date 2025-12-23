#!/usr/bin/env sh
# ------------------------------------------------------------------------------
# This file contains MPI utils for gathering output from multiple ranks.
# ------------------------------------------------------------------------------

# Get the directory where this file is located to load dependencies.
UTILSDIR="$SRCDIR/utils"
. "$UTILSDIR/general_utils.sh"
. "$UTILSDIR/print_utils.sh"
. "$UTILSDIR/array_utils.sh"

# Gather all collected results and delete the temporary directory.
# Reports the energy for all events as a newline-separated string.
#   NOTE: This function should only be called by rank 0!
_gather_results() {
    tmp_dir="$1"
    num_ranks=${OMPI_COMM_WORLD_SIZE:-${PMI_SIZE:-${SLURM_NTASKS:-1}}}
    file_count=0

    # Wait for all files to appear.
    while true; do
        file_count=$(find "$tmp_dir" -maxdepth 1 -type f | wc -l)
        if [ "$file_count" -ge "$num_ranks" ]; then
            break
        fi
        sleep 0.5
    done

    # Merge the energy logs into one, starting by own file.
    energy_total=$(cat "$tmp_dir/rank_0.out")
    mpi_total_energy=""
    while IFS= read -r line; do
        mpi_total_energy=$(array_push "$mpi_total_energy" "$line")
    done <<EOF
$energy_total
EOF

    # Aggregate the collecting values of all ranks.
    i=1
    while [ "$i" -lt "$num_ranks" ]; do
        energy_input=$(cat "$tmp_dir/rank_$((i - 1)).out")

        # Aggregate the values of this rank for each event.
        j=0
        while IFS= read -r line; do
            cur_energy=$(array_get "$mpi_total_energy" "$j")

            # If input is text, set total to that string.
            if ! is_numerical "$line"; then
                mpi_total_energy=$(array_set "$mpi_total_energy" "$j" "$line")
            # Only perform addition if current total value is not a string.
            elif is_numerical "$cur_energy"; then
                mpi_total_energy=$(array_set "$mpi_total_energy" "$j" \
                    "$(echo "$cur_energy + $line" | bc -l)")
            fi

            j=$((j + 1))
        done <<EOF
$energy_input
EOF

        i=$((i + 1))
    done

    # Remove the tmp directory.
    rm -rd "$tmp_dir"

    # Print the totals as a newline-separated string.
    array_foreach "$mpi_total_energy" print_argument
}

# Profile given application with multiple ranks, if configured. Combine partial
# energy consumption numbers and sum to total. Also works when called with one
# process.
#   Usage:      mpi_combine <labels> <energy_values>
mpi_combine() {
    # Name input.
    labels="$1"
    energy="$2"

    # Get job and rank ID for temporary files.
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
        # If in parallel, wait for results, gather values, and remove tmp files.
        if [ "$job" != "<NO JOB>" ]; then
            energy_total=$(_gather_results "$tmp_dir")
        else
            energy_total=$energy
        fi

        # Find the longest label name for aligned printing.
        max_len=$(get_max_len "$labels")

        # Print labels with collected values side by side.
        zip_strings "$labels" "$energy_total" |
        while IFS=' ' read -r event energy; do
            if is_numerical "$energy"; then
                printf "%-${max_len}s  %s J\n" "$event" "$energy"
            else
                printf "%-${max_len}s  %s\n" "$event" "$energy"
            fi
        done
    fi
}
