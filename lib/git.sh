#!/bin/bash
# BARF Library: Git Branch Automation
# Automatic branch creation and management for issues

# Get branch name for issue based on configuration
get_branch_name() {
    local issue="$1"
    local format
    format=$(config_get "git.branch_format" "feat/{issue}")

    local branch_name="${format//\{issue\}/$issue}"
    local issue_number
    issue_number=$(echo "$issue" | grep -oE '[0-9]+' | head -1)
    branch_name="${branch_name//\{issue_number\}/$issue_number}"

    echo "$branch_name"
}

# Check if git branch automation is enabled
is_auto_branch_enabled() {
    local enabled
    enabled=$(config_get "git.auto_branch" "false")
    [[ "$enabled" == "true" ]]
}

# Create and checkout branch for issue
setup_issue_branch() {
    local issue="$1"

    if ! is_auto_branch_enabled; then
        return 0
    fi

    # Check if we're in a git repo
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        log_verbose "Not a git repository, skipping branch automation"
        return 0
    fi

    local branch_name
    branch_name=$(get_branch_name "$issue")

    local current_branch
    current_branch=$(git branch --show-current 2>/dev/null || echo "")

    if [[ "$current_branch" == "$branch_name" ]]; then
        log_verbose "Already on branch: $branch_name"
        return 0
    fi

    if git show-ref --verify --quiet "refs/heads/$branch_name" 2>/dev/null; then
        log_info "Switching to existing branch: $branch_name"
        git checkout "$branch_name"
    else
        log_info "Creating new branch: $branch_name"
        local base_branch
        base_branch=$(config_get "git.base_branch" "")

        if [[ -n "$base_branch" ]]; then
            git checkout -b "$branch_name" "$base_branch"
        else
            git checkout -b "$branch_name"
        fi
    fi

    log_success "Branch ready: $branch_name"
}
