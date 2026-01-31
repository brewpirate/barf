#!/bin/bash
# BARF Command: new
# Create new issue from template

cmd_new() {
    local template_type="${1:-}"
    local title="${2:-}"

    if [[ -z "$template_type" ]] || [[ -z "$title" ]]; then
        log_error "Missing required arguments"
        echo "Usage: barf new <type> <title>"
        echo ""
        echo "Available templates:"
        echo "  feature   - New feature request"
        echo "  bug       - Bug report"
        echo "  refactor  - Code refactoring"
        echo "  docs      - Documentation update"
        echo "  test      - Add/improve tests"
        echo "  chore     - Maintenance task"
        exit 1
    fi

    print_header "Creating New Issue: $template_type"

    local issues_dir
    issues_dir=$(config_get "source.path" "$DEFAULT_ISSUES_DIR")

    # Convert title to filename (lowercase, replace spaces with dashes)
    local filename
    filename=$(echo "$title" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd 'a-z0-9-')
    local issue_file="$issues_dir/$filename.md"

    if [[ $DRY_RUN -eq 1 ]]; then
        log_dry_run "Would create issue file: $issue_file"
        log_dry_run "Template type: $template_type"
        log_dry_run "Title: $title"
        echo ""
        echo -e "${CYAN}--- Template Preview ---${NC}"
        generate_template "$template_type" "$title"
        echo -e "${CYAN}--- End Preview ---${NC}"
        return 0
    fi

    mkdir -p "$issues_dir"

    if [[ -f "$issue_file" ]]; then
        log_error "Issue file already exists: $issue_file"
        exit 1
    fi

    log_info "Creating issue from '$template_type' template..."
    log_verbose "File: $issue_file"

    generate_template "$template_type" "$title" > "$issue_file"

    log_success "Created: $issue_file"
    log_info "Edit the file and then create the GitHub issue with:"
    echo "  gh issue create --title \"$title\" --body-file \"$issue_file\""
}

generate_template() {
    local type="$1"
    local title="$2"

    case "$type" in
        feature)
            cat << EOF
# $title

## Summary
[Brief description of the feature]

## Motivation
[Why is this feature needed? What problem does it solve?]

## Detailed Description
[Detailed explanation of the feature]

## Acceptance Criteria
- [ ] [Criterion 1]
- [ ] [Criterion 2]
- [ ] [Criterion 3]

## Technical Considerations
- **Affected areas:** [List components/files likely to change]
- **Dependencies:** [External dependencies or related issues]
- **Performance:** [Any performance considerations]

## Design Notes
[Optional: API design, UI mockups, architecture decisions]

## Out of Scope
[What this feature explicitly does NOT include]

## Testing Requirements
- [ ] Unit tests for [component]
- [ ] Integration tests for [flow]
- [ ] Manual testing for [scenario]
EOF
            ;;
        bug)
            cat << EOF
# Bug: $title

## Summary
[One-line description of the bug]

## Environment
- **OS:** [e.g., macOS 14.0, Ubuntu 22.04]
- **Version:** [e.g., v1.2.3, commit hash]
- **Browser:** [if applicable]

## Steps to Reproduce
1. [Step 1]
2. [Step 2]
3. [Step 3]

## Expected Behavior
[What should happen]

## Actual Behavior
[What actually happens]

## Error Messages
\`\`\`
[Paste any error messages or stack traces]
\`\`\`

## Screenshots
[If applicable]

## Additional Context
[Any other relevant information]

## Acceptance Criteria
- [ ] Bug no longer reproducible
- [ ] Regression test added
- [ ] No new issues introduced
EOF
            ;;
        refactor)
            cat << EOF
# Refactor: $title

## Summary
[Brief description of what needs refactoring]

## Current State
[Describe the current implementation and its problems]

## Proposed Changes
[Describe the refactoring approach]

## Motivation
- [ ] Improve maintainability
- [ ] Improve performance
- [ ] Reduce complexity
- [ ] Enable future features
- [ ] Fix technical debt

## Affected Areas
- [File/component 1]
- [File/component 2]

## Acceptance Criteria
- [ ] All existing tests pass
- [ ] No functionality changes (unless specified)
- [ ] Code review approved
- [ ] Documentation updated if needed

## Risks
[Potential risks and mitigation strategies]

## Testing Plan
- [ ] Existing tests cover changes
- [ ] Manual regression testing for [areas]
EOF
            ;;
        docs)
            cat << EOF
# Documentation: $title

## Summary
[What documentation needs to be added/updated]

## Type
- [ ] New documentation
- [ ] Update existing docs
- [ ] Fix inaccuracies
- [ ] Improve clarity

## Scope
[Which docs/sections are affected]

## Content Outline
1. [Section 1]
2. [Section 2]
3. [Section 3]

## Acceptance Criteria
- [ ] Documentation is accurate
- [ ] Examples are working
- [ ] Links are valid
- [ ] Follows style guide
EOF
            ;;
        test)
            cat << EOF
# Testing: $title

## Summary
[What tests need to be added/improved]

## Type
- [ ] Unit tests
- [ ] Integration tests
- [ ] End-to-end tests
- [ ] Performance tests

## Coverage Target
[Specific areas/functions that need test coverage]

## Test Cases
- [ ] [Test case 1]
- [ ] [Test case 2]
- [ ] [Test case 3]

## Acceptance Criteria
- [ ] Test coverage increased to [X]%
- [ ] All new tests pass
- [ ] Tests are maintainable and clear
- [ ] Edge cases covered
EOF
            ;;
        chore)
            cat << EOF
# Chore: $title

## Summary
[Brief description of the maintenance task]

## Type
- [ ] Dependency update
- [ ] CI/CD improvement
- [ ] Build optimization
- [ ] Cleanup
- [ ] Configuration

## Tasks
- [ ] [Task 1]
- [ ] [Task 2]
- [ ] [Task 3]

## Acceptance Criteria
- [ ] [Criterion 1]
- [ ] [Criterion 2]
- [ ] Build/tests still pass
EOF
            ;;
        *)
            log_error "Unknown template type: $type"
            echo "Available types: feature, bug, refactor, docs, test, chore"
            exit 1
            ;;
    esac
}
