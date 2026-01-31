#!/bin/bash
# Local Markdown Issue Plugin for BARF
#
# This plugin manages issues as local markdown files.
# Default issue source for BARF.

set -euo pipefail

# ============================================================================
# Configuration
# ============================================================================

# Get issues directory from config or use default
get_issues_dir() {
    local config_file=".barf.yaml"
    if [[ -f "$config_file" ]]; then
        local path
        path=$(grep -A1 "^source:" "$config_file" 2>/dev/null | grep "path:" | sed 's/.*path:[[:space:]]*//' | tr -d '"' | tr -d "'" || echo "")
        echo "${path:-./issues}"
    else
        echo "./issues"
    fi
}

ISSUES_DIR=$(get_issues_dir)

# ============================================================================
# Helper Functions
# ============================================================================

# Find issue file (handles with/without .md extension)
find_issue_file() {
    local issue="$1"

    if [[ -f "$ISSUES_DIR/$issue.md" ]]; then
        echo "$ISSUES_DIR/$issue.md"
    elif [[ -f "$ISSUES_DIR/$issue" ]]; then
        echo "$ISSUES_DIR/$issue"
    else
        return 1
    fi
}

# Sanitize string for use as filename
sanitize_filename() {
    echo "$1" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd '[:alnum:]-_'
}

# ============================================================================
# Commands
# ============================================================================

cmd_fetch() {
    local issue="${1:-}"
    [[ -z "$issue" ]] && { echo "Usage: /fetch <issue>" >&2; exit 1; }

    local file
    if file=$(find_issue_file "$issue"); then
        cat "$file"
    else
        echo "Issue not found: $issue" >&2
        echo "Looked in: $ISSUES_DIR/$issue.md" >&2
        exit 1
    fi
}

cmd_update() {
    local issue="${1:-}"
    [[ -z "$issue" ]] && { echo "Usage: /update <issue> (content from stdin)" >&2; exit 1; }

    mkdir -p "$ISSUES_DIR"

    local file
    if file=$(find_issue_file "$issue" 2>/dev/null); then
        cat > "$file"
    else
        # Create new file with .md extension
        cat > "$ISSUES_DIR/$issue.md"
    fi
    echo "Issue updated: $issue"
}

cmd_comment() {
    local issue="${1:-}"
    shift || true
    local comment="$*"

    [[ -z "$issue" ]] && { echo "Usage: /comment <issue> <text>" >&2; exit 1; }
    [[ -z "$comment" ]] && { echo "Usage: /comment <issue> <text>" >&2; exit 1; }

    local file
    if ! file=$(find_issue_file "$issue"); then
        echo "Issue not found: $issue" >&2
        exit 1
    fi

    # Append comment with timestamp
    {
        echo ""
        echo "---"
        echo ""
        echo "**Comment** ($(date '+%Y-%m-%d %H:%M')):"
        echo ""
        echo "$comment"
    } >> "$file"

    echo "Comment added to: $issue"
}

cmd_context() {
    # For local files, context is the same as fetch
    cmd_fetch "$@"
}

cmd_status() {
    local issue="${1:-}"
    local new_status="${2:-}"

    [[ -z "$issue" ]] && { echo "Usage: /status <issue> [new_status]" >&2; exit 1; }

    local file
    if ! file=$(find_issue_file "$issue"); then
        echo "Issue not found: $issue" >&2
        exit 1
    fi

    if [[ -z "$new_status" ]]; then
        # Get status from YAML frontmatter
        if head -1 "$file" | grep -q "^---"; then
            local status
            status=$(sed -n '2,/^---$/p' "$file" | grep "^status:" | sed 's/status:[[:space:]]*//' || echo "")
            if [[ -n "$status" ]]; then
                echo "$status"
            else
                echo "open"
            fi
        else
            echo "open"
        fi
    else
        # Set status in YAML frontmatter
        if head -1 "$file" | grep -q "^---"; then
            # Check if status line exists
            if grep -q "^status:" "$file"; then
                # Update existing status
                sed -i "s/^status:.*/status: $new_status/" "$file"
            else
                # Add status to existing frontmatter
                sed -i "2i status: $new_status" "$file"
            fi
        else
            # Add new frontmatter
            local content
            content=$(cat "$file")
            {
                echo "---"
                echo "status: $new_status"
                echo "---"
                echo ""
                echo "$content"
            } > "$file"
        fi
        echo "Status set to: $new_status"
    fi
}

cmd_list() {
    if [[ -d "$ISSUES_DIR" ]]; then
        find "$ISSUES_DIR" -maxdepth 1 -name "*.md" -type f 2>/dev/null | while read -r file; do
            local name
            name=$(basename "$file" .md)
            local status
            status=$(cmd_status "$name" 2>/dev/null || echo "open")
            echo "$name ($status)"
        done | sort
    fi
}

cmd_create() {
    local title="${1:-}"
    shift || true
    local body="$*"

    [[ -z "$title" ]] && { echo "Usage: /create <title> [body]" >&2; exit 1; }

    # Sanitize title for filename
    local filename
    filename=$(sanitize_filename "$title")

    # Ensure unique filename
    local counter=1
    local final_name="$filename"
    while [[ -f "$ISSUES_DIR/$final_name.md" ]]; do
        final_name="${filename}-${counter}"
        ((counter++))
    done

    mkdir -p "$ISSUES_DIR"

    {
        echo "---"
        echo "status: open"
        echo "created: $(date '+%Y-%m-%d %H:%M')"
        echo "---"
        echo ""
        echo "# $title"
        echo ""
        if [[ -n "$body" ]]; then
            echo "$body"
        else
            echo "## Requirements"
            echo ""
            echo "<!-- Add requirements here -->"
            echo ""
            echo "## Acceptance Criteria"
            echo ""
            echo "<!-- Add acceptance criteria here -->"
        fi
    } > "$ISSUES_DIR/$final_name.md"

    # Return the filename (without .md)
    echo "$final_name"
}

cmd_link() {
    local child="${1:-}"
    local parent="${2:-}"

    [[ -z "$child" || -z "$parent" ]] && { echo "Usage: /link <child> <parent>" >&2; exit 1; }

    # Add parent reference to child
    cmd_comment "$child" "Parent issue: [[$parent]]"

    # Add child reference to parent
    cmd_comment "$parent" "Sub-issue: [[$child]]"

    echo "Linked $child -> $parent"
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
        echo "BARF Local Issue Plugin"
        echo ""
        echo "Commands:"
        echo "  /fetch <issue>              Get issue content"
        echo "  /update <issue>             Update issue (content from stdin)"
        echo "  /comment <issue> <text>     Add comment to issue"
        echo "  /context <issue>            Get full issue context"
        echo "  /status <issue> [status]    Get or set issue status"
        echo "  /list                       List all issues"
        echo "  /create <title> [body]      Create new issue"
        echo "  /link <child> <parent>      Link issues"
        echo ""
        echo "Issues directory: $ISSUES_DIR"
        exit 1
        ;;
esac
