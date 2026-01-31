#!/bin/bash
# BARF Command: audit
# Perform codebase quality audit

cmd_audit() {
    require_cmd claude

    log_info "Starting codebase audit..."

    # Get audit output file
    local audit_output
    audit_output=$(config_get "audit.output" "./AUDIT_REPORT.md")

    # Select model for audit (complex for thorough analysis)
    local model
    model=$(select_model "complex")
    local model_flag
    model_flag=$(get_model_flag "$model")

    # Read audit prompt
    local prompt_file="PROMPT_audit.md"
    [[ ! -f "$prompt_file" ]] && die "Audit prompt not found: $prompt_file"

    local prompt
    prompt=$(cat "$prompt_file")

    # Read AGENTS.md for context
    local agents_content=""
    if [[ -f "AGENTS.md" ]]; then
        agents_content=$(cat "AGENTS.md")
    fi

    # Prepare the full prompt
    local full_prompt="$prompt

## AGENTS.md Content

$agents_content

## Instructions

Perform a comprehensive audit of this codebase. Save the report to: $audit_output

Use the Task tool with Explore subagent to analyze the codebase thoroughly."

    log_info "Analyzing codebase with Claude ($model)..."

    # shellcheck disable=SC2086
    claude $model_flag --dangerously-skip-permissions -p "$full_prompt"

    if [[ -f "$audit_output" ]]; then
        log_success "Audit complete: $audit_output"
    else
        log_warn "Audit complete but report file not found"
    fi
}
