#!/bin/bash
# BARF Command: plan
# Generate implementation plan for an issue

cmd_plan() {
    local issue=""
    local max_iterations="0"
    local show_diff=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --diff|-d)
                show_diff=true
                shift
                ;;
            *)
                if [[ -z "$issue" ]]; then
                    issue="$1"
                elif [[ "$max_iterations" == "0" ]]; then
                    max_iterations="$1"
                fi
                shift
                ;;
        esac
    done

    [[ -z "$issue" ]] && die "Usage: barf plan <issue> [max_iterations] [--diff]"

    require_cmd claude

    # Setup branch if auto_branch enabled
    setup_issue_branch "$issue"

    log_info "Starting planning for: $issue"

    # Fetch issue content
    local issue_content
    issue_content=$(plugin_call /fetch "$issue") || die "Failed to fetch issue: $issue"

    # Get plans directory
    local plans_dir
    plans_dir=$(config_get "plans.path" "$DEFAULT_PLANS_DIR")
    mkdir -p "$plans_dir"

    local plan_file="$plans_dir/${issue}-plan.md"
    local backup_file=""

    # Check for existing plan and backup if --diff
    if [[ -f "$plan_file" ]]; then
        if [[ "$show_diff" == true ]]; then
            backup_file="$plans_dir/.${issue}-plan.backup.md"
            cp "$plan_file" "$backup_file"
            log_info "Backed up existing plan for diff comparison"
        else
            # Check config for auto_backup
            local auto_backup
            auto_backup=$(config_get "plans.auto_backup" "true")
            if [[ "$auto_backup" == "true" ]]; then
                backup_file="$plans_dir/.${issue}-plan.backup.md"
                cp "$plan_file" "$backup_file"
            fi
        fi
    fi

    # Select model for planning (complex for better reasoning)
    local model
    model=$(select_model "complex")
    local model_flag
    model_flag=$(get_model_flag "$model")

    # Read planning prompt
    local prompt_file="PROMPT_plan.md"
    [[ ! -f "$prompt_file" ]] && die "Planning prompt not found: $prompt_file"

    local prompt
    prompt=$(cat "$prompt_file")

    # Prepare the full prompt
    local full_prompt="$prompt

## Issue Content

$issue_content

## Instructions

Create a detailed implementation plan for this issue. Save the plan to: $plan_file

If the issue is too large for a single plan:
1. Create a partial plan with what you can cover
2. Document which parts need separate planning
3. Recommend splitting into these sub-issues

## Existing Codebase

Use the Task tool with Explore subagent to study the codebase structure and patterns before planning."

    local iteration=1
    local split_enabled
    split_enabled=$(config_get "split.enabled" "true")
    local max_retries
    max_retries=$(config_get "split.max_retries" "$DEFAULT_MAX_RETRIES")

    while true; do
        log_info "Planning Iteration $iteration..."

        # Check max iterations
        if [[ $max_iterations -gt 0 && $iteration -gt $max_iterations ]]; then
            log_warn "Max iterations ($max_iterations) reached"
            break
        fi

        # Run Claude
        local output
        # shellcheck disable=SC2086
        if output=$(claude $model_flag --dangerously-skip-permissions -p "$full_prompt" 2>&1); then
            # Check if plan file was created
            if [[ -f "$plan_file" ]]; then
                log_success "Plan generated: $plan_file"

                # Show diff if requested and backup exists
                if [[ "$show_diff" == true && -n "$backup_file" && -f "$backup_file" ]]; then
                    generate_plan_diff "$issue" "$backup_file" "$plan_file"
                    analyze_plan_changes "$backup_file" "$plan_file"
                    rm -f "$backup_file"
                elif [[ "$show_diff" == true ]]; then
                    log_warn "No previous plan to compare against"
                fi

                break
            else
                log_warn "Plan file not created, Claude output:"
                echo "$output"
            fi
        else
            # Check for context limit error using improved detection
            if detect_context_error "$output"; then
                if [[ "$split_enabled" == "true" ]]; then
                    log_warn "Context limit reached - triggering auto-split"
                    handle_auto_split "$issue" "plan"
                    break
                else
                    die "Context limit reached and auto-split is disabled"
                fi
            else
                log_error "Planning failed: $output"
            fi
        fi

        ((iteration++))

        # Check retry limit
        if [[ $iteration -gt $max_retries ]]; then
            log_warn "Max retries ($max_retries) reached"
            if [[ "$split_enabled" == "true" ]]; then
                handle_auto_split "$issue" "plan"
            fi
            break
        fi
    done
}
