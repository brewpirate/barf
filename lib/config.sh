#!/bin/bash
# BARF Library: Configuration Parsing
# Simple YAML subset parser for .barf.yaml

# Get a value from the config file
# Usage: config_get "source.type" "default_value"
config_get() {
    local key="$1"
    local default="${2:-}"

    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo "$default"
        return
    fi

    # Simple YAML parsing - handles nested keys like "source.type"
    local value
    value=$(parse_yaml_key "$CONFIG_FILE" "$key")

    if [[ -n "$value" ]]; then
        echo "$value"
    else
        echo "$default"
    fi
}

# Parse a specific key from YAML file
parse_yaml_key() {
    local file="$1"
    local key="$2"

    # Split key by dots
    IFS='.' read -ra parts <<< "$key"

    local indent=0
    local current_indent=0
    local in_section=true
    local part_index=0
    local target_part="${parts[$part_index]}"

    while IFS= read -r line || [[ -n "$line" ]]; do
        # Skip comments and empty lines
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// }" ]] && continue

        # Calculate indentation
        local stripped="${line#"${line%%[![:space:]]*}"}"
        current_indent=$(( (${#line} - ${#stripped}) / 2 ))

        # Check if we're still in the right section
        if [[ $current_indent -lt $indent ]] && [[ $part_index -gt 0 ]]; then
            in_section=false
        fi

        if $in_section; then
            # Look for the current target key
            if [[ "$line" =~ ^[[:space:]]*${target_part}:[[:space:]]*(.*) ]]; then
                local value="${BASH_REMATCH[1]}"

                # Move to next part of the key
                ((part_index++))

                if [[ $part_index -ge ${#parts[@]} ]]; then
                    # We found the final key
                    # Remove quotes and comments
                    value="${value%%#*}"
                    value="${value%"${value##*[![:space:]]}"}"
                    value="${value#\"}"
                    value="${value%\"}"
                    value="${value#\'}"
                    value="${value%\'}"
                    echo "$value"
                    return
                else
                    # Go deeper
                    target_part="${parts[$part_index]}"
                    indent=$((current_indent + 1))
                fi
            fi
        fi
    done < "$file"
}
