#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# This wrapper contains functions for interacting with the LIKWID energy 
# profiling options.
# ------------------------------------------------------------------------------

# Get the directory where this file is located to load dependencies.
LIKWID_DIR="$(cd "$(dirname "$0")" && pwd)"

. "$LIKWID_DIR/utils.sh"

