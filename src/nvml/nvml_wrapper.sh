#!/usr/bin/env sh
# ------------------------------------------------------------------------------
# This wrapper contains functions for interacting with the NVML energy
# profiling for NVIDIA GPUs.
# ------------------------------------------------------------------------------

# Get the directory where this file is located to load dependencies.
NVMLDIR="$SRCDIR/nvml"
. "$NVMLDIR/../utils/general_utils.sh"
. "$NVMLDIR/../utils/print_utils.sh"

NVML_PROFILER="$NVMLDIR/nvml_profiler.o"


# Returns 0 if papi is available, 1 otherwise.
nvml_available() {
    verbose_echo print_info "Checking for nvidia-smi availability.."

    # Check if the papi_avail command is available.
    if ! function_exists nvidia-smi; then
        printf "1\n"
        return 1
    fi

    printf "0\n"
    return 0
}

_compile_nvml_profiler() {
    # Check if the binary exists.
    if [ -f "$NVML_PROFILER" ]; then
        # If exists, check for executable rights and rebuild if not.
        if [ -x "$NVML_PROFILER" ]; then
            return
        else
            rm "$NVML_PROFILER"
        fi
    fi

    # Compile the code.
    if ! cc -I/usr/local/cuda/include "$NVMLDIR/nvml_profiler.c" -o "$NVML_PROFILER" -lnvidia-ml -Wall; then
        print_error "Error while compiling $(basename "$NVML_PROFILER"), exiting.."
        exit 1
    fi

    # Make binary executable.
    if ! chmod +x "$NVML_PROFILER"; then
        print_error "Error during 'chmod +x $(basename "$NVML_PROFILER")', exiting.."
        exit 1
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
    nvml_header=$(echo '#include <nvml.h>' | gcc -E -I/usr/local/cuda/include - >/dev/null && echo "Found" || echo "Not found")
    if [ "$nvml_header" = "Not found" ]; then
        print_error "Cannot find nvml.h, is the required module loaded?"
        return 1
    fi

    # Make sure the papi_profiler is updated and compiled.
    verbose_echo print_info "Compiling nvml_profiler.c.."
    _compile_nvml_profiler

    # Profile binary with supported events.
    verbose_echo print_into "Executing profiler"
    "$NVML_PROFILER" "$@"
}
