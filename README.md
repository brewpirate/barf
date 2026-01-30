# BARF - Build And Run Framework

![woof](assets/barf.png)



**Issue-Driven Autonomous Development based on the Ralph Playbook**

BARF is a bash tool that implements the [Ralph playbook](https://github.com/ClaytonFarr/ralph-playbook) methodology with a focus on **issue-driven development**. Point it at a GitHub or GitLab issue, and it autonomously clarifies, plans, and implements.

## Core Innovation: Issue-Driven

Unlike traditional Ralph (spec-driven), BARF works directly with your issue tracker:

- **Interview Mode** - Scans issues for ambiguities, asks clarifying questions
- **Planning Mode** - Generates detailed implementation plans with context splitting
- **Building Mode** - Implements autonomously, saves progress when stuck
- **Auditing Mode** - Verifies quality and compliance

## Key Features

### 🔍 **Automatic Context Splitting**
When an issue is too large for context:
- Planning mode detects limits and recommends sub-issues
- Building mode saves progress notes before splitting
- Resume seamlessly after splitting

### 📝 **Progress Notes**
When stuck, BARF creates detailed notes:
- What was accomplished
- How we got here (step-by-step)
- What's blocking progress
- What was tried
- Recommendations for next steps

### 🎯 **Strict Requirements**
Plans include:
- Line-by-line mapping to issue requirements
- File reference
- Specific validation steps
- Edge cases from acceptance criteria

## Quick Start

```bash
# 1. Create an issue in GitHub/GitLab with requirements
# Example: Issue #42 - "Add user authentication"

# 2. Clarify ambiguities
barf interview 42

# 3. Generate detailed plan
barf plan 42

# 4. Build autonomously (max 20 iterations)
barf build 42 20

# 5. Audit quality
barf audit
```

## Installation

```bash
# Download
curl -o barf https://raw.githubusercontent.com/
chmod +x barf

# Move to PATH
sudo mv barf /usr/local/bin/

# Requires: Claude CLI and gh CLI
# Install: https://github.com/anthropics/anthropic-claude-cli
# Install gh: https://cli.github.com/
```

## Modes

### 1. Interview Mode

Scans issue for missing details and asks clarifying questions.

```bash
barf interview 42
```

**What it does:**
1. Fetches issue #42 using `gh issue view`
2. Analyzes description and comments
3. Identifies ambiguities:
   - Unclear acceptance criteria
   - Missing technical constraints
   - Undefined edge cases
   - Implementation approach decisions
4. Uses `AskUserQuestion` to clarify interactively
5. Updates issue with clarifications as comments

**Output:**
- Issue comments with clarifications
- Updated labels if scope changed

### 2. Planning Mode

Generates exhaustive implementation plan from issue.

```bash
barf plan 42          # Unlimited iterations
barf plan 42 5        # Max 5 iterations
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
   - Saves partial plan
   - Documents what's missing
   - Recommends sub-issue splits

**Output:**
- `plans/issue-42-plan.md` - Detailed implementation plan

**Example plan structure:**
```markdown
# Implementation Plan for Issue #42

## Issue Summary
Add OAuth authentication for users

## Acceptance Criteria
- Users can log in with Google OAuth
- Sessions persist for 30 days
- Logout clears session
- Unauthorized requests redirect to login

## Implementation Tasks

### Task 1: Set up OAuth provider config
**Requirements:**
- Support Google OAuth (from issue line 12)

**Implementation:**
1. Create `src/lib/auth/oauth-config.ts`
2. Add OAuth provider interface
3. Implement GoogleOAuthProvider class

**Files affected:**
- `src/lib/auth/oauth-config.ts` (new file)
- `src/lib/auth/index.ts` (export new provider)

**Validation:**
- Unit test: GoogleOAuthProvider returns valid config
- Integration test: Config loads from env vars

**Risks:**
- Environment variables might not be set in all environments

### Task 2: Implement authentication middleware
...
```

### 3. Building Mode

Autonomously implements from plan with automatic progress tracking.

```bash
barf build 42         # Unlimited iterations
barf build 42 20      # Max 20 iterations
```

**What it does:**
1. Reads `plans/issue-42-plan.md`
2. Each iteration:
   - Selects most important incomplete task
   - Searches codebase (never assumes)
   - Implements with parallel subagents
   - Runs tests (backpressure)
   - Commits on success
   - Updates plan
3. **Handles being stuck:**
   - Creates `plans/issue-42-progress.md`
   - Documents attempts and blockers
   - Tries again with fresh context
   - Recommends split if needed after 3 attempts
4. **Handles context limits:**
   - Saves progress notes
   - Documents split recommendations
   - Exits for human intervention

**Example progress notes:**
```markdown
# Progress Notes for Issue #42

## Current State
✓ OAuth config implemented
✓ GoogleOAuthProvider tested
⚠ Middleware partially complete

## Current Task
Implementing session persistence in middleware

## How We Got Here
1. Created oauth-config.ts (committed 3f7d9a2)
2. Implemented GoogleOAuthProvider (committed 8b2e4f1)
3. Started middleware in src/lib/auth/middleware.ts
4. Tests pass for auth flow
5. Stuck on session storage integration

## The Problem
Session storage requires access to Redis client, but:
- RedisClient not initialized in middleware context
- Circular dependency if importing from src/lib/redis
- Tests mock Redis but real impl fails

## What Was Tried
- Attempt 1: Direct import from src/lib/redis
  Result: Circular dependency error
  
- Attempt 2: Dependency injection via middleware params
  Result: Tests pass, but breaks existing middleware API
  
- Attempt 3: Global Redis instance
  Result: Goes against codebase patterns

## Needed to Proceed
Decision on Redis client initialization:
1. Accept middleware API change? OR
2. Refactor Redis singleton pattern? OR
3. Different session storage approach?

## Recommendations
- Option A: Use middleware factory pattern (accepts deps)
- Option B: Create src/lib/session abstraction (hides Redis)
- Option C: Split into sub-issue for session refactor
```

**Output:**
- Commits for each completed task
- Updated `plans/issue-42-plan.md`
- `plans/issue-42-progress.md` if stuck

### 4. Audit Mode

Comprehensive quality analysis across entire codebase.

```bash
barf audit
```

**What it does:**
- Code quality analysis
- Spec/issue compliance checking
- Test coverage assessment
- Technical debt identification
- Consistency review

**Output:**
- `AUDIT_REPORT.md` with prioritized findings

## File Structure

```
project/
├── barf                           # The tool
├── plans/                         # Per-issue plans and progress
│   ├── issue-42-plan.md
│   ├── issue-42-progress.md
│   ├── issue-43-plan.md
│   └── ...
├── PROMPT_interview.md            # Interview mode instructions
├── PROMPT_plan.md                 # Planning mode instructions
├── PROMPT_build.md                # Building mode instructions
├── PROMPT_audit.md                # Auditing mode instructions
├── AGENTS.md                      # Operational guide
└── src/                           # Application source code
```

## Context Splitting Workflow

When an issue is too large:

```bash
# Try to plan issue #50
$ barf plan 50
Planning Iteration 1...
⚠ Context limit reached
Issue #50 needs to be split
Suggested sub-issues:
  1. Authentication infrastructure (OAuth, sessions)
  2. User profile management
  3. Permission system
  4. Audit logging

# Create sub-issues
$ gh issue create --title "Auth infrastructure" --body "..." --label "parent:#50"
$ gh issue create --title "User profiles" --body "..." --label "parent:#50"
# ... etc

# Plan each sub-issue
$ barf plan 51  # Auth infrastructure
$ barf plan 52  # User profiles

# Build each
$ barf build 51 20
$ barf build 52 20
```

The same applies during building - if stuck or context limited, BARF saves progress and recommends splitting.

## Advanced Usage

### Work Branches

```bash
# Create branch for issue
git checkout -b feat/issue-42

# Plan and build on this branch
barf plan 42
barf build 42 20

# Everything committed to feat/issue-42
gh pr create --fill
```

### Retry Logic

When stuck, BARF automatically retries:

```bash
$ barf build 42 20

Building Iteration 5...
⚠ Agent reports being stuck
✓ Progress notes created: plans/issue-42-progress.md
Retrying with fresh context...

Building Iteration 6...
[reads progress notes, tries different approach]
```

After 3 stuck iterations on same task, human intervention needed.

### Continuous Building

```bash
# Run until done or you stop it
$ barf build 42

# Monitor in another terminal
$ watch -n 2 'cat plans/issue-42-plan.md | grep "\[.\]"'
```

### Custom Models

```bash
# Use Sonnet for speed (if tasks are clear)
barf -m sonnet build 42 50
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
- **Context limit:** Save state → recommend split → resume after
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
| Source of truth | Specs | **Issues** |
| Clarification | Manual conversation | **Auto interview** |
| Context limits | Manual split | **Auto detect & recommend** |
| Stuck handling | Manual intervention | **Progress notes + retry** |
| Progress tracking | Plan updates only | **Detailed notes** |
| Sub-task handling | Manual | **Auto split detection** |
| Setup | Manual files | **Auto-init** |
| Multi-mode | Script swapping | **Single tool** |

## Troubleshooting

### "Issue #X not found"
Ensure `gh` CLI is authenticated and has access to the repo.

### "Context limit reached"
This is expected for large issues. Follow the split recommendations.

### Ralph going in circles
Check `plans/issue-N-progress.md`:
- What's being attempted?
- Is there a blocker?
- Does issue need clarification?

May need to:
- Update issue with more detail
- Re-run interview mode
- Regenerate plan
- Split into smaller issues

### Tests failing repeatedly
- Check `AGENTS.md` for correct test commands
- Review acceptance criteria in issue
- Check if tests themselves need fixing

## Example Workflow

```bash
# 1. Create issue
$ gh issue create --title "Add rate limiting" \
  --body "Implement rate limiting to prevent API abuse.
  
Acceptance Criteria:
- 100 requests per hour per IP
- 429 status on limit exceeded
- Rate limit headers in response
- Whitelist for internal services"

# Issue #55 created

# 2. Interview (finds missing details)
$ barf interview 55
> What should happen when rate limit is exceeded? 
  [User answers: Return 429 with Retry-After header]
> How should whitelist be configured?
  [User answers: Environment variable CSV list]

✓ Issue updated with clarifications

# 3. Generate plan
$ barf plan 55
✓ Plan generated: plans/issue-55-plan.md

# 4. Review plan
$ cat plans/issue-55-plan.md
# [detailed plan with 8 tasks]

# 5. Build
$ barf build 55 20

Building Iteration 1...
✓ Task: Create rate limit middleware interface
  Committed: feat(#55): add rate limit middleware interface

Building Iteration 2...
✓ Task: Implement in-memory rate limiter
  Committed: feat(#55): implement in-memory rate limiter

Building Iteration 3...
[continues until done or max iterations]

# 6. Check progress
$ cat plans/issue-55-plan.md | grep "^\[.\]"
[x] Create rate limit middleware interface
[x] Implement in-memory rate limiter
[x] Add rate limit headers
[ ] Implement Redis-backed storage
[ ] Add whitelist support
...

# 7. Continue if needed
$ barf build 55 20

# 8. Audit when complete
$ barf audit
```

## Tips

1. **Write good issues** - Clear acceptance criteria = better plans
2. **Small issues** - Easier to plan, less context splitting
3. **Let it retry** - Progress notes + fresh context often resolves blocks
4. **Trust the split** - When BARF recommends splitting, do it
5. **Review progress notes** - They contain valuable debugging info
6. **Update AGENTS.md** - Capture operational learnings
7. **Regenerate plans** - Plans are disposable, regenerate if wrong

## Credits

Based on [Geoff Huntley's Ralph methodology](https://ghuntley.com/ralph/) and the [Ralph playbook](https://github.com/ClaytonFarr/ralph-playbook) by Clayton Farr.

Issue-driven enhancements and automatic context splitting by BARF.

## License

MIT
