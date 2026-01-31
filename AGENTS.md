# BARF Operational Guide

This file contains operational learnings and patterns for BARF.

## Project Configuration

### Test Commands
```bash
# Add your test commands here
# npm test
# pytest
# go test ./...
```

### Build Commands
```bash
# Add your build commands here
# npm run build
# make build
```

### Lint Commands
```bash
# Add your lint commands here
# npm run lint
# eslint .
```

## Learned Patterns

Document patterns discovered during implementation:

### Code Style
- [Add patterns as they're discovered]

### Architecture Decisions
- [Add decisions as they're made]

### Common Gotchas
- [Add gotchas as they're encountered]

## Issue Templates

When creating sub-issues, use these patterns:

### Sub-issue Format
```markdown
Title: [Parent Feature] - [Specific Task]
Labels: parent:#<parent_issue_number>

## Context
This is a sub-issue of #<parent_number>.

## Scope
[Specific scope for this sub-issue]

## Acceptance Criteria
- [ ] [Criterion 1]
- [ ] [Criterion 2]
```

## Recovery Procedures

### When Stuck
1. Check `plans/issue-N-progress.md` for context
2. Review what was tried
3. Consider alternative approaches
4. If stuck 3+ times, split the issue

### When Context Limit Reached
1. Check for partial plans/progress
2. Create sub-issues as recommended
3. Resume with fresh context on smaller scope

### When Tests Keep Failing
1. Check if tests themselves need updating
2. Review acceptance criteria interpretation
3. Check for environment issues
4. Consider if approach needs rethinking

## Commit Conventions

```
type(#issue): subject

Types:
- feat: New feature
- fix: Bug fix
- refactor: Code refactoring
- test: Adding tests
- docs: Documentation
- chore: Maintenance
```
