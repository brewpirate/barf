#!/bin/bash
# BARF Command: init
# Initialize BARF in current directory

cmd_init() {
    log_info "Initializing BARF in current directory..."

    # Create config file
    if [[ ! -f "$CONFIG_FILE" ]]; then
        cat > "$CONFIG_FILE" << 'EOF'
# BARF Configuration

source:
  type: local
  path: ./issues

issues:
  reference: filename

commands:
  fetch: /fetch
  update: /update
  comment: /comment
  context: /context
  status: /status
  list: /list
  create: /create
  link: /link

plans:
  path: ./plans

split:
  enabled: true
  max_retries: 3
  pattern: "{issue}-part{n}"

models:
  fast: haiku
  default: sonnet
  complex: opus

build:
  commit_format: "feat({issue}): {task}"
  run_tests: true

interview:
  auto_update: true
  use_comments: true

audit:
  output: ./AUDIT_REPORT.md
EOF
        log_success "Created $CONFIG_FILE"
    else
        log_warn "$CONFIG_FILE already exists, skipping"
    fi

    # Create directories
    local issues_dir
    issues_dir=$(config_get "source.path" "$DEFAULT_ISSUES_DIR")

    local plans_dir
    plans_dir=$(config_get "plans.path" "$DEFAULT_PLANS_DIR")

    mkdir -p "$issues_dir" && log_success "Created $issues_dir/"
    mkdir -p "$plans_dir" && log_success "Created $plans_dir/"
    mkdir -p "$(dirname "$0")/plugins" && log_success "Created plugins/"

    # Create AGENTS.md if it doesn't exist
    if [[ ! -f "AGENTS.md" ]]; then
        cat > "AGENTS.md" << 'EOF'
# AGENTS.md - Operational Guide

This file contains operational information for autonomous agents working on this codebase.

## Project Overview

<!-- Describe your project here -->

## Development Commands

```bash
# Install dependencies
# npm install

# Run tests
# npm test

# Build
# npm run build

# Lint
# npm run lint
```

## Architecture Notes

<!-- Describe key architectural decisions -->

## Common Patterns

<!-- Document patterns used in this codebase -->

## Known Issues

<!-- Document known issues or gotchas -->
EOF
        log_success "Created AGENTS.md"
    else
        log_warn "AGENTS.md already exists, skipping"
    fi

    # Create prompt files
    create_prompt_files

    # Create default local plugin
    create_local_plugin

    log_success "BARF initialized successfully!"
    echo ""
    echo "Next steps:"
    echo "  1. Edit .barf.yaml to configure your project"
    echo "  2. Edit AGENTS.md with your project details"
    echo "  3. Create issues in $issues_dir/"
    echo "  4. Run: barf interview <issue>"
}

create_prompt_files() {
    # PROMPT_interview.md
    if [[ ! -f "PROMPT_interview.md" ]]; then
        cat > "PROMPT_interview.md" << 'PROMPT_EOF'
# Interview Mode Instructions

You are analyzing an issue to identify ambiguities and missing information.

## Your Task

1. Read the issue content carefully
2. Identify any ambiguities:
   - Unclear acceptance criteria
   - Missing technical constraints
   - Undefined edge cases
   - Implementation approach decisions needed
3. Ask clarifying questions using the AskUserQuestion tool
4. Update the issue with clarifications

## Guidelines

- Be thorough but not pedantic
- Focus on information needed for implementation
- Group related questions together
- Provide context for why each question matters

## Output Format

For each ambiguity found:
1. Quote the relevant part of the issue
2. Explain why it's ambiguous
3. Ask a specific clarifying question
4. Suggest options if applicable

After all clarifications:
- Summarize the clarifications
- Update the issue with the new information
PROMPT_EOF
        log_success "Created PROMPT_interview.md"
    fi

    # PROMPT_plan.md
    if [[ ! -f "PROMPT_plan.md" ]]; then
        cat > "PROMPT_plan.md" << 'PROMPT_EOF'
# Planning Mode Instructions

You are creating a detailed implementation plan from an issue.

## Your Task

1. Read the issue requirements thoroughly
2. Study the existing codebase using parallel subagents
3. Create a step-by-step implementation plan
4. Save the plan to the plans directory

## Plan Structure

```markdown
# Implementation Plan for {issue}

## Issue Summary
Brief description of what needs to be done

## Acceptance Criteria
- List each criterion from the issue
- Map to specific line numbers in the issue

## Implementation Tasks

### Task 1: {title}
**Requirements:**
- Which issue requirements this addresses (with line refs)

**Implementation:**
1. Specific step
2. Specific step
3. Specific step

**Files affected:**
- path/to/file.ts (new file | modify | delete)
- path/to/other.ts:123-145 (specific lines)

**Validation:**
- How to verify this task is complete
- Specific test cases

**Risks:**
- Potential issues or blockers

### Task 2: {title}
...
```

## Guidelines

- Be exhaustive - cover all requirements
- Be specific - include file paths and line numbers
- Be practical - order tasks by dependencies
- Be cautious - identify risks early

## Context Limit Handling

If you detect that the issue is too large:
1. Create a partial plan with completed tasks
2. Document which requirements are not yet planned
3. Recommend how to split the issue
4. Save progress before context runs out
PROMPT_EOF
        log_success "Created PROMPT_plan.md"
    fi

    # PROMPT_build.md
    if [[ ! -f "PROMPT_build.md" ]]; then
        cat > "PROMPT_build.md" << 'PROMPT_EOF'
# Building Mode Instructions

You are implementing code based on an existing plan.

## Your Task

1. Read the plan file for this issue
2. Select the most important incomplete task
3. Implement it completely
4. Run tests to verify
5. Commit if successful
6. Update the plan to mark task complete

## Guidelines

- Never assume - always search the codebase first
- Use parallel subagents to explore code
- Follow existing patterns in the codebase
- Run tests after each change (backpressure)
- Make atomic commits for each task

## When Stuck

If you cannot complete a task:
1. Document what you've tried
2. Explain the blocker
3. Create progress notes file
4. Recommend next steps

Progress notes format:
```markdown
# Progress Notes for {issue}

## Current State
- [x] Completed tasks
- [ ] Incomplete tasks

## Current Task
What you were working on

## How We Got Here
Step by step history

## The Problem
What's blocking progress

## What Was Tried
- Attempt 1: approach - result
- Attempt 2: approach - result

## Recommendations
Options to resolve the blocker
```

## Context Limit Handling

If context is filling up:
1. Save all progress immediately
2. Create progress notes
3. Document remaining tasks
4. Recommend issue split if needed
PROMPT_EOF
        log_success "Created PROMPT_build.md"
    fi

    # PROMPT_audit.md
    if [[ ! -f "PROMPT_audit.md" ]]; then
        cat > "PROMPT_audit.md" << 'PROMPT_EOF'
# Audit Mode Instructions

You are performing a comprehensive quality audit of the codebase.

## Your Task

1. Analyze the entire codebase
2. Check for issues across multiple dimensions
3. Create a prioritized report

## Audit Dimensions

### Code Quality
- Code style consistency
- Error handling
- Performance issues
- Security vulnerabilities
- Dead code

### Issue Compliance
- Are all accepted issues fully implemented?
- Do implementations match requirements?
- Are there undocumented features?

### Test Coverage
- Are critical paths tested?
- Are edge cases covered?
- Are tests meaningful or just coverage padding?

### Technical Debt
- Outdated dependencies
- TODO/FIXME comments
- Workarounds that need proper fixes
- Documentation gaps

### Consistency
- Naming conventions
- File organization
- API patterns
- Error message formats

## Report Format

```markdown
# Audit Report

Generated: {date}

## Summary
- Critical: X issues
- High: X issues
- Medium: X issues
- Low: X issues

## Critical Issues
### {title}
- **Location:** file:line
- **Description:** What's wrong
- **Impact:** Why it matters
- **Recommendation:** How to fix

## High Priority
...

## Medium Priority
...

## Low Priority
...

## Recommendations
Prioritized list of improvements
```

## Guidelines

- Be objective and specific
- Provide actionable recommendations
- Include file paths and line numbers
- Prioritize by impact and effort
PROMPT_EOF
        log_success "Created PROMPT_audit.md"
    fi
}

create_local_plugin() {
    local plugin_dir="$(dirname "$0")/plugins"
    local plugin_path="$plugin_dir/local.sh"

    mkdir -p "$plugin_dir"

    if [[ ! -f "$plugin_path" ]]; then
        cat > "$plugin_path" << 'PLUGIN_EOF'
#!/bin/bash
# Local Markdown Issue Plugin for BARF

set -euo pipefail

# Get issues directory from config or use default
get_issues_dir() {
    local config_file=".barf.yaml"
    if [[ -f "$config_file" ]]; then
        local path
        path=$(grep -A1 "^source:" "$config_file" | grep "path:" | sed 's/.*path:[[:space:]]*//' | tr -d '"' | tr -d "'")
        echo "${path:-./issues}"
    else
        echo "./issues"
    fi
}

ISSUES_DIR=$(get_issues_dir)

case "${1:-}" in
    /fetch)
        # Fetch issue content
        issue="${2:-}"
        [[ -z "$issue" ]] && { echo "Usage: /fetch <issue>"; exit 1; }

        # Try with and without .md extension
        if [[ -f "$ISSUES_DIR/$issue.md" ]]; then
            cat "$ISSUES_DIR/$issue.md"
        elif [[ -f "$ISSUES_DIR/$issue" ]]; then
            cat "$ISSUES_DIR/$issue"
        else
            echo "Issue not found: $issue" >&2
            exit 1
        fi
        ;;

    /update)
        # Update issue content (reads from stdin)
        issue="${2:-}"
        [[ -z "$issue" ]] && { echo "Usage: /update <issue>"; exit 1; }

        if [[ -f "$ISSUES_DIR/$issue.md" ]]; then
            cat > "$ISSUES_DIR/$issue.md"
        elif [[ -f "$ISSUES_DIR/$issue" ]]; then
            cat > "$ISSUES_DIR/$issue"
        else
            # Create new file with .md extension
            cat > "$ISSUES_DIR/$issue.md"
        fi
        echo "Issue updated: $issue"
        ;;

    /comment)
        # Add comment to issue
        issue="${2:-}"
        comment="${3:-}"
        [[ -z "$issue" ]] && { echo "Usage: /comment <issue> <text>"; exit 1; }

        local file
        if [[ -f "$ISSUES_DIR/$issue.md" ]]; then
            file="$ISSUES_DIR/$issue.md"
        elif [[ -f "$ISSUES_DIR/$issue" ]]; then
            file="$ISSUES_DIR/$issue"
        else
            echo "Issue not found: $issue" >&2
            exit 1
        fi

        # Append comment with timestamp
        {
            echo ""
            echo "---"
            echo "**Comment** ($(date '+%Y-%m-%d %H:%M')):"
            echo "$comment"
        } >> "$file"
        echo "Comment added to: $issue"
        ;;

    /context)
        # Get full context (same as fetch for local files)
        issue="${2:-}"
        [[ -z "$issue" ]] && { echo "Usage: /context <issue>"; exit 1; }

        "$0" /fetch "$issue"
        ;;

    /status)
        # Get or set issue status (stored as YAML frontmatter)
        issue="${2:-}"
        new_status="${3:-}"
        [[ -z "$issue" ]] && { echo "Usage: /status <issue> [status]"; exit 1; }

        local file
        if [[ -f "$ISSUES_DIR/$issue.md" ]]; then
            file="$ISSUES_DIR/$issue.md"
        elif [[ -f "$ISSUES_DIR/$issue" ]]; then
            file="$ISSUES_DIR/$issue"
        else
            echo "Issue not found: $issue" >&2
            exit 1
        fi

        if [[ -z "$new_status" ]]; then
            # Get status from frontmatter
            if head -1 "$file" | grep -q "^---"; then
                sed -n '2,/^---$/p' "$file" | grep "^status:" | sed 's/status:[[:space:]]*//'
            else
                echo "open"
            fi
        else
            # Set status in frontmatter
            if head -1 "$file" | grep -q "^---"; then
                # Update existing frontmatter
                sed -i "s/^status:.*/status: $new_status/" "$file"
            else
                # Add frontmatter
                local content
                content=$(cat "$file")
                {
                    echo "---"
                    echo "status: $new_status"
                    echo "---"
                    echo "$content"
                } > "$file"
            fi
            echo "Status set to: $new_status"
        fi
        ;;

    /list)
        # List all issues
        if [[ -d "$ISSUES_DIR" ]]; then
            find "$ISSUES_DIR" -name "*.md" -type f | while read -r file; do
                basename "$file" .md
            done
        fi
        ;;

    /create)
        # Create new issue
        title="${2:-}"
        body="${3:-}"
        [[ -z "$title" ]] && { echo "Usage: /create <title> [body]"; exit 1; }

        # Sanitize title for filename
        local filename
        filename=$(echo "$title" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd '[:alnum:]-')

        mkdir -p "$ISSUES_DIR"

        {
            echo "# $title"
            echo ""
            if [[ -n "$body" ]]; then
                echo "$body"
            fi
        } > "$ISSUES_DIR/$filename.md"

        echo "$filename"
        ;;

    /link)
        # Link child issue to parent
        child="${2:-}"
        parent="${3:-}"
        [[ -z "$child" || -z "$parent" ]] && { echo "Usage: /link <child> <parent>"; exit 1; }

        "$0" /comment "$child" "Parent issue: $parent"
        "$0" /comment "$parent" "Sub-issue: $child"
        echo "Linked $child to $parent"
        ;;

    *)
        echo "Unknown command: ${1:-}"
        echo "Available commands: /fetch, /update, /comment, /context, /status, /list, /create, /link"
        exit 1
        ;;
esac
PLUGIN_EOF
        chmod +x "$plugin_path"
        log_success "Created plugins/local.sh"
    fi
}
