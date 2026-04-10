#!/usr/bin/env sh
# ------------------------------------------------------------------------------
# This file contains MPI utils for gathering output from multiple ranks.
# ------------------------------------------------------------------------------

# Get the directory where this file is located to load dependencies.
UTILSDIR="$SRCDIR/utils"
. "$UTILSDIR/general_utils.sh"
. "$UTILSDIR/print_utils.sh"
. "$UTILSDIR/array_utils.sh"

# Define globals for MPI related variables.
RANK=${OMPI_COMM_WORLD_RANK:-${PMI_RANK:-${SLURM_PROCID:-${MPI_RANK:-0}}}}
# shellcheck disable=SC2034
LOCAL_RANK=${OMPI_COMM_WORLD_LOCAL_RANK:-${MPI_LOCALRANKID:-${PMI_LOCAL_RANK:-${SLURM_LOCALID:-0}}}}
# shellcheck disable=SC2034
MPI_SIZE=${OMPI_COMM_WORLD_SIZE:-${PMI_SIZE:-${SLURM_NTASKS:-1}}}
JOB=${SLURM_JOB_ID:-${PBS_JOBID:-${JOB_ID:-"<NO JOB>"}}}


# Aggregate results of the ranks through concatonation.
#   Supported data types:
#       - energy:       Gather energy values.
#       - labels:       Gather labels.
#   Usage:      _aggregate_concatenate  <mpi_total_array> <num_procs> <dtype>
_aggregate_concatenate() {
    mpi_total_array="$1"
    num_procs="$2"
    dtype="$3"

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
    while [ "$i" -lt "$num_procs" ]; do
        # Aggregate the values of this rank for each event.
        rank_input=$(cat "$tmp_dir/rank_${i}_$dtype.out")
        while IFS= read -r line; do
            mpi_total_array=$(array_push "$mpi_total_array" "$line")
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
#   Usage:      _aggregate_combine  <mpi_total_array> <num_procs> <dtype>
_aggregate_combine() {
    mpi_total_array="$1"
    num_procs="$2"
    dtype="$3"

    # Get all filenames of $dtype and sort by rank.
    rank_files=$(find "$tmp_dir" -type f -name "rank_*_${dtype}.out" |
        awk -F'[_./]' '{print $(NF-2), $0}' |
        sort -n |
        cut -d' ' -f2-)

    # Setup array with data from the first rank and delete from list.
    first_rank_file=$(array_get "$rank_files" "0")
    first_rank_data=$(cat "$first_rank_file")
    mpi_total_array=""
    while IFS= read -r line; do
        mpi_total_array=$(array_push "$mpi_total_array" "$line")
    done <<EOF
$first_rank_data
EOF
    rank_files=$(array_delete "$rank_files" "0")

    # Loop over rank files and aggregate values.
    while IFS= read -r rank_file; do
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
$rank_file
EOF
    done <<EOF
$rank_files
EOF

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
#   Usage:      _gather_ranks <mode> <$num_procs> <data_type> <tmp_dir>
_gather_ranks() {
    # Set mode.
    mode="$1"
    num_procs="$2"
    dtype="$3"
    tmp_dir="$4"

    # Check if mode and dtype are valid.
    if [ "$mode" != "combine" ] && [ "$mode" != "concatenate" ]; then
        print_error "<mpi_utils> _gather_ranks called with illegal mode."
        exit 1
    elif [ "$dtype" != "energy" ] && [ "$dtype" != "labels" ]; then
        print_error "<mpi_utils> _gather_ranks called with illegal dtype."
        exit 1
    fi

    # Setup collection of results.
    file_count=0

    # Number of files is twice the number of ranks in case of concatenate mode,
    # as both labels and values are stored.
    [ "$mode" = "combine" ] && num_files="$num_procs"
    [ "$mode" = "concatenate" ] && num_files=$((num_procs * 2))

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
        mpi_total_array=$(
            _aggregate_combine "$mpi_total_array" "$num_procs" "$dtype"
        )
    else
        mpi_total_array=$(
            _aggregate_concatenate "$mpi_total_array" "$num_procs" "$dtype"
        )
    fi

    # Print the totals as a newline-separated string.
    array_foreach "$mpi_total_array" print_argument
}

# Combine partial energy consumption numbers and sum to total.
# Also works when called with one process.
#   Supported modes:
#       - combine:      Add up values at the same index for all ranks.
#       - concatenate:  Concatenate results of all ranks and print in order.
#   Usage:      mpi_gather <mode> <num_procs> <labels> <energy_values>
mpi_gather() {
    # Name input.
    mode="$1"
    num_procs="$2"
    labels="$3"
    energy="$4"

    # Store number of items per rank for printing in concatenate mode.
    items_per_rank=$(printf '%s\n' "$labels" | wc -l)

    # Only write tmp files if job detected.
    if [ "$JOB" != "<NO JOB>" ]; then
        tmp_dir="tmp.$JOB"
        mkdir -p "$tmp_dir"
        # TODO: Read loop is +=1, with Rank and per-node you get 0,2,etc. causing problems.
        printf "%s\n" "$energy" >"$tmp_dir/rank_${RANK}_energy.out"

        # Only store labels if in concatenate mode.
        if [ "$mode" = "concatenate" ]; then
            printf "%s\n" "$labels" >"$tmp_dir/rank_${RANK}_labels.out"
        fi
    fi

    # Only rank 0 combines the results.
    if [ "$RANK" -eq "0" ]; then
        # If in parallel, wait for results, gather values, and remove tmp files.
        if [ "$JOB" != "<NO JOB>" ]; then
            energy_total=$(
                _gather_ranks "$mode" "$num_procs" "energy" "$tmp_dir"
            )

            # Overwrite labels if mode is concatenate.
            if [ "$mode" = "concatenate" ]; then
                labels=$(_gather_ranks "$mode" "$num_procs" "labels" "$tmp_dir")
            fi

            # Remove the tmp directory.
            rm -rd "$tmp_dir"
        else
            energy_total=$energy
        fi

        # Find the longest label name for aligned printing.
        max_label_len=$(get_max_len "$labels")

        # Compute width of longest line, and cap on [18, 80] characters.
        max_energy_len=$(get_max_len "$energy")
        max_window_width=$((max_label_len + max_energy_len + 4))
        [ "$max_window_width" -lt "18" ] && max_window_width=18
        [ "$max_window_width" -gt "80" ] && max_window_width=80

        # Print header for energy measurements.
        print_full_width "=" "$max_window_width"
        print_centered "Energy Consumption" "$max_window_width"
        print_centered "by pwrloc" "$max_window_width"
        print_full_width "=" "$max_window_width"

        # Print labels with collected values side by side.
        i=0
        zip_strings "$labels" "$energy_total" |
            while IFS=' ' read -r event energy; do
                # Add headers for each rank if in concatenate mode.
                if [ "$mode" = "concatenate" ] \
                && [ $((i % items_per_rank)) -eq 0 ]; then
                    [ $((i / items_per_rank)) -gt 0 ] && printf "\n"
                    printf "Rank %s:\n" $((i / items_per_rank))
                fi

                # Omit Joules postfix if value not numerical.
                if is_numerical "$energy"; then
                    printf "%-${max_label_len}s  %s J\n" "$event" "$energy"
                else
                    printf "%-${max_label_len}s  %s\n" "$event" "$energy"
                fi

                i=$((i + 1))
            done

        # Print footer for energy measurements.
        print_full_width "=" "$max_window_width"
    fi
}

# Get the number of nodes in use.
mpi_get_num_nodes() {
    # Return 1 if MPI is not in use.
    if [ "$JOB" = "<NO JOB>" ]; then
        printf "1\n"
        return
    fi

    # Create tmp dir and let every rank write their local rank id.
    tmp_dir_num_nodes="tmp.$JOB/num_nodes"
    mkdir -p "$tmp_dir_num_nodes"
    touch "$tmp_dir_num_nodes/${RANK}_${LOCAL_RANK}.tmp"

    # Wait for all files to be written.
    while true; do
        file_count=$(find "$tmp_dir_num_nodes" -maxdepth 1 -type f | wc -l)
        if [ "$file_count" -ge "$MPI_SIZE" ]; then
            break
        fi
        sleep 0.5
    done

    # Count the number of files named 0.tmp and write confirm file.
    node_count=$(
        find "$tmp_dir_num_nodes" -type f -name '*0.tmp' | wc -l | tr -d ' '
    )
    touch "$tmp_dir_num_nodes/sync.${RANK}"

    # Sync with all processes and perform cleanup.
    if [ "$RANK" -eq "0" ]; then
        # If rank 0, wait for all files to be present, and remove everything.
        while true; do
            file_count=$(find "$tmp_dir_num_nodes" -maxdepth 1 -type f | wc -l)
            if [ "$file_count" -ge "$((MPI_SIZE * 2))" ]; then
                break
            fi
            sleep 0.5
        done

        # Let the folder itself exist as it will be removed during MPI clean up.
        rm -rf "$tmp_dir_num_nodes/"
    else
        # If rank > 0, wait for num_nodes dir to be removed.
        while [ -d "$tmp_dir_num_nodes" ]; do
            sleep 0.5
        done
    fi

    # Print number of nodes.
    printf "%s\n" "$node_count"
}
