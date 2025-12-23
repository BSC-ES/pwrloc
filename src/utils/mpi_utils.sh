#!/usr/bin/env sh
# ------------------------------------------------------------------------------
# This file contains MPI utils for gathering output from multiple ranks.
# ------------------------------------------------------------------------------

# Get the directory where this file is located to load dependencies.
UTILSDIR="$SRCDIR/utils"
. "$UTILSDIR/general_utils.sh"
. "$UTILSDIR/print_utils.sh"
. "$UTILSDIR/array_utils.sh"

# Aggregate results of the ranks through concatonation.
#   Supported data types:
#       - energy:       Gather energy values.
#       - labels:       Gather labels.
#   Usage:      _aggregate_concatenate  <mpi_total_array> <dtype>
_aggregate_concatenate() {
    mpi_total_array="$1"
    dtype="$2"
    num_ranks=${OMPI_COMM_WORLD_SIZE:-${PMI_SIZE:-${SLURM_NTASKS:-1}}}

    # Setup array with data from rank 0.
    rank0_data=$(cat "$tmp_dir/rank_0_$dtype.out")
    mpi_total_array=""
    while IFS= read -r line; do
        mpi_total_array=$(array_push "$mpi_total_array" "$line")
    done <<EOF
$rank0_data
EOF

    # Aggregate the collected values of all ranks.
    i=1
    while [ "$i" -lt "$num_ranks" ]; do
        rank_input=$(cat "$tmp_dir/rank_$((i - 1))_$dtype.out")

        # Aggregate the values of this rank for each event.
        j=0
        while IFS= read -r line; do
            mpi_total_array=$(array_push "$mpi_total_array" "$line")
            j=$((j + 1))
        done <<EOF
$rank_input
EOF

        i=$((i + 1))
    done

    printf "%s\n" "$mpi_total_array"
}

# Aggregate results of the ranks through addition.
#   Supported data types:
#       - energy:       Gather energy values.
#       - labels:       Gather labels.
#   Usage:      _aggregate_combine  <mpi_total_array> <dtype>
_aggregate_combine() {
    mpi_total_array="$1"
    dtype="$2"
    num_ranks=${OMPI_COMM_WORLD_SIZE:-${PMI_SIZE:-${SLURM_NTASKS:-1}}}

    # Setup array with data from rank 0.
    rank0_data=$(cat "$tmp_dir/rank_0_$dtype.out")
    mpi_total_array=""
    while IFS= read -r line; do
        mpi_total_array=$(array_push "$mpi_total_array" "$line")
    done <<EOF
$rank0_data
EOF

    # Aggregate the collected values of all ranks.
    i=1
    while [ "$i" -lt "$num_ranks" ]; do
        rank_input=$(cat "$tmp_dir/rank_$((i - 1))_$dtype.out")

        # Aggregate the values of this rank for each event.
        j=0
        while IFS= read -r line; do
            cur_energy=$(array_get "$mpi_total_array" "$j")

            # If input is text, set total to that string.
            if ! is_numerical "$line"; then
                mpi_total_array=$(array_set "$mpi_total_array" "$j" "$line")
            # Only perform addition if current total value is not a string.
            elif is_numerical "$cur_energy"; then
                mpi_total_array=$(array_set "$mpi_total_array" "$j" \
                    "$(echo "$cur_energy + $line" | bc -l)")
            fi

            j=$((j + 1))
        done <<EOF
$rank_input
EOF

        i=$((i + 1))
    done

    printf "%s\n" "$mpi_total_array"
}

# Gather all collected results, delete the temporary directory, and print total
# values.
#   NOTE: This function should only be called by rank 0!
#   Supported modes:
#       - combine:      Add up values at the same index for all ranks.
#       - concatenate:  Concatenate results of all ranks and print in order.
#   Supported data types:
#       - energy:       Gather energy values.
#       - labels:       Gather labels.
#   Usage:      _gather_ranks <mode> <data_type> <tmp_dir>
_gather_ranks() {
    # Set mode.
    mode="$1"
    dtype="$2"

    # Check if mode and dtype are valid.
    if [ "$mode" != "combine" ] && [ "$mode" != "concatenate" ]; then
        print_error "<mpi_utils> _gather_ranks called with illegal mode."
        exit 1
    elif [ "$dtype" != "energy" ] && [ "$dtype" != "labels" ]; then
        print_error "<mpi_utils> _gather_ranks called with illegal dtype."
        exit 1
    fi

    # Setup collection of results.
    tmp_dir="$3"
    num_ranks=${OMPI_COMM_WORLD_SIZE:-${PMI_SIZE:-${SLURM_NTASKS:-1}}}
    file_count=0

    # Number of files is twice the rank in case of collect
    [ "$mode" = "combine" ] && num_files="$num_ranks"
    [ "$mode" = "concatenate" ] && num_files=$((num_ranks * 2))

    # Wait for all files to appear.
    while true; do
        file_count=$(find "$tmp_dir" -maxdepth 1 -type f | wc -l)
        if [ "$file_count" -ge "$num_files" ]; then
            break
        fi
        sleep 0.5
    done

    # Aggregate through addition if mode is combine, otherwise concatenate.
    if [ "$mode" = "combine" ]; then
        mpi_total_array=$(_aggregate_combine "$mpi_total_array")
    else
        mpi_total_array=$(_aggregate_concatenate "$mpi_total_array")
    fi

    # Print the totals as a newline-separated string.
    array_foreach "$mpi_total_array" print_argument
}

# Combine partial energy consumption numbers and sum to total.
# Also works when called with one process.
#   Supported modes:
#       - combine:      Add up values at the same index for all ranks.
#       - concatenate:  Concatenate results of all ranks and print in order.
#   Usage:      mpi_gather <mode> <labels> <energy_values>
mpi_gather() {
    # Name input.
    mode="$1"
    labels="$2"
    energy="$3"

    # Get job and rank ID for temporary files.
    job=${SLURM_JOB_ID:-${PBS_JOBID:-${JOB_ID:-"<NO JOB>"}}}
    rank=${OMPI_COMM_WORLD_RANK:-${PMI_RANK:-${SLURM_PROCID:-${MPI_RANK:-0}}}}

    # Only write tmp files if job detected.
    if [ "$job" != "<NO JOB>" ]; then
        tmp_dir="tmp.$job"
        mkdir -p "$tmp_dir"
        printf "%s\n" "$energy" >"$tmp_dir/rank_${rank}_energy.out"

        # Only store labels if in concatenate mode.
        if [ "$mode" = "concatenate" ]; then
            printf "%s\n" "$labels" >"$tmp_dir/rank_${rank}_labels.out"
        fi
    fi

    # Only rank 0 combines the results.
    if [ "$rank" -eq "0" ]; then
        # If in parallel, wait for results, gather values, and remove tmp files.
        if [ "$job" != "<NO JOB>" ]; then
            energy_total=$(_gather_ranks "$mode" "energy" "$tmp_dir")

            # Overwrite labels if mode is concatenate.
            if [ "$mode" = "concatenate" ]; then
                labels=$(_gather_ranks "$mode" "labels" "$tmp_dir")
            fi

            # Remove the tmp directory.
            rm -rd "$tmp_dir"
        else
            energy_total=$energy
        fi

        # Find the longest label name for aligned printing.
        max_len=$(get_max_len "$labels")

        # Print header for energy measurements.
        print_full_width "=" "22"
        print_centered "Energy Consumption" "22"
        print_full_width "=" "22"

        # Print labels with collected values side by side.
        zip_strings "$labels" "$energy_total" |
        while IFS=' ' read -r event energy; do
            if is_numerical "$energy"; then
                printf "%-${max_len}s  %s J\n" "$event" "$energy"
            else
                printf "%-${max_len}s  %s\n" "$event" "$energy"
            fi
        done

        # Print footer for energy measurements.
        print_full_width "=" "22"
    fi
}
