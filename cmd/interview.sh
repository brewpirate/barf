#!/bin/bash
# BARF Command: interview
# Analyze issue and ask clarifying questions

cmd_stats() {
    local issue="${1:-}"

    print_header "BARF Cost Tracking"

    show_stats "$issue"
}

cmd_interview() {
    local issue="${1:-}"

    [[ -z "$issue" ]] && die "Usage: barf interview <issue>"

    require_cmd claude

    # Setup branch if auto_branch enabled
    setup_issue_branch "$issue"

    log_info "Starting interview for: $issue"

    # Fetch issue content
    local issue_content
    issue_content=$(plugin_call /fetch "$issue") || die "Failed to fetch issue: $issue"

    # Select model for interview (default is good enough)
    local model
    model=$(select_model "default")
    local model_flag
    model_flag=$(get_model_flag "$model")

    # Read interview prompt
    local prompt_file="PROMPT_interview.md"
    [[ ! -f "$prompt_file" ]] && die "Interview prompt not found: $prompt_file"

    local prompt
    prompt=$(cat "$prompt_file")

    # Prepare the full prompt with issue content
    local full_prompt="$prompt

## Issue Content

$issue_content

## Instructions

Analyze this issue and identify any ambiguities or missing information. Ask clarifying questions as needed."

    # Run Claude
    log_info "Analyzing issue with Claude ($model)..."

    # shellcheck disable=SC2086
    claude $model_flag --dangerously-skip-permissions -p "$full_prompt"

    log_success "Interview complete for: $issue"
}
