#!/bin/bash
# BARF Library: Plugin System
# Plugin loading and execution for different issue sources

# Get the plugin script path based on source type
get_plugin_path() {
    local source_type
    source_type=$(config_get "source.type" "local")

    case "$source_type" in
        local)
            echo "$(dirname "$0")/plugins/local.sh"
            ;;
        github)
            echo "$(dirname "$0")/plugins/github.sh"
            ;;
        gitlab)
            echo "$(dirname "$0")/plugins/gitlab.sh"
            ;;
        custom)
            config_get "source.plugin"
            ;;
        *)
            die "Unknown source type: $source_type"
            ;;
    esac
}

# Call a plugin command
# Usage: plugin_call /fetch issue-name
plugin_call() {
    local cmd="$1"
    shift

    local plugin_path
    plugin_path=$(get_plugin_path)

    if [[ ! -f "$plugin_path" ]]; then
        die "Plugin not found: $plugin_path"
    fi

    if [[ ! -x "$plugin_path" ]]; then
        chmod +x "$plugin_path"
    fi

    "$plugin_path" "$cmd" "$@"
}
