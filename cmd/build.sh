#!/bin/bash
# BARF Command: build
# Build from plan - implement tasks iteratively

cmd_build() {
    local issue="${1:-}"
    local max_iterations="${2:-0}"

    [[ -z "$issue" ]] && die "Usage: barf build <issue> [max_iterations]"

    require_cmd claude

    # Setup branch if auto_branch enabled
    setup_issue_branch "$issue"

    log_info "Starting build for: $issue"

    # Get plans directory
    local plans_dir
    plans_dir=$(config_get "plans.path" "$DEFAULT_PLANS_DIR")

    local plan_file="$plans_dir/${issue}-plan.md"
    local progress_file="$plans_dir/${issue}-progress.md"

    # Check if plan exists
    [[ ! -f "$plan_file" ]] && die "Plan not found: $plan_file (run 'barf plan $issue' first)"

    # Select model for building (default for most tasks)
    local model
    model=$(select_model "default")
    local model_flag
    model_flag=$(get_model_flag "$model")

    # Read build prompt
    local prompt_file="PROMPT_build.md"
    [[ ! -f "$prompt_file" ]] && die "Build prompt not found: $prompt_file"

    local prompt
    prompt=$(cat "$prompt_file")

    # Get commit format
    local commit_format
    commit_format=$(config_get "build.commit_format" "feat({issue}): {task}")

    # Detect test command
    local test_command
    test_command=$(config_get "build.test_command" "")
    if [[ -z "$test_command" ]]; then
        test_command=$(detect_test_command)
        if [[ -n "$test_command" ]]; then
            log_info "Detected test command: $test_command"
        fi
    fi

    local iteration=1
    local stuck_count=0
    local split_enabled
    split_enabled=$(config_get "split.enabled" "true")
    local max_retries
    max_retries=$(config_get "split.max_retries" "$DEFAULT_MAX_RETRIES")

    while true; do
        log_info "Building Iteration $iteration..."

        # Check max iterations
        if [[ $max_iterations -gt 0 && $iteration -gt $max_iterations ]]; then
            log_warn "Max iterations ($max_iterations) reached"
            break
        fi

        # Read current plan
        local plan_content
        plan_content=$(cat "$plan_file")

        # Check if all tasks are complete
        if ! echo "$plan_content" | grep -q "^\[ \]"; then
            log_success "All tasks complete!"
            break
        fi

        # Check context limit before sending
        local full_context="$prompt

$plan_content

$(if [[ -f "$progress_file" ]]; then cat "$progress_file"; fi)"

        if check_context_limit "$full_context" "$model" "0.7"; then
            log_warn "Context is getting large - consider splitting issue"
        fi

        # Prepare the full prompt
        local full_prompt="$prompt

## Plan Content

$plan_content

## Progress Notes

$(if [[ -f "$progress_file" ]]; then cat "$progress_file"; else echo "No progress notes yet."; fi)

## Test Command

$(if [[ -n "$test_command" ]]; then echo "Run tests with: $test_command"; else echo "No test command detected - check AGENTS.md or add to .barf.yaml"; fi)

## Instructions

1. Select the most important incomplete task (marked with [ ])
2. Implement it completely
3. Run tests to verify: ${test_command:-'(configure in AGENTS.md or .barf.yaml)'}
4. If tests pass, commit with format: $commit_format
5. Update the plan file to mark the task as [x]
6. If stuck, create progress notes and exit

Issue name for commits: $issue"

        # Run Claude
        local output
        # shellcheck disable=SC2086
        if output=$(claude $model_flag --dangerously-skip-permissions -p "$full_prompt" 2>&1); then
            # Check for stuck indicator
            if echo "$output" | grep -qi "stuck\|blocked\|cannot\|unable"; then
                ((stuck_count++))
                log_warn "Agent reports being stuck (attempt $stuck_count/$max_retries)"

                if [[ $stuck_count -ge $max_retries ]]; then
                    if [[ "$split_enabled" == "true" ]]; then
                        log_warn "Max stuck attempts reached - triggering auto-split"
                        handle_auto_split "$issue" "build"
                        break
                    else
                        log_error "Max stuck attempts reached and auto-split is disabled"
                        break
                    fi
                fi

                log_info "Retrying with fresh context..."
            else
                # Reset stuck count on progress
                stuck_count=0
            fi
        else
            # Check for context limit error using improved detection
            if detect_context_error "$output"; then
                if [[ "$split_enabled" == "true" ]]; then
                    log_warn "Context limit reached - triggering auto-split"
                    handle_auto_split "$issue" "build"
                    break
                else
                    die "Context limit reached and auto-split is disabled"
                fi
            else
                log_error "Build iteration failed: $output"
            fi
        fi

        ((iteration++))
    done
}
