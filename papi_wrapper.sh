#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# This wrapper contains functions for interacting with the PAPI energy 
# profiling options.
# ------------------------------------------------------------------------------

# Get the directory where this file is located to load dependencies.
BASEDIR=$(cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd)
. "$BASEDIR/utils.sh"

PAPI_PROFILER="$BASEDIR/papi_profiler.o"

# Returns 0 if papi is available, 1 otherwise.
papi_available() {
    verbose_echo print_info "Checking for papi availability.."

    # Check if the papi_avail command is available.
    if ! function_exists papi_avail; then
        echo "1"
        return 1
    fi

    echo "0"
    return 0
}

_compile_papi_profiler() {
    # Check if the binary exists, if so remove.
    if [ -f "$PAPI_PROFILER" ]; then
        rm "$PAPI_PROFILER"
    fi

    # Compile the code.
    cc "$BASEDIR/papi_profiler.c" -o "$PAPI_PROFILER" -lpapi
    chmod +x "$PAPI_PROFILER"
}

# Convert a unit string into a floating-point scaling factor to Joules
_parse_papi_unit_to_joules() {
    local unit="$1"

    # Parse scientific notation like "2^-32 Joules"
    if [[ "$unit" =~ ^([0-9.]+)\^(-?[0-9]+)$ ]]; then
        local base="${BASH_REMATCH[1]}"
        local exponent="${BASH_REMATCH[2]}"
        # local exponent=$(echo "$unit" | sed -E "s/^${base}\^\((-?[0-9]+)\).*$/\1/")
        echo "scale=20; $base^($exponent)" | bc -l | sed 's/^\./0./'
        return
    fi

    # Parse SI prefixes.
    case "$unit" in
        aJ)     echo "1e-18" ;;
        fJ)     echo "1e-15" ;;
        pJ)     echo "1e-12" ;;
        nJ)     echo "1e-9"  ;;
        uJ|µJ)  echo "1e-6"  ;;
        mJ)     echo "1e-3"  ;;
        J)      echo "1"     ;;
        kJ)     echo "1e3"   ;;
        MJ)     echo "1e6"   ;;
        GJ)     echo "1e9"   ;;
        *)      echo "Unrecognized unit: $unit" >&2 ;;
    esac
}

# Parse the output of papi_native_avail for energy related events and units.
_parse_papi_native_avail() {
    # Support for 3 different output modes:
    #   - "events": Only print the event names.
    #   - "units":  Only print the units.
    #   - "both":   Print both names and units separated by " : ".
    local mode="$1"

    # Get events from user.
    local events="$2"

    # Locals for parsing each event.
    local in_event=0
    local event_name=""
    local description=""
    local units=""

    # Loop over all lines of the output.
    echo "$events" | while IFS= read -r line; do
        # Detect the start of a rapl or cray_pm event block.
        if [[ "$line" =~ ^\|[[:space:]]*(rapl::|cray_rapl::|cray_pm:::PM_ENERGY:)[^[:space:]]+ ]]; then
            # Exclude any UNITS events.
            if [[ ! "$line" =~ ^\|[[:space:]]*(cray_rapl:::UNITS|cray_pm:::UNITS) ]]; then
                # TODO: For MN5, extract the modifiers (e.g. :cpu=0) as well and create permuted events.
                # Extract the event name.
                event_name=$(echo "$line" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2}')

                # Reset values for parsing this event.
                in_event=1
                description=""
                units=""
                continue
            fi
        fi

        # Parse consecutive lines after the event name line.
        if [[ $in_event -eq 1 ]]; then
            # Extract units in MN5 and LUMI format.
            if [[ "$line" =~ Units?[[:space:]]*(:|is)[[:space:]]*([0-9]+|\-?[0-9]+|2\^[\-0-9]+|[a-zA-Z]+) ]]; then
                units=$(_parse_papi_unit_to_joules "${BASH_REMATCH[2]}")
            fi

            # Detect the end of the event block.
            if [[ "$line" =~ ^[-=]+$ ]]; then
                # Default units to 1 if none was detected.
                [ -z "$units" ] && units=1

                # Print found values.
                if [ "$mode" = "events" ]; then
                    echo "$event_name"
                elif [ "$mode" = "units" ]; then
                    echo "$units"
                else
                    echo "$event_name : $units"
                fi

                # Reset event block detection.
                in_event=0
            fi
        fi
    done
}

# Parse papi_native_avail for RAPL related events and their unit scalars.
_get_papi_native_avail() {
    # Make sure papi_native_avail is available.
    if ! function_exists papi_available; then
        print_error "Cannot load PAPI components, is PAPI loaded?"
        return
    fi

    # Support for 3 different output modes:
    #   - "events": Only print the event names.
    #   - "units":  Only print the units.
    #   - "both":   Print both names and units separated by " : ".
    local mode="$1"

    # Fetch list of counters and units.
    local components=("rapl" "cray_pm")
    local events=""

    for component in "${components[@]}"; do
        events=$(papi_native_avail -i "$component")
        _parse_papi_native_avail "$mode" "$events"
    done
}

# Return the set of energy events supported by this system.
papi_events() {
    local events=$(_get_papi_native_avail "events")
    if [ -z "$events" ]; then
        echo "NO EVENTS AVAILABLE"
    else
        echo "$events"
    fi
}

# Profile the provided binary with PAPI counters.
papi_profile() {
    # Make sure PAPI is available.
    if ! papi_available 2>&1 > /dev/null; then
        print_error "PAPI is not available."
        return
    fi

    # Get events and units.
    local events=$(_get_papi_native_avail "events")
    local units=$(_get_papi_native_avail "units")

    # Throw warning if there are no supported events.
    if [ -z "$events" ]; then
        print_warning "No supported PAPI counters found."
        return
    fi

    verbose_echo print_info "Events:\n$events"
    verbose_echo print_info "Units:\n$units"

    # Make sure the papi_profiler is updated and compiled.
    verbose_echo print_info "Compiling papi_profiler.c.."
    _compile_papi_profiler

    # Profile binary with supported events.
    verbose_echo print_into "Executing profiler"
    "$PAPI_PROFILER" "$events" "$units" $@
}
