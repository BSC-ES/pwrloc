#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# This wrapper contains functions for interacting with the LIKWID energy 
# profiling options.
# ------------------------------------------------------------------------------

# Get the directory where this file is located to load dependencies.
BASEDIR=$(cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd)
. "$BASEDIR/utils.sh"
