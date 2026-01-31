#!/bin/bash
# BARF Command: resume
# Resume work on an issue (auto-detects state)

cmd_resume() {
    local issue="${1:-}"
    local max_iterations="${2:-0}"

    [[ -z "$issue" ]] && die "Usage: barf resume <issue> [max_iterations]"

    require_cmd claude

    # Get plans directory
    local plans_dir
    plans_dir=$(config_get "plans.path" "$DEFAULT_PLANS_DIR")

    local plan_file="$plans_dir/${issue}-plan.md"
    local progress_file="$plans_dir/${issue}-progress.md"

    # Check what exists to determine how to resume
    if [[ -f "$progress_file" ]]; then
        log_info "Found progress notes for: $issue"
        log_info "Resuming from saved progress..."

        # Check if there are sub-issues to work on
        local sub_issues
        sub_issues=$(grep -E "^- [a-zA-Z0-9_-]+:" "$progress_file" 2>/dev/null | sed 's/^- \([^:]*\):.*/\1/' || echo "")

        if [[ -n "$sub_issues" ]]; then
            log_info "Found sub-issues from previous split:"
            echo "$sub_issues" | while read -r sub; do
                [[ -n "$sub" ]] && echo "  - $sub"
            done
            echo ""

            # Work on first incomplete sub-issue
            echo "$sub_issues" | while read -r sub_issue; do
                [[ -z "$sub_issue" ]] && continue

                local sub_plan="$plans_dir/${sub_issue}-plan.md"
                local sub_status
                sub_status=$(plugin_call /status "$sub_issue" 2>/dev/null || echo "open")

                if [[ "$sub_status" != "closed" && "$sub_status" != "done" && "$sub_status" != "completed" ]]; then
                    if [[ ! -f "$sub_plan" ]]; then
                        log_info "Planning sub-issue: $sub_issue"
                        cmd_plan "$sub_issue" "$max_iterations"
                    fi

                    log_info "Building sub-issue: $sub_issue"
                    cmd_build "$sub_issue" "$max_iterations"
                    return
                fi
            done

            log_success "All sub-issues appear complete!"
            log_info "Marking parent issue as complete..."
            plugin_call /status "$issue" "completed" 2>/dev/null || true
            return
        fi
    fi

    # No sub-issues, check for plan
    if [[ -f "$plan_file" ]]; then
        # Check if there are incomplete tasks
        if grep -q "^\[ \]" "$plan_file"; then
            log_info "Found incomplete tasks in plan, resuming build..."
            cmd_build "$issue" "$max_iterations"
        else
            log_success "All tasks in plan are complete!"
            plugin_call /status "$issue" "completed" 2>/dev/null || true
        fi
    else
        # No plan exists, start from planning
        log_info "No plan found, starting from planning phase..."
        cmd_plan "$issue" "$max_iterations"

        if [[ -f "$plan_file" ]]; then
            log_info "Plan created, starting build..."
            cmd_build "$issue" "$max_iterations"
        fi
    fi
}
