# ------------------------------------------------------------------------------
# Utils related to energy and power.
# ------------------------------------------------------------------------------


# Convert a SLURM ConsumedEnergy string (e.g. "123.45K") to integer joules.
convert_to_joules() {
    # Strip whitespace
    local string
    string=$(printf "%s" "$1" | tr -d ' ')

    # Catch empty lines.
    if [ -z "$string" ]; then
        echo "0"
        return
    fi

    # Separate numeric value and unit
    local num unit mult
    num=$(printf "%s" "$string" | sed 's/[KMG]$//')
    unit=$(printf "%s" "$string" | sed 's/^[0-9.]*//')

    # Choose multiplier based on unit
    case "$unit" in
        "") mult=1 ;;
        K)  mult=1000 ;;
        M)  mult=1000000 ;;
        G)  mult=1000000000 ;;
        *)
            echo "Unknown unit: $unit" >&2
            return 1
            ;;
    esac

    # Convert to integer joules.
    printf "%.0f" "$(echo "$num * $mult" | bc)"
}

# Convert integer joules into human readable unit (J, K, M, G).
convert_from_joules() {
    local joules="$1"

    if [ "$joules" -ge 1000000000 ]; then
        local unit="G"
        local divisor=1000000000
    elif [ "$joules" -ge 1000000 ]; then
        local unit="M"
        local divisor=1000000
    elif [ "$joules" -ge 1000 ]; then
        local unit="K"
        local divisor=1000
    else
        local unit=""
        local divisor=1
    fi

    local value
    value=$(echo "scale=2; $joules / $divisor" | bc)
    printf "%s %sJ" "$value" "$unit"
}
