# BARF - Build And Run Framework

![woof](assets/barf.png)

**Issue-Driven Autonomous Development based on the Ralph Playbook**

BARF is a bash tool that implements the [Ralph playbook](https://github.com/ClaytonFarr/ralph-playbook) methodology with a focus on **issue-driven development**. Point it at an issue (local file, GitHub, GitLab), and it autonomously clarifies, plans, and implements.

## Core Innovation: Issue-Driven with Pluggable Sources

BARF works with multiple issue sources through a **plugin system**:

- **Local Markdown** (default) - Issues as `.md` files in your repo
- **GitHub** - Via `gh` CLI
- **GitLab** - Via `glab` CLI
- **Custom** - Write your own plugin

### Modes

- **Interview Mode** - Scans issues for ambiguities, asks clarifying questions
- **Planning Mode** - Generates detailed implementation plans with context splitting
- **Building Mode** - Implements autonomously, saves progress when stuck
- **Auditing Mode** - Verifies quality and compliance

## Key Features

### Pluggable Issue Sources
Configure your issue source in `.barf.yaml`:
```yaml
source:
  type: local          # local | github | gitlab
  path: ./issues       # for local plugin
```

### Automatic Model Selection
BARF picks the optimal Claude model for each task:
- **Haiku** - Quick lookups, simple analysis
- **Sonnet** - Planning, code generation
- **Opus** - Complex reasoning, architecture decisions

### Automatic Context Splitting
When an issue is too large for context:
- Planning/building mode detects context limits
- **Automatically splits** issue into sub-issues
- Retries with smaller scope
- Links sub-issues to parent

### Progress Notes
When stuck, BARF creates detailed notes:
- What was accomplished
- How we got here (step-by-step)
- What's blocking progress
- What was tried
- Recommendations for next steps

### Strict Requirements
Plans include:
- Line-by-line mapping to issue requirements
- File references
- Specific validation steps
- Edge cases from acceptance criteria

## Quick Start

```bash
# 1. Initialize BARF in your project
barf init

# 2. Create an issue (local markdown by default)
echo "# Add user authentication

## Requirements
- Users can log in with email/password
- Sessions persist for 30 days
- Logout clears session
" > issues/auth.md

# 3. Clarify ambiguities
barf interview auth

# 4. Generate detailed plan
barf plan auth

# 5. Build autonomously (max 20 iterations)
barf build auth 20

# 6. Audit quality
barf audit
```

## Installation

```bash
# Download
curl -o barf https://raw.githubusercontent.com/brewpirate/barf/main/barf
chmod +x barf

# Move to PATH
sudo mv barf /usr/local/bin/

# Requires: Claude CLI
# Install: https://github.com/anthropics/anthropic-claude-cli
```

## Configuration

Create `.barf.yaml` in your project root:

```yaml
# Issue source plugin
source:
  type: local              # local | github | gitlab
  path: ./issues           # directory for local issues
  # repo: owner/repo       # for github/gitlab plugins

# Issue referencing
issues:
  reference: filename      # filename | number

# Plugin commands (customizable)
commands:
  fetch: /fetch
  update: /update
  comment: /comment
  context: /context
  status: /status
  list: /list

# Output paths
plans:
  path: ./plans

# Auto-split settings
split:
  enabled: true
  max_retries: 3
```

## Modes

### 1. Interview Mode

Scans issue for missing details and asks clarifying questions.

```bash
barf interview <issue>
```

**What it does:**
1. Fetches issue using configured plugin
2. Analyzes description and comments
3. Identifies ambiguities:
   - Unclear acceptance criteria
   - Missing technical constraints
   - Undefined edge cases
   - Implementation approach decisions
4. Asks clarifying questions interactively
5. Updates issue with clarifications

**Output:**
- Issue updated with clarifications
- Labels updated if scope changed

### 2. Planning Mode

Generates exhaustive implementation plan from issue.

```bash
barf plan <issue>           # Unlimited iterations
barf plan <issue> 5         # Max 5 iterations
```

**What it does:**
1. Fetches issue requirements
2. Studies existing codebase with parallel subagents
3. Creates detailed, step-by-step plan:
   - Task breakdown
   - File references (with line numbers)
   - Strict requirements from issue
   - Validation approach
   - Risk assessment
4. **Handles context limits:**
   - Detects when context is full
   - Auto-splits issue into sub-issues
   - Retries with smaller scope

**Output:**
- `plans/<issue>-plan.md` - Detailed implementation plan
- Sub-issues created if split was needed

**Example plan structure:**
```markdown
# Implementation Plan for auth

## Issue Summary
Add user authentication

## Acceptance Criteria
- Users can log in with email/password
- Sessions persist for 30 days
- Logout clears session

## Implementation Tasks

### Task 1: Set up auth config
**Requirements:**
- Support email/password (from issue line 5)

**Implementation:**
1. Create `src/lib/auth/config.ts`
2. Add auth provider interface
3. Implement EmailAuthProvider class

**Files affected:**
- `src/lib/auth/config.ts` (new file)
- `src/lib/auth/index.ts` (export new provider)

**Validation:**
- Unit test: EmailAuthProvider validates credentials
- Integration test: Config loads from env vars

**Risks:**
- Password hashing algorithm choice

### Task 2: Implement authentication middleware
...
```

### 3. Building Mode

Autonomously implements from plan with automatic progress tracking.

```bash
barf build <issue>          # Unlimited iterations
barf build <issue> 20       # Max 20 iterations
```

**What it does:**
1. Reads `plans/<issue>-plan.md`
2. Each iteration:
   - Selects most important incomplete task
   - Searches codebase (never assumes)
   - Implements with parallel subagents
   - Runs tests (backpressure)
   - Commits on success
   - Updates plan
3. **Handles being stuck:**
   - Creates `plans/<issue>-progress.md`
   - Documents attempts and blockers
   - Tries again with fresh context
   - Auto-splits if stuck after 3 attempts
4. **Handles context limits:**
   - Saves progress notes
   - Auto-splits issue into sub-issues
   - Continues with smaller scope

**Example progress notes:**
```markdown
# Progress Notes for auth

## Current State
- [x] Auth config implemented
- [x] EmailAuthProvider tested
- [ ] Middleware partially complete

## Current Task
Implementing session persistence in middleware

## How We Got Here
1. Created config.ts (committed 3f7d9a2)
2. Implemented EmailAuthProvider (committed 8b2e4f1)
3. Started middleware in src/lib/auth/middleware.ts
4. Tests pass for auth flow
5. Stuck on session storage integration

## The Problem
Session storage requires Redis client initialization...

## What Was Tried
- Attempt 1: Direct import - circular dependency
- Attempt 2: Dependency injection - breaks API
- Attempt 3: Global instance - against patterns

## Recommendations
- Option A: Use middleware factory pattern
- Option B: Create session abstraction layer
- Option C: Split into sub-issue for session refactor
```

**Output:**
- Commits for each completed task
- Updated `plans/<issue>-plan.md`
- `plans/<issue>-progress.md` if stuck
- Sub-issues if auto-split triggered

### 4. Audit Mode

Comprehensive quality analysis across entire codebase.

```bash
barf audit
```

**What it does:**
- Code quality analysis
- Issue compliance checking
- Test coverage assessment
- Technical debt identification
- Consistency review

**Output:**
- `AUDIT_REPORT.md` with prioritized findings

## File Structure

```
project/
├── barf                           # The tool (if local install)
├── .barf.yaml                     # Configuration
├── plugins/                       # Issue source plugins
│   ├── local.sh                   # Default: local markdown
│   ├── github.sh                  # GitHub issues
│   └── gitlab.sh                  # GitLab issues
├── issues/                        # Local issues (if using local plugin)
│   ├── auth.md
│   ├── rate-limiting.md
│   └── ...
├── plans/                         # Per-issue plans and progress
│   ├── auth-plan.md
│   ├── auth-progress.md
│   └── ...
├── PROMPT_interview.md            # Interview mode instructions
├── PROMPT_plan.md                 # Planning mode instructions
├── PROMPT_build.md                # Building mode instructions
├── PROMPT_audit.md                # Auditing mode instructions
└── AGENTS.md                      # Operational guide
```

## Context Splitting Workflow

When context fills up, BARF automatically handles it:

```bash
$ barf plan big-feature
Planning Iteration 1...
Context limit reached - auto-splitting issue

Created sub-issues:
  - big-feature-part1.md (Authentication infrastructure)
  - big-feature-part2.md (User profile management)
  - big-feature-part3.md (Permission system)

Planning big-feature-part1...
Plan generated: plans/big-feature-part1-plan.md

# BARF continues with each sub-issue
```

The same applies during building:

```bash
$ barf build big-feature 20
Building Iteration 5...
Context limit reached - saving progress and splitting

Progress saved: plans/big-feature-progress.md
Created sub-issues from remaining tasks

Continuing with big-feature-part1...
```

## Plugin System

### Plugin Interface

Plugins implement these commands (configurable in `.barf.yaml`):

| Command | Description |
|---------|-------------|
| `/fetch <id>` | Get issue content |
| `/update <id> <content>` | Update issue |
| `/comment <id> <text>` | Add comment to issue |
| `/context <id>` | Get full context (issue + comments) |
| `/status <id> [status]` | Get or set issue status |
| `/list` | List all issues |
| `/create <title> <body>` | Create new issue |
| `/link <child> <parent>` | Link sub-issue to parent |

### Creating Custom Plugins

Create a shell script in `plugins/` that handles the commands:

```bash
#!/bin/bash
# plugins/custom.sh

case "$1" in
  /fetch)
    # Return issue content for $2 (issue id)
    ;;
  /update)
    # Update issue $2 with content from stdin
    ;;
  /list)
    # List all issues
    ;;
  *)
    echo "Unknown command: $1"
    exit 1
    ;;
esac
```

Then configure in `.barf.yaml`:
```yaml
source:
  type: custom
  plugin: ./plugins/custom.sh
```

## Advanced Usage

### Work Branches

```bash
# Create branch for issue
git checkout -b feat/auth

# Plan and build on this branch
barf plan auth
barf build auth 20

# Everything committed to feat/auth
gh pr create --fill
```

### Retry Logic

When stuck, BARF automatically retries:

```bash
$ barf build auth 20

Building Iteration 5...
Agent reports being stuck
Progress notes created: plans/auth-progress.md
Retrying with fresh context...

Building Iteration 6...
[reads progress notes, tries different approach]
```

After 3 stuck iterations on same task → auto-split triggered.

### Using GitHub Issues

```yaml
# .barf.yaml
source:
  type: github
  repo: owner/repo
```

```bash
# Now reference by issue number
barf interview 42
barf plan 42
barf build 42 20
```

### Using GitLab Issues

```yaml
# .barf.yaml
source:
  type: gitlab
  repo: group/project
```

```bash
barf interview 42
barf plan 42
barf build 42 20
```

## Ralph Core Principles

BARF implements Ralph's proven patterns:

### Context is Everything
- Fresh context each iteration
- Parallel subagents for memory extension
- Tight task scope (one per loop)
- Main agent as scheduler

### Backpressure Steering
- **Upstream:** Issue requirements, existing code, utilities
- **Downstream:** Tests, builds, type checks, lints

### Let Ralph Ralph
- Self-identifies, self-corrects, self-improves
- Eventual consistency through iteration
- Disposable plans (regenerate anytime)

### Handling Failure
- **Stuck:** Progress notes → retry with fresh context
- **Context limit:** Auto-split → continue with smaller scope
- **Wrong plan:** Regenerate (plan is disposable)

## Safety

BARF uses `--dangerously-skip-permissions` for autonomous operation.

**Protection mechanisms:**
- Run in sandboxes (Docker, Fly, E2B)
- Limit credentials to minimum needed
- Ctrl+C stops loops
- `git reset --hard` reverts changes
- Progress notes preserve work

## Comparison with Traditional Ralph

| Feature | Ralph | BARF |
|---------|-------|------|
| Source of truth | Specs | **Issues (pluggable)** |
| Default source | N/A | **Local markdown** |
| Clarification | Manual conversation | **Auto interview** |
| Context limits | Manual split | **Auto-split & retry** |
| Stuck handling | Manual intervention | **Progress notes + retry** |
| Progress tracking | Plan updates only | **Detailed notes** |
| Sub-task handling | Manual | **Auto split detection** |
| Model selection | Manual | **Auto per task** |
| Setup | Manual files | **`barf init`** |
| Multi-mode | Script swapping | **Single tool** |

## Troubleshooting

### "Issue not found"
- For local: Check issue exists in configured `source.path`
- For GitHub: Ensure `gh` CLI is authenticated
- For GitLab: Ensure `glab` CLI is authenticated

### "Context limit reached"
This triggers auto-split. If it keeps happening:
- Break down issues into smaller pieces upfront
- Check if codebase context is too large
- Review `.barf.yaml` split settings

### Ralph going in circles
Check `plans/<issue>-progress.md`:
- What's being attempted?
- Is there a blocker?
- Does issue need clarification?

May need to:
- Update issue with more detail
- Re-run interview mode
- Regenerate plan
- Manually split into smaller issues

### Tests failing repeatedly
- Check `AGENTS.md` for correct test commands
- Review acceptance criteria in issue
- Check if tests themselves need fixing

## Example Workflow

```bash
# 1. Initialize BARF
$ barf init
Created .barf.yaml
Created issues/
Created plans/
Created AGENTS.md

# 2. Create local issue
$ cat > issues/rate-limiting.md << 'EOF'
# Add Rate Limiting

Implement rate limiting to prevent API abuse.

## Acceptance Criteria
- 100 requests per hour per IP
- 429 status on limit exceeded
- Rate limit headers in response
- Whitelist for internal services

## Technical Notes
- Use Redis for distributed counting
- Whitelist configured via env var
EOF

# 3. Interview (finds missing details)
$ barf interview rate-limiting
> What should the Retry-After header value be?
  [User answers: Seconds until limit resets]
> How should whitelist IPs be formatted?
  [User answers: Comma-separated in RATE_LIMIT_WHITELIST]

Issue updated with clarifications

# 4. Generate plan
$ barf plan rate-limiting
Plan generated: plans/rate-limiting-plan.md

# 5. Review plan
$ cat plans/rate-limiting-plan.md
# [detailed plan with 6 tasks]

# 6. Build
$ barf build rate-limiting 20

Building Iteration 1...
Task: Create rate limit middleware interface
Committed: feat(rate-limiting): add middleware interface

Building Iteration 2...
Task: Implement Redis-backed counter
Committed: feat(rate-limiting): implement redis counter

Building Iteration 3...
[continues until done or max iterations]

# 7. Check progress
$ grep "^\[.\]" plans/rate-limiting-plan.md
[x] Create rate limit middleware interface
[x] Implement Redis-backed counter
[x] Add rate limit headers
[ ] Implement whitelist support
[ ] Add integration tests
...

# 8. Continue if needed
$ barf build rate-limiting 20

# 9. Audit when complete
$ barf audit
```

## Tips

1. **Write good issues** - Clear acceptance criteria = better plans
2. **Small issues** - Easier to plan, less context splitting
3. **Let it retry** - Progress notes + fresh context often resolves blocks
4. **Trust the split** - Auto-split is designed to help, not hinder
5. **Review progress notes** - They contain valuable debugging info
6. **Update AGENTS.md** - Capture operational learnings
7. **Regenerate plans** - Plans are disposable, regenerate if wrong

## Credits

Based on [Geoff Huntley's Ralph methodology](https://ghuntley.com/ralph/) and the [Ralph playbook](https://github.com/ClaytonFarr/ralph-playbook) by Clayton Farr.

Plugin system, auto-split, and local-first approach by BARF.

## License

MIT
