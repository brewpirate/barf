#!/bin/bash
# BARF Library: Model Selection
# Claude model selection and flag generation

# Select the appropriate model for a task type
# Usage: select_model "fast|default|complex"
select_model() {
    local task_type="${1:-default}"

    case "$task_type" in
        fast)
            config_get "models.fast" "haiku"
            ;;
        complex)
            config_get "models.complex" "opus"
            ;;
        *)
            config_get "models.default" "sonnet"
            ;;
    esac
}

# Map model name to Claude CLI model flag
get_model_flag() {
    local model="$1"

    case "$model" in
        haiku)
            echo "--model claude-3-5-haiku-latest"
            ;;
        sonnet)
            echo "--model claude-sonnet-4-20250514"
            ;;
        opus)
            echo "--model claude-opus-4-20250514"
            ;;
        *)
            # Default to sonnet
            echo "--model claude-sonnet-4-20250514"
            ;;
    esac
}
