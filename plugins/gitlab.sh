#!/bin/bash
# GitLab Issue Plugin for BARF
#
# This plugin manages issues via GitLab using the glab CLI.
# Requires: glab CLI (https://gitlab.com/gitlab-org/cli)

set -euo pipefail

# ============================================================================
# Configuration
# ============================================================================

# Get project from config or detect from git
get_project() {
    local config_file=".barf.yaml"

    # Try config file first
    if [[ -f "$config_file" ]]; then
        local repo
        repo=$(grep -A2 "^source:" "$config_file" 2>/dev/null | grep "repo:" | sed 's/.*repo:[[:space:]]*//' | tr -d '"' | tr -d "'" || echo "")
        if [[ -n "$repo" ]]; then
            echo "$repo"
            return
        fi
    fi

    # Try to detect from git remote
    if command -v git &>/dev/null && git rev-parse --git-dir &>/dev/null; then
        local remote_url
        remote_url=$(git remote get-url origin 2>/dev/null || echo "")

        if [[ -n "$remote_url" ]]; then
            # Handle SSH URLs: git@gitlab.com:group/project.git
            if [[ "$remote_url" =~ git@gitlab\.com:(.+)(\.git)?$ ]]; then
                echo "${BASH_REMATCH[1]%.git}"
                return
            fi
            # Handle HTTPS URLs: https://gitlab.com/group/project.git
            if [[ "$remote_url" =~ gitlab\.com/(.+)(\.git)?$ ]]; then
                echo "${BASH_REMATCH[1]%.git}"
                return
            fi
        fi
    fi

    echo ""
}

PROJECT=$(get_project)

# ============================================================================
# Validation
# ============================================================================

require_glab() {
    if ! command -v glab &>/dev/null; then
        echo "Error: glab CLI not found. Install from https://gitlab.com/gitlab-org/cli" >&2
        exit 1
    fi

    # Check authentication
    if ! glab auth status &>/dev/null; then
        echo "Error: glab CLI not authenticated. Run 'glab auth login'" >&2
        exit 1
    fi
}

require_project() {
    if [[ -z "$PROJECT" ]]; then
        echo "Error: Project not configured." >&2
        echo "Set source.repo in .barf.yaml or run from a git repo with GitLab remote." >&2
        exit 1
    fi
}

# ============================================================================
# Commands
# ============================================================================

cmd_fetch() {
    local issue="${1:-}"
    [[ -z "$issue" ]] && { echo "Usage: /fetch <issue_number>" >&2; exit 1; }

    require_glab
    require_project

    # Get issue
    glab issue view "$issue" --repo "$PROJECT" --output json | jq -r '"# " + .title + "\n\nStatus: " + .state + "\nLabels: " + ([.labels[].name] | join(", ")) + "\n\n" + .description'
}

cmd_update() {
    local issue="${1:-}"
    [[ -z "$issue" ]] && { echo "Usage: /update <issue_number> (body from stdin)" >&2; exit 1; }

    require_glab
    require_project

    # Read new body from stdin
    local body
    body=$(cat)

    # Update issue description
    glab issue update "$issue" --repo "$PROJECT" --description "$body"

    echo "Issue #$issue updated"
}

cmd_comment() {
    local issue="${1:-}"
    shift || true
    local comment="$*"

    [[ -z "$issue" ]] && { echo "Usage: /comment <issue_number> <text>" >&2; exit 1; }
    [[ -z "$comment" ]] && { echo "Usage: /comment <issue_number> <text>" >&2; exit 1; }

    require_glab
    require_project

    glab issue note "$issue" --repo "$PROJECT" --message "$comment"

    echo "Comment added to #$issue"
}

cmd_context() {
    local issue="${1:-}"
    [[ -z "$issue" ]] && { echo "Usage: /context <issue_number>" >&2; exit 1; }

    require_glab
    require_project

    echo "# Issue #$issue"
    echo ""

    # Get issue details
    glab issue view "$issue" --repo "$PROJECT" --comments
}

cmd_status() {
    local issue="${1:-}"
    local new_status="${2:-}"

    [[ -z "$issue" ]] && { echo "Usage: /status <issue_number> [open|closed]" >&2; exit 1; }

    require_glab
    require_project

    if [[ -z "$new_status" ]]; then
        # Get current status
        glab issue view "$issue" --repo "$PROJECT" --output json | jq -r '.state'
    else
        # Set status
        case "$new_status" in
            open|opened)
                glab issue reopen "$issue" --repo "$PROJECT"
                echo "Issue #$issue reopened"
                ;;
            closed|close)
                glab issue close "$issue" --repo "$PROJECT"
                echo "Issue #$issue closed"
                ;;
            *)
                echo "Unknown status: $new_status (use 'open' or 'closed')" >&2
                exit 1
                ;;
        esac
    fi
}

cmd_list() {
    require_glab
    require_project

    # List open issues
    glab issue list --repo "$PROJECT" --output json | jq -r '.[] | "#\(.iid) [\(.state)] \(.title)\(if .labels | length > 0 then " (" + ([.labels[].name] | join(", ")) + ")" else "" end)"'
}

cmd_create() {
    local title="${1:-}"
    shift || true
    local body="$*"

    [[ -z "$title" ]] && { echo "Usage: /create <title> [body]" >&2; exit 1; }

    require_glab
    require_project

    local issue_output
    if [[ -n "$body" ]]; then
        issue_output=$(glab issue create --repo "$PROJECT" --title "$title" --description "$body" --yes)
    else
        issue_output=$(glab issue create --repo "$PROJECT" --title "$title" --description "" --yes)
    fi

    # Extract issue number from output
    local issue_number
    issue_number=$(echo "$issue_output" | grep -oE '#[0-9]+' | tr -d '#' | head -1)

    echo "$issue_number"
}

cmd_link() {
    local child="${1:-}"
    local parent="${2:-}"

    [[ -z "$child" || -z "$parent" ]] && { echo "Usage: /link <child_issue> <parent_issue>" >&2; exit 1; }

    require_glab
    require_project

    # Add label to child indicating parent
    glab issue update "$child" --repo "$PROJECT" --label "parent:#$parent" 2>/dev/null || true

    # Add comment to both issues
    cmd_comment "$child" "Parent issue: #$parent"
    cmd_comment "$parent" "Sub-issue: #$child"

    echo "Linked #$child -> #$parent"
}

# ============================================================================
# Main Entry Point
# ============================================================================

case "${1:-}" in
    /fetch)
        shift
        cmd_fetch "$@"
        ;;
    /update)
        shift
        cmd_update "$@"
        ;;
    /comment)
        shift
        cmd_comment "$@"
        ;;
    /context)
        shift
        cmd_context "$@"
        ;;
    /status)
        shift
        cmd_status "$@"
        ;;
    /list)
        shift
        cmd_list "$@"
        ;;
    /create)
        shift
        cmd_create "$@"
        ;;
    /link)
        shift
        cmd_link "$@"
        ;;
    *)
        echo "BARF GitLab Issue Plugin"
        echo ""
        echo "Commands:"
        echo "  /fetch <number>              Get issue content"
        echo "  /update <number>             Update issue description (content from stdin)"
        echo "  /comment <number> <text>     Add comment to issue"
        echo "  /context <number>            Get issue with all comments"
        echo "  /status <number> [status]    Get or set issue status (open/closed)"
        echo "  /list                        List all open issues"
        echo "  /create <title> [body]       Create new issue"
        echo "  /link <child> <parent>       Link issues"
        echo ""
        echo "Project: ${PROJECT:-<not configured>}"
        echo ""
        echo "Requires: glab CLI (https://gitlab.com/gitlab-org/cli)"
        exit 1
        ;;
esac
