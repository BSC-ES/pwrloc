#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# This wrapper contains functions for interacting with the SLURM energy 
# accounting subsystem.
# ------------------------------------------------------------------------------

# Get the directory where this file is located to load dependencies.
BASEDIR="$(cd "$(dirname "$0")" && pwd)"

. "$BASEDIR/utils.sh"

# Returns 0 if SLURM is available, 1 otherwise.
function slurm_available() {
    verbose_echo "Checking for SLURM availability.."
}