#!/usr/bin/env sh
# ------------------------------------------------------------------------------
# This wrapper contains functions for interacting with the NVML energy
# profiling for NVIDIA GPUs.
# ------------------------------------------------------------------------------

# Get the directory where this file is located to load dependencies.
NVMLDIR="$SRCDIR/nvml"
. "$NVMLDIR/../utils/general_utils.sh"
. "$NVMLDIR/../utils/print_utils.sh"

NVML_PROFILER_NAME="nvml_profiler.o"
NVML_PROFILER="$NVMLDIR/$NVML_PROFILER_NAME"


# Returns 0 if nvml is available, 1 otherwise.
nvml_available() {
    verbose_echo print_info "Checking for nvidia-smi availability.."

    # Check if the nvidia-smi command is available.
    if ! function_exists nvidia-smi; then
        printf "1\n"
        return 1
    fi

    printf "0\n"
    return 0
}

_compile_nvml_profiler() {
    # Return if profiler exists and is executable.
    if [ -x "$NVML_PROFILER" ]; then
        verbose_echo print_info "$NVML_PROFILER_NAME is already compiled."
        return
    fi

    # Recompile profiler with rank 0, and let other ranks wait.
    if [ "$RANK" -eq "0" ]; then
        verbose_echo print_info "Compiling ${NVML_PROFILER_NAME}.."

        # Remove profiler binary if it exists but isn't executable.
        if [ -f "$NVML_PROFILER" ]; then
            rm "$NVML_PROFILER"
        fi

        # Compile the code.
        if ! cc -I/usr/local/cuda/include "$NVMLDIR/nvml_profiler.c" \
                -o "$NVML_PROFILER" -lnvidia-ml -Wall; then
            print_error \
                "Error while compiling $(basename "$NVML_PROFILER"), exiting.."
            exit 1
        fi

        # Make binary executable.
        if ! chmod +x "$NVML_PROFILER"; then
            print_error \
                "Error during 'chmod +x $(basename "$NVML_PROFILER")', exiting.."
            exit 1
        fi
    else
        # Rank > 0 wait till profiler exists.
        verbose_echo print_info "Waiting for rank 0 to compile profiler.."
        while [ ! -x "$NVML_PROFILER" ]; do
            sleep 0.2
        done
    fi
}

# Profile the provided binary with NVML.
nvml_profile() {
    # Make sure nvidia-smi is available.
    if ! nvml_available >/dev/null 2>&1; then
        print_error "nvidia-smi is not available."
        return
    fi

    # Check if the nvml.h library is found.
    nvml_header=$(\
        echo '#include <nvml.h>' | \
        gcc -E -I/usr/local/cuda/include - >/dev/null \
            && echo "Found" \
            || echo "Not found"
    )
    if [ "$nvml_header" = "Not found" ]; then
        print_error "Cannot find nvml.h, is the required module loaded?"
        return 1
    fi

    # Make sure the NVML profiler is compiled.
    _compile_nvml_profiler

    # Compute the number of nodes using all ranks.
    num_nodes=$(mpi_get_num_nodes)

    # NVML profiles the entire node, thus only the first rank per node needs to
    # profile.
    if [ "$LOCAL_RANK" -eq "0" ]; then
        # Collect measurements with NVML.
        verbose_echo print_info "Executing profiler"
        output=$("$NVML_PROFILER" "$@")

        # Split output in labels and energies, then merge MPI ranks.
        labels=$(printf '%s\n' "$output" | awk '{print $1}')
        energies=$(printf '%s\n' "$output" | awk '{print $2}')
        mpi_gather "$MPI_MODE" "$num_nodes" "$labels" "$energies"
    else
        verbose_echo print_info "Local rank > 0, so exiting.."
    fi
}
