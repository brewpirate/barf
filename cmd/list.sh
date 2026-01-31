#!/bin/bash
# BARF Command: list
# List all issues with status

cmd_list() {
    local filter="${1:-}"

    log_info "Issues:"
    echo ""

    # Get list from plugin
    local issues
    issues=$(plugin_call /list 2>/dev/null) || die "Failed to list issues"

    if [[ -z "$issues" ]]; then
        echo "  No issues found."
        return
    fi

    # Get plans directory for status check
    local plans_dir
    plans_dir=$(config_get "plans.path" "$DEFAULT_PLANS_DIR")

    echo "$issues" | while read -r issue_line; do
        [[ -z "$issue_line" ]] && continue

        # Extract issue name (may include status from plugin)
        local issue_name
        issue_name=$(echo "$issue_line" | sed 's/ (.*//')

        # Check for plan and progress
        local has_plan=""
        local has_progress=""
        local task_status=""

        if [[ -f "$plans_dir/${issue_name}-plan.md" ]]; then
            has_plan="[plan]"
            # Count tasks
            local total_tasks
            local done_tasks
            total_tasks=$(grep -c "^\[.\]" "$plans_dir/${issue_name}-plan.md" 2>/dev/null || echo "0")
            done_tasks=$(grep -c "^\[x\]" "$plans_dir/${issue_name}-plan.md" 2>/dev/null || echo "0")
            if [[ $total_tasks -gt 0 ]]; then
                task_status="($done_tasks/$total_tasks)"
            fi
        fi

        if [[ -f "$plans_dir/${issue_name}-progress.md" ]]; then
            has_progress="[progress]"
        fi

        # Apply filter if specified
        case "$filter" in
            --planned|planned)
                [[ -z "$has_plan" ]] && continue
                ;;
            --in-progress|in-progress)
                [[ -z "$has_progress" && -z "$has_plan" ]] && continue
                ;;
            --open|open)
                echo "$issue_line" | grep -qi "closed\|done\|completed" && continue
                ;;
            "")
                # No filter
                ;;
        esac

        printf "  %-30s %s %s %s\n" "$issue_line" "$has_plan" "$has_progress" "$task_status"
    done
}
