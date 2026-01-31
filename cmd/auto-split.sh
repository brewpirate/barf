#!/bin/bash
# BARF Command: auto-split
# Handle automatic splitting of large issues

handle_auto_split() {
    local issue="$1"
    local mode="$2"  # plan or build

    log_info "Handling auto-split for: $issue"

    local plans_dir
    plans_dir=$(config_get "plans.path" "$DEFAULT_PLANS_DIR")

    local progress_file="$plans_dir/${issue}-progress.md"
    local split_pattern
    split_pattern=$(config_get "split.pattern" "{issue}-part{n}")

    # Create progress notes if they don't exist
    if [[ ! -f "$progress_file" ]]; then
        cat > "$progress_file" << EOF
# Progress Notes for $issue

## Status
Auto-split triggered during $mode mode

## Reason
Context limit reached or stuck after max retries

## Created Sub-Issues
<!-- BARF will add sub-issues here -->

## Recommendations
1. Review the sub-issues created
2. Run barf plan/build on each sub-issue
3. Mark parent issue as complete when all sub-issues are done
EOF
    fi

    # Use Claude to analyze and recommend splits
    local model
    model=$(select_model "fast")
    local model_flag
    model_flag=$(get_model_flag "$model")

    # Fetch issue content
    local issue_content
    issue_content=$(plugin_call /fetch "$issue" 2>/dev/null) || issue_content=""

    # Get existing plan if any
    local plan_content=""
    local plan_file="$plans_dir/${issue}-plan.md"
    if [[ -f "$plan_file" ]]; then
        plan_content=$(cat "$plan_file")
    fi

    local split_prompt="Analyze this issue and recommend how to split it into 2-4 smaller sub-issues.

Issue content:
$issue_content

Existing plan (if any):
$plan_content

Provide a brief list of recommended sub-issues with titles and scope. Format:
1. {title} - {brief scope description}
2. {title} - {brief scope description}
..."

    log_info "Analyzing issue for split recommendations..."

    local recommendations
    # shellcheck disable=SC2086
    recommendations=$(claude $model_flag --dangerously-skip-permissions -p "$split_prompt" 2>/dev/null) || recommendations="Manual split recommended"

    # Create sub-issues based on pattern
    local n=1
    echo "$recommendations" | grep -E "^[0-9]+\." | while read -r line; do
        local title
        title=$(echo "$line" | sed 's/^[0-9]*\.[[:space:]]*//' | cut -d'-' -f1 | xargs)

        if [[ -n "$title" ]]; then
            local sub_issue
            sub_issue="${split_pattern//\{issue\}/$issue}"
            sub_issue="${sub_issue//\{n\}/$n}"

            # Create sub-issue
            local new_issue
            new_issue=$(plugin_call /create "$title" "Parent: $issue

$line")

            if [[ -n "$new_issue" ]]; then
                # Link to parent
                plugin_call /link "$new_issue" "$issue" 2>/dev/null || true

                log_success "Created sub-issue: $new_issue"

                # Update progress file
                echo "- $new_issue: $title" >> "$progress_file"
            fi

            ((n++))
        fi
    done

    log_info "Split recommendations saved to: $progress_file"
    echo ""
    echo "Next steps:"
    echo "  1. Review sub-issues created"
    echo "  2. Run 'barf plan <sub-issue>' for each"
    echo "  3. Run 'barf build <sub-issue>' for each"
}
