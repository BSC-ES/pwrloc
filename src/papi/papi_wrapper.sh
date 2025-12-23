#!/usr/bin/env sh
# ------------------------------------------------------------------------------
# This wrapper contains functions for interacting with the PAPI energy
# profiling options.
# ------------------------------------------------------------------------------

# Get the directory where this file is located to load dependencies.
PAPIDIR="$SRCDIR/papi"
. "$PAPIDIR/../utils/general_utils.sh"
. "$PAPIDIR/../utils/print_utils.sh"
. "$PAPIDIR/../utils/array_utils.sh"

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
    # Check if the binary exists.
    if [ -f "$PAPI_PROFILER" ]; then
        # If exists, check for executable rights and rebuild if not.
        if [ -x "$PAPI_PROFILER" ]; then
            return
        else
            rm "$PAPI_PROFILER"
        fi
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

# Convert a unit-string into a floating-point scalar for converting in Joule.
_parse_papi_unit_to_joule_scalar() {
    unit="$1"

    case $unit in
    *"^"*)
        split=$(split_scientific_notation "$unit")
        base=${split%%$'\n'*}
        exponent=${split#*$'\n'}

        # Compute the value using bc
        printf "scale=20; %s^(%s)\n" "$base" "$exponent" |
            bc -l |
            sed 's/^\./0./'
        return
        ;;
    esac

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
    *)          printf "Unrecognized SI prefix unit: %s\n" "$unit" >&2 ;;
    esac
}

# Print papi event information depending on the mode given.
_print_papi_event() {
    mode="$1"
    event="$2"
    unit="$3"

    # Print found values.
    if [ "$mode" = "events" ]; then
        printf "%s\n" "$event"
    elif [ "$mode" = "units" ]; then
        printf "%s\n" "$unit"
    else
        printf "%s : %s\n" "$event" "$unit"
    fi
}

# Detect the start of a PAPI event block with energy counter information.
_detect_papi_start_event_block() {
    # Reject UNITS events.
    case $1 in
        '|'[[:space:]]*cray_rapl:::UNITS* | \
        '|'[[:space:]]*cray_pm:::UNITS* )
            return 1
            ;;
    esac

    # Accept RAPL/CRAY_PM energy events.
    case $1 in
        '|'[[:space:]]*rapl::* | \
        '|'[[:space:]]*cray_rapl::* | \
        '|'[[:space:]]*cray_pm:::PM_ENERGY:* )
            return 0
            ;;
    esac

    # Return false in any other case.
    return 1
}

# Detect a modifier line inside a PAPI event block, like :cpu=0 or :freq=2000.
_detect_papi_modifier_line() {
    case $1 in
        '|'[[:space:]]*:*=* )
            return 0
            ;;
    esac

    return 1
}

# Detect a unit line inside a PAPI event block in the style of MN5 and LUMI.
_detect_unit_line() {
    case $1 in
        *[Uu]nit* )
            # Must contain at least one of these separators:
            case $1 in
                *:[[:space:]]*|*is[[:space:]]* ) return 0 ;;
            esac
            ;;
    esac

    return 1
}

# Detect the end of a PAPI event block.
_detect_event_block_end() {
    case $1 in
        # One or more '-' or '=' only
        [-=]* )
            # But it must not be empty
            [ -n "$1" ] && return 0
            ;;
    esac

    return 1
}

# Parse the output of papi_native_avail for energy related events and units.
_parse_papi_native_avail() {
    # Support for 3 different output modes:
    #   - "events": Only print the event names.
    #   - "units":  Only print the units.
    #   - "both":   Print both names and units separated by " : ".
    mode="$1"

    # Get events from user.
    events="$2"

    # Locals for parsing each event, where unit will contain Joule scalars.
    in_event=0
    event_name=""
    unit=""

    # Loop over all lines of the output.
    printf '%s\n' "$events" | while IFS= read -r line; do
        # Detect the start of a rapl or cray_pm event block, which is not a
        # UNITS event.
        if _detect_papi_start_event_block "$line"; then
            # Extract the event name.
            event_name=$(printf "%s\n" "$line" \
                | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2}')

            # Reset values for parsing this event.
            in_event=1
            modifiers=""
            unit=""
            continue
        fi

        # Parse consecutive lines after the event name line.
        if [ $in_event -eq 1 ]; then
            # Extract modifiers, like :cpu=*.
            if _detect_papi_modifier_line "$line"; then
                # Extract the modifier name, e.g. "cpu"
                mod=$(printf '%s\n' "$line" \
                    | sed -n 's/^|[[:space:]]*\(:[^[:space:]]*\).*$/\1/p')

                # If extraction failed, skip
                [ -z "$mod" ] && continue

                # Skip known modifiers that do not make sense to alter.
                case $mod in
                    :period=* | :freq=* | :excl=* | :pinned=* )
                        ;;
                    *)
                        # Store parsed modifiers in an array.
                        modifiers=$(array_push "$modifiers" "$mod")
                        ;;
                esac
            fi

            # Extract units in MN5 and LUMI format.
            if _detect_unit_line "$line"; then
                # Extract unit token and convert to scalar.
                case $line in
                    # Parse MN5 format.
                    *'Unit is '*)
                        unit_token=$(printf '%s\n' "$line" |
                            sed 's/.*Unit is[[:space:]]*//; s/[[:space:]]*|.*//')
                        scalar=${unit_token%% *}
                        unit=${unit_token#* }

                        # Print warning if unit is not Joules.
                        if [ "$unit" = "Joules" ]; then
                            unit=$(_parse_papi_unit_to_joule_scalar "$scalar")
                        else
                            verbose_echo print_warning "Unit line did not have Joules unit."
                        fi
                        ;;
                    # Parse LUMI format.
                    *'Units:'*)
                        unit=$(printf '%s\n' "$line" |
                            sed 's/.*Units:[[:space:]]*//; s/[[:space:]]*|.*//')
                        unit=$(_parse_papi_unit_to_joule_scalar "$unit")
                        ;;
                    *)
                        verbose_echo print_warning "Could not parse unit line.."
                        ;;
                esac
            fi

            # Detect the end of the event block.
            if _detect_event_block_end "$line"; then
                # Default units to 1 if none was detected.
                [ -z "$unit" ] && unit=1

                # If no modifiers were collected, provide event as-is.
                if [ "$(array_len "$modifiers")" -eq 0 ]; then
                    _print_papi_event "$mode" "$event_name" "$unit"
                else
                    # Otherwise, take combinations of the event and modifiers.
                    while [ "$(array_len "$modifiers")" -ne 0 ]; do
                        mod=$(array_get_last "$modifiers")
                        modifiers=$(array_pop "$modifiers")
                        _print_papi_event "$mode" "${event_name}${mod}" "$unit"
                    done
                fi

                # Reset event block detection state.
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
    mode="$1"

    # Fetch list of counters and units.
    components=""
    components=$(array_push "$components" "rapl")
    components=$(array_push "$components" "cray_pm")
    events=""

    while [ "$(array_len "$components")" -ne 0 ]; do
        component=$(array_get_last "$components")
        components=$(array_pop "$components")
        events=$(papi_native_avail -i "$component")

        # Print the found counters and units to stdout.
        _parse_papi_native_avail "$mode" "$events"
    done
}

# Return the set of energy events supported by this system.
papi_events() {
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
