#!/usr/bin/env sh
# ------------------------------------------------------------------------------
# This application is a wrapper for listing and using energy profilers available
# to the system.
# Usage of the program can be seen in the show_help() function.
# ------------------------------------------------------------------------------

# Get the directory where this file is located to load dependencies.
SRCDIR=$(cd "$(dirname -- "$0")" >/dev/null 2>&1 && pwd)

# Import functions from utils and the tool wrappers.
. "$SRCDIR/nvml/nvml_wrapper.sh"
. "$SRCDIR/papi/papi_wrapper.sh"
. "$SRCDIR/perf/perf_wrapper.sh"
. "$SRCDIR/rocm/rocm_wrapper.sh"
. "$SRCDIR/slurm/slurm_wrapper.sh"
. "$SRCDIR/../tests/run_tests.sh"
. "$SRCDIR/utils/print_utils.sh"


# Show how to use this program.
show_help() {
    cat <<EOF
Usage: $(basename "$0") [-l] [-p profiler] [-v] [--] [bin] [args]

Options:
  -h            Show this help message and exit.
  -l            List availability of the supported profilers.
  -p profiler   Profile using provided profiler.
  -t            Run test suite.
  -v            Enable verbose mode.

Application:
  [bin] [args]  Application (with arguments) to profile.
                SLURM notes:
                    - [bin] should be a SLURM job id.
                    - The dependency job id will be used if [bin] is not given.

Example:
  $(basename "$0") -p slurm <slurm_job_id>
  $(basename "$0") -p perf echo "Hello world"
  $(basename "$0") -p perf -- echo "Foo Bar rules!"
EOF
}

# Show info on the availability and setup of the supported profilers.
show_profilers() {
    # Fetch and print SLURM variables.
    slurm_avail=$(slurm_available)
    if [ "$slurm_avail" -eq "0" ]; then
        slurm_ptype=$(slurm_profiler_type)
        slurm_pfreq=$(slurm_profiler_freq)
    fi
    printf "========== SLURM ==========\n"
    printf "slurm_avail: %s\n" "$(bool_to_text "$slurm_avail")"
    printf "slurm_ptype: %s\n" "$slurm_ptype"
    printf "slurm_pfreq: %s\n\n" "$slurm_pfreq"

    # Fetch and print PERF variables.
    perf_avail=$(perf_available)
    perf_events=$(perf_events)
    printf "========== PERF ===========\n"
    printf "perf_avail: %s\n" "$(bool_to_text "$perf_avail")"
    printf "%s\n" "perf_events:"
    printf "%s\n" "$perf_events" | awk '{print "\t" $0}'
    printf "\n"

    # Fetch and print PAPI variables.
    papi_avail=$(papi_available)
    papi_found_events=""
    if [ "$papi_avail" -eq 0 ]; then
        papi_found_events=$(papi_events)
    fi

    printf "========== PAPI ===========\n"
    printf "%s\n" "papi_avail: $(bool_to_text "$papi_avail")"
    if [ "$papi_avail" -eq 0 ]; then
        printf "papi_events:\n"
        printf "%s\n" "$papi_found_events" | awk '{print "\t" $0}'
    fi
    printf "\n"

    # Fetch and print NVML variables.
    nvml_avail=$(nvml_available)
    printf "%s\n" "========== NVML ==========="
    printf "nvml_avail: %s\n\n" "$(bool_to_text "$nvml_avail")"

    # Fetch and print NVML variables.
    rocm_avail=$(rocm_available)
    printf "%s\n" "========== ROCM ==========="
    printf "rocm_avail: %s\n\n" "$(bool_to_text "$rocm_avail")"
}

# Show the setup after parsing the arguments.
show_setup() {
    # Show setup in case of a verbose execution.
    verbose_echo "========== SETUP =========="
    verbose_echo "profiler = $profiler"
    verbose_echo "bin = $bin"
    verbose_echo "args = $args"
    verbose_echo "======== END SETUP ========\n"
}

# Main entry point for wrapper, containing argument parser.
main() {
    # Show help if no arguments are given.
    [ $# -eq 0 ] && show_help && exit 1

    # Default values.
    export VERBOSE=0
    profiler=""

    # Parse options.
    while getopts ":p:hltv" opt; do
        case "$opt" in
            h)
                show_help
                exit 0
                ;;
            l)
                show_profilers
                exit 0
                ;;
            p) profiler="$OPTARG" ;;
            t)
                run_test_suite
                exit 0
                ;;
            v) export VERBOSE=1 ;;
            :)
                echo "Option -$OPTARG requires an argument." >&2
                exit 1
                ;;
            \?)
                echo "Invalid option: -$OPTARG" >&2
                exit 1
                ;;
        esac
    done
    shift $((OPTIND - 1))

    # Parse binary and arguments to profile, if profiler is set.
    if [ -n "$1" ]; then
        bin="$1"
        shift
        args="$*"
    elif [ -n "$profiler" ]; then
        # Check if a job id was passed as dependency for SLURM profiling.
        if [ "$profiler" = "slurm" ]; then
            bin=$(echo "$SLURM_JOB_DEPENDENCY" | awk -F':' '{print $2}')

            if [ -z "$bin" ]; then
                print_error "Error: Missing jobid to profile." >&2
                show_help
                exit 1
            fi
        else
            print_error "Error: Missing application to profile." >&2
            show_help
            exit 1
        fi
    fi

    # Print the setup, if in VERBOSE mode.
    show_setup

    # Validate the profiler and profile the application afterwards.
    case "$profiler" in
        slurm)
            # Validate SLURM availability.
            # TODO: Test if this new check works!
            if [ "$(slurm_available)" = "1" ]; then
                print_error "SLURM energy accounting is not available."
                exit 1
            fi
            slurm_profile "$bin"
            ;;
        perf)
            # Validate PERF availability.
            if [ "$(perf_available)" = "1" ]; then
                print_error "Perf is not available."
                exit 1
            fi
            perf_profile "$bin" "$args"
            ;;
        papi)
            # Validate PAPI availability.
            if [ "$(papi_available)" = "1" ]; then
                print_error "PAPI is not available, is the module loaded?"
                exit 1
            fi
            papi_profile "$bin" "$args"
            ;;
        nvml)
            # Validate NVML availability.
            if [ "$(nvml_available)" = "1" ]; then
                print_error "nvidia-smi is not available, is the module loaded?"
                exit 1
            fi
            nvml_profile "$bin" "$args"
            ;;
        rocm)
            # Validate ROCM availability.
            if [ "$(rocm_available)" = "1" ]; then
                print_error "rocm-smi is not available, is the module loaded?"
                exit 1
            fi
            rocm_profile "$bin" "$args"
            ;;
        "") # Variable not set.
            ;;
        *)
            echo "Invalid profiler: $profiler"
            echo "Valid profilers: slurm|perf|papi|nvml|rocm"
            exit 1
            ;;
    esac
}

main "$@"
