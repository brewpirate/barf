#!/bin/bash
# BARF Command: status
# Show status summary or get/set issue status

cmd_status() {
    local issue="${1:-}"
    local new_status="${2:-}"

    if [[ -z "$issue" ]]; then
        # Show overall status summary
        log_info "BARF Status Summary"
        echo ""

        local plans_dir
        plans_dir=$(config_get "plans.path" "$DEFAULT_PLANS_DIR")

        local issues_dir
        issues_dir=$(config_get "source.path" "$DEFAULT_ISSUES_DIR")

        # Count issues
        local total_issues=0
        local planned_issues=0
        local in_progress=0
        local completed_issues=0

        if [[ -d "$issues_dir" ]]; then
            total_issues=$(find "$issues_dir" -maxdepth 1 -name "*.md" -type f 2>/dev/null | wc -l)
        fi

        if [[ -d "$plans_dir" ]]; then
            planned_issues=$(find "$plans_dir" -name "*-plan.md" -type f 2>/dev/null | wc -l)
            in_progress=$(find "$plans_dir" -name "*-progress.md" -type f 2>/dev/null | wc -l)
        fi

        echo "  Total issues:     $total_issues"
        echo "  With plans:       $planned_issues"
        echo "  In progress:      $in_progress"
        echo ""

        # Show test command
        local test_cmd
        test_cmd=$(detect_test_command)
        if [[ -n "$test_cmd" ]]; then
            echo "  Test command:     $test_cmd"
        else
            echo "  Test command:     (not detected)"
        fi

        # Show source type
        local source_type
        source_type=$(config_get "source.type" "local")
        echo "  Issue source:     $source_type"

        return
    fi

    # Get or set status for specific issue
    if [[ -z "$new_status" ]]; then
        # Get status
        local status
        status=$(plugin_call /status "$issue" 2>/dev/null) || status="unknown"

        local plans_dir
        plans_dir=$(config_get "plans.path" "$DEFAULT_PLANS_DIR")

        echo "Issue: $issue"
        echo "Status: $status"

        # Show plan status if exists
        if [[ -f "$plans_dir/${issue}-plan.md" ]]; then
            local total_tasks
            local done_tasks
            total_tasks=$(grep -c "^\[.\]" "$plans_dir/${issue}-plan.md" 2>/dev/null || echo "0")
            done_tasks=$(grep -c "^\[x\]" "$plans_dir/${issue}-plan.md" 2>/dev/null || echo "0")
            echo "Tasks: $done_tasks/$total_tasks complete"

            # Show incomplete tasks
            local incomplete
            incomplete=$(grep "^\[ \]" "$plans_dir/${issue}-plan.md" 2>/dev/null | head -5)
            if [[ -n "$incomplete" ]]; then
                echo ""
                echo "Next tasks:"
                echo "$incomplete" | while read -r task; do
                    echo "  $task"
                done
            fi
        fi

        # Show progress notes if exists
        if [[ -f "$plans_dir/${issue}-progress.md" ]]; then
            echo ""
            echo "Progress notes: $plans_dir/${issue}-progress.md"

            # Check for blockers
            local problem
            problem=$(sed -n '/^## The Problem/,/^##/p' "$plans_dir/${issue}-progress.md" 2>/dev/null | head -5)
            if [[ -n "$problem" ]]; then
                echo ""
                echo "Current blocker:"
                echo "$problem" | tail -n +2 | head -3 | while read -r line; do
                    echo "  $line"
                done
            fi
        fi
    else
        # Set status
        plugin_call /status "$issue" "$new_status"
        log_success "Status updated: $issue -> $new_status"
    fi
}
