# ------------------------------------------------------------------------------
# This wrapper contains functions for interacting with the PAPI energy
# profiling options.
# ------------------------------------------------------------------------------

# Get the directory where this file is located to load dependencies.
PAPIDIR="$BASEDIR/papi"
. "$PAPIDIR/../utils/general_utils.sh"
. "$PAPIDIR/../utils/print_utils.sh"

PAPI_PROFILER="$PAPIDIR/papi_profiler.o"

# Returns 0 if papi is available, 1 otherwise.
papi_available() {
    verbose_echo print_info "Checking for papi availability.."

    # Check if the papi_avail command is available.
    if ! function_exists papi_avail; then
        printf "1\n"
        return 1
    fi

    printf "0\n"
    return 0
}

_compile_papi_profiler() {
    # Check if the binary exists, if so remove.
    if [ -f "$PAPI_PROFILER" ]; then
        rm "$PAPI_PROFILER"
    fi

    # Compile the code.
    if ! cc "$PAPIDIR/papi_profiler.c" "$PAPIDIR/papi_component.c" "$PAPIDIR/papi_event.c" -o "$PAPI_PROFILER" -lpapi -Wall; then
        print_error "Error while compiling $(basename "$PAPI_PROFILER"), exiting.."
        exit 1
    fi

    # Make binary executable.
    if ! chmod +x "$PAPI_PROFILER"; then
        print_error "Error during 'chmod +x $(basename "$PAPI_PROFILER")', exiting.."
        exit 1
    fi
}

# Convert a unit string into a floating-point scaling factor to Joules
_parse_papi_unit_to_joules() {
    local unit="$1"

    # Parse scientific notation like "2^-32 Joules"
    if [[ "$unit" =~ ^([0-9.]+)\^(-?[0-9]+)$ ]]; then
        local base="${BASH_REMATCH[1]}"
        local exponent="${BASH_REMATCH[2]}"
        # local exponent=$(echo "$unit" | sed -E "s/^${base}\^\((-?[0-9]+)\).*$/\1/")
        printf "scale=20; %s^(%s)\n" "$base" "$exponent" | bc -l | sed 's/^\./0./'
        return
    fi

    # Parse SI prefixes.
    case "$unit" in
    pJ)         printf "0.000000000001\n" ;;
    nJ)         printf "0.000000001\n" ;;
    uJ | µJ)    printf "0.000001\n" ;;
    mJ)         printf "0.001\n" ;;
    J)          printf "1\n" ;;
    kJ)         printf "1000\n" ;;
    MJ)         printf "1000000\n" ;;
    GJ)         printf "1000000000\n" ;;
    *)          printf "Unrecognized unit: %s\n" "$unit" >&2 ;;
    esac
}

# Print papi event information depending on the mode given.
_print_papi_event() {
    local mode="$1"
    local event="$2"
    local unit="$3"

    # Print found values.
    if [ "$mode" = "events" ]; then
        printf "%s\n" "$event"
    elif [ "$mode" = "units" ]; then
        ecprintf "%s\n"ho "$unit"
    else
        printf "%s : %s\n" "$event" "$unit"
    fi
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
    local unit=""
    local modifiers=()
    local mod=""

    # Loop over all lines of the output.
    echo "$events" | while IFS= read -r line; do
        # Detect the start of a rapl or cray_pm event block.
        if [[ "$line" =~ ^\|[[:space:]]*(rapl::|cray_rapl::|cray_pm:::PM_ENERGY:)[^[:space:]]+ ]]; then
            # Exclude any UNITS events.
            if [[ ! "$line" =~ ^\|[[:space:]]*(cray_rapl:::UNITS|cray_pm:::UNITS) ]]; then
                # Extract the event name.
                event_name=$(printf "%s\n" "$line" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2}')

                # Reset values for parsing this event.
                in_event=1
                modifiers=()
                unit=""
                continue
            fi
        fi

        # Parse consecutive lines after the event name line.
        if [[ $in_event -eq 1 ]]; then
            # Extract modifiers, like :cpu=*.
            if [[ "$line" =~ ^\|[[:space:]]*(:[a-zA-Z0-9_]+=[^[:space:]]+) ]]; then
                mod="${BASH_REMATCH[1]}"
                case "$mod" in
                # Skip known modifiers that do not make sense to alter.
                :period=* | :freq=* | :excl=* | :pinned=*) ;;
                *) modifiers+=("$mod") ;;
                esac
            fi

            # Extract units in MN5 and LUMI format.
            if [[ "$line" =~ Units?[[:space:]]*(:|is)[[:space:]]*([0-9]+|\-?[0-9]+|2\^[\-0-9]+|[a-zA-Z]+) ]]; then
                unit=$(_parse_papi_unit_to_joules "${BASH_REMATCH[2]}")
            fi

            # Detect the end of the event block.
            if [[ "$line" =~ ^[-=]+$ ]]; then
                # Default units to 1 if none was detected.
                [ -z "$unit" ] && unit=1

                # Take combinations of the event_name and modifiers, if any exist.
                if [ ${#modifiers[@]} -eq 0 ]; then
                    _print_papi_event "$mode" "$event_name" "$unit"
                else
                    for mod in "${modifiers[@]}"; do
                        _print_papi_event "$mode" "$event_name$mod" "$unit"
                    done
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
    if ! papi_available >/dev/null 2>&1; then
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
    local events
    events=$(_get_papi_native_avail "events")
    if [ -z "$events" ]; then
        printf "NO EVENTS AVAILABLE\n"
    else
        printf "%s\n" "$events"
    fi
}

# Profile the provided binary with PAPI counters.
papi_profile() {
    # Make sure PAPI is available.
    if ! papi_available >/dev/null 2>&1; then
        print_error "PAPI is not available."
        return
    fi

    # Get events and units.
    local events units
    events=$(_get_papi_native_avail "events")
    units=$(_get_papi_native_avail "units")

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
    "$PAPI_PROFILER" "$events" "$units" "$@"
}
