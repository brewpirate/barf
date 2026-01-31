#!/bin/bash
# GitHub Issue Plugin for BARF
#
# This plugin manages issues via GitHub using the gh CLI.
# Requires: gh CLI (https://cli.github.com/)

set -euo pipefail

# ============================================================================
# Configuration
# ============================================================================

# Get repository from config or detect from git
get_repo() {
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
            # Handle SSH URLs: git@github.com:owner/repo.git
            if [[ "$remote_url" =~ git@github\.com:([^/]+)/(.+)(\.git)?$ ]]; then
                echo "${BASH_REMATCH[1]}/${BASH_REMATCH[2]%.git}"
                return
            fi
            # Handle HTTPS URLs: https://github.com/owner/repo.git
            if [[ "$remote_url" =~ github\.com/([^/]+)/(.+)(\.git)?$ ]]; then
                echo "${BASH_REMATCH[1]}/${BASH_REMATCH[2]%.git}"
                return
            fi
        fi
    fi

    echo ""
}

REPO=$(get_repo)

# ============================================================================
# Validation
# ============================================================================

require_gh() {
    if ! command -v gh &>/dev/null; then
        echo "Error: gh CLI not found. Install from https://cli.github.com/" >&2
        exit 1
    fi

    # Check authentication
    if ! gh auth status &>/dev/null; then
        echo "Error: gh CLI not authenticated. Run 'gh auth login'" >&2
        exit 1
    fi
}

require_repo() {
    if [[ -z "$REPO" ]]; then
        echo "Error: Repository not configured." >&2
        echo "Set source.repo in .barf.yaml or run from a git repo with GitHub remote." >&2
        exit 1
    fi
}

# ============================================================================
# Commands
# ============================================================================

cmd_fetch() {
    local issue="${1:-}"
    [[ -z "$issue" ]] && { echo "Usage: /fetch <issue_number>" >&2; exit 1; }

    require_gh
    require_repo

    # Get issue body
    gh issue view "$issue" --repo "$REPO" --json title,body,state,labels --template '# {{.title}}

Status: {{.state}}
Labels: {{range .labels}}{{.name}} {{end}}

{{.body}}'
}

cmd_update() {
    local issue="${1:-}"
    [[ -z "$issue" ]] && { echo "Usage: /update <issue_number> (body from stdin)" >&2; exit 1; }

    require_gh
    require_repo

    # Read new body from stdin
    local body
    body=$(cat)

    # Update issue body
    gh issue edit "$issue" --repo "$REPO" --body "$body"

    echo "Issue #$issue updated"
}

cmd_comment() {
    local issue="${1:-}"
    shift || true
    local comment="$*"

    [[ -z "$issue" ]] && { echo "Usage: /comment <issue_number> <text>" >&2; exit 1; }
    [[ -z "$comment" ]] && { echo "Usage: /comment <issue_number> <text>" >&2; exit 1; }

    require_gh
    require_repo

    gh issue comment "$issue" --repo "$REPO" --body "$comment"

    echo "Comment added to #$issue"
}

cmd_context() {
    local issue="${1:-}"
    [[ -z "$issue" ]] && { echo "Usage: /context <issue_number>" >&2; exit 1; }

    require_gh
    require_repo

    # Get issue with comments
    echo "# Issue #$issue"
    echo ""
    gh issue view "$issue" --repo "$REPO" --json title,body,state,labels,comments --template '## {{.title}}

**Status:** {{.state}}
**Labels:** {{range .labels}}{{.name}} {{end}}

---

{{.body}}

---

## Comments

{{range .comments}}
### Comment by {{.author.login}} ({{.createdAt}})

{{.body}}

---

{{end}}'
}

cmd_status() {
    local issue="${1:-}"
    local new_status="${2:-}"

    [[ -z "$issue" ]] && { echo "Usage: /status <issue_number> [open|closed]" >&2; exit 1; }

    require_gh
    require_repo

    if [[ -z "$new_status" ]]; then
        # Get current status
        gh issue view "$issue" --repo "$REPO" --json state --jq '.state'
    else
        # Set status
        case "$new_status" in
            open)
                gh issue reopen "$issue" --repo "$REPO"
                echo "Issue #$issue reopened"
                ;;
            closed|close)
                gh issue close "$issue" --repo "$REPO"
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
    require_gh
    require_repo

    # List open issues
    gh issue list --repo "$REPO" --json number,title,state,labels --template '{{range .}}#{{.number}} [{{.state}}] {{.title}}{{if .labels}} ({{range .labels}}{{.name}} {{end}}){{end}}
{{end}}'
}

cmd_create() {
    local title="${1:-}"
    shift || true
    local body="$*"

    [[ -z "$title" ]] && { echo "Usage: /create <title> [body]" >&2; exit 1; }

    require_gh
    require_repo

    local issue_url
    if [[ -n "$body" ]]; then
        issue_url=$(gh issue create --repo "$REPO" --title "$title" --body "$body")
    else
        issue_url=$(gh issue create --repo "$REPO" --title "$title" --body "")
    fi

    # Extract issue number from URL
    local issue_number
    issue_number=$(echo "$issue_url" | grep -oE '[0-9]+$')

    echo "$issue_number"
}

cmd_link() {
    local child="${1:-}"
    local parent="${2:-}"

    [[ -z "$child" || -z "$parent" ]] && { echo "Usage: /link <child_issue> <parent_issue>" >&2; exit 1; }

    require_gh
    require_repo

    # Add label to child indicating parent
    gh issue edit "$child" --repo "$REPO" --add-label "parent:#$parent" 2>/dev/null || true

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
        echo "BARF GitHub Issue Plugin"
        echo ""
        echo "Commands:"
        echo "  /fetch <number>              Get issue content"
        echo "  /update <number>             Update issue body (content from stdin)"
        echo "  /comment <number> <text>     Add comment to issue"
        echo "  /context <number>            Get issue with all comments"
        echo "  /status <number> [status]    Get or set issue status (open/closed)"
        echo "  /list                        List all open issues"
        echo "  /create <title> [body]       Create new issue"
        echo "  /link <child> <parent>       Link issues"
        echo ""
        echo "Repository: ${REPO:-<not configured>}"
        echo ""
        echo "Requires: gh CLI (https://cli.github.com/)"
        exit 1
        ;;
esac
