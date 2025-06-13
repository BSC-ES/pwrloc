#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# This application is a wrapper for listing and using energy profilers available
# to the system.
# Usage of the program can be seen in the show_help() function.
# ------------------------------------------------------------------------------

# Get the directory where this file is located to load dependencies.
BASEDIR=$(cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd)

# Import functions from utils and the tool wrappers.
. "$BASEDIR/utils.sh"
. "$BASEDIR/slurm_wrapper.sh"
. "$BASEDIR/perf_wrapper.sh"

# Show how to use this program.
show_help() {
    cat << EOF
Usage: $(basename "$0") [-p profiler][-l] [-v] [--] [bin] [args]

Options:
  -p profiler   Profile using provided profiler
  -l            List availability of the supported profilers
  -v            Enable verbose mode
  -h            Show this help message and exit

Application:
  [bin] [args]  Application (with arguments) to profile.
                SLURM notes:
                    - [bin] should be a SLURM job id.
                    - The dependency job id will be used if [bin] is not given.

Example:
  $(basename "$0") -p slurm <slurm_job_id>
  $(basename "$0") -p ear echo "Hello world"
  $(basename "$0") -p ear -- echo "Foo Bar rules!"
EOF
}

# Show the setup after parsing the arguments.
show_setup() {
    # Show setup in case of a verbose execution.
    verbose_echo "========== SETUP =========="
    verbose_echo "profiler = $profiler"
    verbose_echo "list_profilers = $list_profilers"
    verbose_echo "VERBOSE = $VERBOSE"
    verbose_echo "bin = $bin"
    verbose_echo "args = $args"
    verbose_echo "======== END SETUP ========\n"
}

# Show info on the availability and setup of the supported profilers.
show_profilers() {
    # Fetch and print SLURM variables.
    local slurm_avail=$(slurm_available)
    local slurm_ptype=$(slurm_profiler_type)
    local slurm_pfreq=$(slurm_profiler_freq)
    echo -e "========== SLURM =========="
    echo "slurm_avail: $(bool_to_text $slurm_avail)"
    echo "slurm_ptype: $slurm_ptype"
    echo -e "slurm_pfreq: $slurm_pfreq\n"

    # Fetch and print perf variables.
    echo -e "========== PERF ==========="
    local perf_avail=$(perf_available)
    local perf_events=$(perf_events)
    echo "perf_avail: $(bool_to_text $perf_avail)"  # TODO: No integer?
    echo "perf_events:"
    echo "$perf_events" | awk '{print "\t" $0}'
}

# Main entry point for wrapper, containing argument parser.
main() {
    # Show help if no arguments are given.
    [ $# -eq 0 ] && show_help && exit 1

    # Default values.
    local profiler=""
    local list_profilers=0
    export VERBOSE=0

    # Parse options.
    while getopts ":p:lvh" opt; do
        case "$opt" in
            p) profiler="$OPTARG" ;;
            l) show_profilers; exit 1 ;;
            v) export VERBOSE=1 ;;
            h) show_help; exit 0 ;;
            :) echo "Option -$OPTARG requires an argument." >&2; exit 1 ;;
            \?) echo "Invalid option: -$OPTARG" >&2; exit 1 ;;
        esac
    done
    shift $((OPTIND - 1))

    # Parse binary and arguments to profile, if profiler is set.
    if [ -n "$1" ]; then
        local bin="$1"
        shift
        local args="$@"
    elif [ -n "$profiler" ]; then
        # Check if a job id was passed as dependency for SLURM profiling.
        if [ "$profiler" == "slurm" ]; then
            local bin=$(echo "$SLURM_JOB_DEPENDENCY" | awk -F':' '{print $2}')

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
            #  >/dev/null 2>&1
            if [[ "$slurm_available" == "1" ]]; then
                print_error "SLURM energy accounting is not available."
                exit 1
            fi
            slurm_profile "$bin"
            ;;
        perf)
            # Validate perf availability.
            if [[ "$perf_available" == "1" ]]; then
                print_error "perf is not available."
                exit 1
            fi
            perf_profile "$bin" "$args"
            ;;
        likwid)
            # Validate LIKWID availability.
            # TODO
            ;;
        ear)
            # Validate EAR availability.
            # TODO
            ;;
        "") # Variable not set.
            ;;
        *)
            echo "Invalid profiler: $profiler"
            echo "Valid profilers: slurm|likwid|ear"
            exit 1
            ;;
    esac
}

main "$@"
