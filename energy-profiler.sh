#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# This application is a wrapper for listing and using energy profilers available
# to the system.
# Usage of the program can be seen in the show_help() function.
# ------------------------------------------------------------------------------

# Get the directory where this file is located to load dependencies.
BASEDIR="$(cd "$(dirname "$0")" && pwd)"

# Import functions from utils and the tool wrappers.
. "$BASEDIR/utils.sh"
. "$BASEDIR/slurm_wrapper.sh"

# Show how to use this program.
show_help() {
    cat << EOF
Usage: $(basename "$0") [-p PROFILER][-l] [-v] [--] [bin] [args]

Options:
  -p PROFILER   Specify input file
  -l            List available profilers
  -v            Enable verbose mode
  -h            Show this help message and exit

Application:
  [bin] [args]  Application (with arguments) to profile

Example:
  $(basename "$0") -p slurm echo "Hello world"
  $(basename "$0") -p slurm -- echo "Foo Bar rules!"
EOF
}

# Show the setup after parsing the arguments.
show_setup() {
    # Show setup in case of a verbose execution.
    verbose_echo "========="
    verbose_echo "| SETUP |"
    verbose_echo print_full_width =
    verbose_echo "PROFILER = $PROFILER"
    verbose_echo "LIST_PROFILERS = $LIST_PROFILERS"
    verbose_echo "VERBOSE = $VERBOSE"
    verbose_echo "BIN = $BIN"
    verbose_echo "ARGS = $ARGS"
    verbose_echo print_full_width =
}

# Show info on the availability and setup of the supported profilers.
show_profilers() {
    # Fetch SLURM variables.
    SLURM_AVAIL=$(slurm_available)
    SLURM_PTYPE=$(slurm_profiler_type)
    SLURM_PFREQ=$(slurm_profiler_freq)
}

# Main entry point for wrapper, containing argument parser.
main() {
    # Show help if no arguments are given.
    [ $# -eq 0 ] && show_help && exit 1

    # Default values.
    PROFILER=""
    LIST_PROFILERS=0
    VERBOSE=0

    # Parse options.
    while getopts ":p:lvh" opt; do
        case "$opt" in
            p) PROFILER="$OPTARG" ;;
            l) LIST_PROFILERS=1 ;;
            v) export VERBOSE=1 ;;
            h) show_help; exit 0 ;;
            :) echo "Option -$OPTARG requires an argument." >&2; exit 1 ;;
            \?) echo "Invalid option: -$OPTARG" >&2; exit 1 ;;
        esac
    done
    shift $((OPTIND - 1))

    # Parse binary and arguments to profile, if profiler is set.
    if [ -n "$1" ]; then
        BIN="$1"
        shift
        ARGS="$@"
    elif [ -n "$PROFILER" ]; then
        echo "Error: Missing application to profile." >&2
        show_help
        exit 1
    fi

    # Print the setup, if in VERBOSE mode.
    show_setup

    # Validate the PROFILER and profile the application afterwards.
    case "$PROFILER" in
        slurm)
            # Validate SLURM availability.
            if ! slurm_available; then
                echo "SLURM energy accounting is not available."
                exit 1
            fi
            ;;
        likwid)
            # Validate LIKWID availability.
            # TODO
            ;;
        ear)
            # Validate EAR availability.
            # TODO
            ;;
        *)
            echo "Invalid profiler: $PROFILER"
            echo "Valid profilers: slurm|likwid|ear"
            exit 1
            ;;
    esac
}

main "$@"
