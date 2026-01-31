#!/bin/bash
# BARF Command: dashboard
# Show progress dashboard

cmd_dashboard() {
    print_header "BARF Dashboard"

    if [[ $DRY_RUN -eq 1 ]]; then
        log_dry_run "Would display project dashboard with:"
        log_dry_run "  - All issues and their status"
        log_dry_run "  - Build progress for each issue"
        log_dry_run "  - Recent activity"
        return 0
    fi

    local issues_dir
    issues_dir=$(config_get "source.path" "$DEFAULT_ISSUES_DIR")
    local plans_dir
    plans_dir=$(config_get "plans.path" "$DEFAULT_PLANS_DIR")

    # Check if gh is available
    if ! command -v gh &> /dev/null; then
        log_warn "GitHub CLI (gh) not available - showing local data only"
    fi

    echo ""

    # Section 1: Issues Overview (from GitHub)
    echo -e "${BOLD}Issues Overview${NC}"
    echo -e "${DIM}─────────────────────────────────────────────────${NC}"

    if command -v gh &> /dev/null; then
        local issues
        issues=$(gh issue list --limit 20 --json number,title,state,labels 2>/dev/null || echo "[]")

        if [[ "$issues" == "[]" ]] || [[ -z "$issues" ]]; then
            echo "  No open issues found"
        else
            if command -v jq &> /dev/null; then
                echo "$issues" | jq -r '.[] | "  #\(.number) [\(.state)] \(.title)"' 2>/dev/null || echo "  (install jq for better formatting)"
            else
                echo "  (install jq for formatted issue list)"
                echo "  Run: gh issue list"
            fi
        fi
    else
        echo "  (gh CLI not available)"
    fi

    echo ""

    # Section 2: Plans Status
    echo -e "${BOLD}Plan Status${NC}"
    echo -e "${DIM}─────────────────────────────────────────────────${NC}"

    if [[ -d "$plans_dir" ]]; then
        local plan_count=0
        for plan_file in "$plans_dir"/issue-*-plan.md; do
            [[ -f "$plan_file" ]] || continue
            plan_count=$((plan_count + 1))

            local issue_num
            issue_num=$(basename "$plan_file" | sed 's/issue-\(.*\)-plan.md/\1/')

            # Count tasks
            local done=0
            local pending=0
            local total=0

            if [[ -f "$plan_file" ]]; then
                done=$(grep -c "^\[x\]" "$plan_file" 2>/dev/null || echo "0")
                pending=$(grep -c "^\[ \]" "$plan_file" 2>/dev/null || echo "0")
                total=$((done + pending))
            fi

            # Progress bar
            local pct=0
            [[ $total -gt 0 ]] && pct=$((done * 100 / total))
            local bar_done=$((pct / 5))
            local bar_pending=$((20 - bar_done))
            local bar=""
            for ((i=0; i<bar_done; i++)); do bar+="█"; done
            for ((i=0; i<bar_pending; i++)); do bar+="░"; done

            # Status indicator
            local status_icon="○"
            local status_color="$YELLOW"
            if [[ $done -eq $total ]] && [[ $total -gt 0 ]]; then
                status_icon="●"
                status_color="$GREEN"
            elif [[ -f "$plans_dir/issue-$issue_num-progress.md" ]]; then
                status_icon="◐"
                status_color="$YELLOW"
            fi

            printf "  ${status_color}%s${NC} Issue #%-4s [%s] %3d%% (%d/%d tasks)\n" \
                "$status_icon" "$issue_num" "$bar" "$pct" "$done" "$total"
        done

        if [[ $plan_count -eq 0 ]]; then
            echo "  No plans found in $plans_dir/"
            echo "  Run: barf plan <issue> to create one"
        fi
    else
        echo "  No plans directory found"
    fi

    echo ""

    # Section 3: Progress Notes (stuck issues)
    echo -e "${BOLD}Progress Notes (Stuck Issues)${NC}"
    echo -e "${DIM}─────────────────────────────────────────────────${NC}"

    local progress_count=0
    if [[ -d "$plans_dir" ]]; then
        for progress_file in "$plans_dir"/issue-*-progress.md; do
            [[ -f "$progress_file" ]] || continue
            progress_count=$((progress_count + 1))

            local issue_num
            issue_num=$(basename "$progress_file" | sed 's/issue-\(.*\)-progress.md/\1/')

            local last_modified
            last_modified=$(stat -c %Y "$progress_file" 2>/dev/null || stat -f %m "$progress_file" 2>/dev/null || echo "0")
            local now
            now=$(date +%s)
            local age_hours=$(( (now - last_modified) / 3600 ))

            printf "  ${YELLOW}⚠${NC} Issue #%-4s (updated %dh ago) → %s\n" \
                "$issue_num" "$age_hours" "$progress_file"
        done
    fi

    if [[ $progress_count -eq 0 ]]; then
        echo "  No stuck issues - all clear!"
    fi

    echo ""

    # Section 4: Local Issues (from issues/ directory)
    echo -e "${BOLD}Local Issue Files${NC}"
    echo -e "${DIM}─────────────────────────────────────────────────${NC}"

    if [[ -d "$issues_dir" ]]; then
        local issue_file_count=0
        for issue_file in "$issues_dir"/*.md; do
            [[ -f "$issue_file" ]] || continue
            issue_file_count=$((issue_file_count + 1))

            local filename
            filename=$(basename "$issue_file")
            local title
            title=$(head -1 "$issue_file" | sed 's/^#\s*//')

            printf "  📄 %-30s %s\n" "$filename" "$title"
        done

        if [[ $issue_file_count -eq 0 ]]; then
            echo "  No local issue files"
            echo "  Create one: barf new feature \"My Feature\""
        fi
    else
        echo "  No issues directory"
    fi

    echo ""

    # Section 5: Recent Git Activity
    echo -e "${BOLD}Recent Activity${NC}"
    echo -e "${DIM}─────────────────────────────────────────────────${NC}"

    if git rev-parse --git-dir > /dev/null 2>&1; then
        git log --oneline -5 --pretty=format:"  %C(yellow)%h%C(reset) %s %C(dim)(%cr)%C(reset)" 2>/dev/null || echo "  No commits yet"
        echo ""
    else
        echo "  Not a git repository"
    fi

    echo ""

    # Section 6: Quick Stats
    echo -e "${BOLD}Quick Stats${NC}"
    echo -e "${DIM}─────────────────────────────────────────────────${NC}"

    local total_plans=0
    local completed_plans=0
    local total_tasks=0
    local completed_tasks=0

    if [[ -d "$plans_dir" ]]; then
        for plan_file in "$plans_dir"/issue-*-plan.md; do
            [[ -f "$plan_file" ]] || continue
            total_plans=$((total_plans + 1))

            local done
            local pending
            done=$(grep -c "^\[x\]" "$plan_file" 2>/dev/null || echo "0")
            pending=$(grep -c "^\[ \]" "$plan_file" 2>/dev/null || echo "0")

            completed_tasks=$((completed_tasks + done))
            total_tasks=$((total_tasks + done + pending))

            [[ $pending -eq 0 ]] && [[ $done -gt 0 ]] && completed_plans=$((completed_plans + 1))
        done
    fi

    echo "  Plans:  $completed_plans/$total_plans completed"
    echo "  Tasks:  $completed_tasks/$total_tasks completed"

    if [[ $progress_count -gt 0 ]]; then
        echo -e "  ${YELLOW}Stuck:   $progress_count issue(s) need attention${NC}"
    fi

    echo ""
}
