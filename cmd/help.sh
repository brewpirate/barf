#!/bin/bash
# BARF Command: help
# Help and version display

show_help() {
    cat << EOF
${BOLD}BARF${NC} - Build And Run Framework v${VERSION}
Issue-Driven Autonomous Development based on the Ralph Playbook

${BOLD}USAGE:${NC}
    barf [OPTIONS] <COMMAND> [ARGS...]

${BOLD}COMMANDS:${NC}
  init                    Initialize BARF in current directory
  interview <issue>       Analyze issue and ask clarifying questions
  plan <issue> [max]      Generate implementation plan (max iterations)
    --diff, -d            Show diff from previous plan when regenerating
  build <issue> [max]     Build from plan (max iterations)
  resume <issue> [max]    Resume work on an issue (auto-detects state)
  audit                   Perform codebase quality audit
  stats [issue]           Show cost tracking statistics
  list [filter]           List all issues (filters: --open, --planned, --in-progress)
  status [issue] [state]  Show status summary or get/set issue status
  new <type> <title>      Create new issue from template
  dashboard               Show progress dashboard

${BOLD}OPTIONS:${NC}
  -m, --model <MODEL>     Use specific Claude model (opus, sonnet, haiku)
  -n, --dry-run           Show what would happen without executing
  -v, --verbose           Increase output verbosity (use -vv for debug)
  -q, --quiet             Suppress non-essential output
  -p, --parallel          Process sub-issues in parallel (for plan)
  -h, --help              Show this help message
  --version               Show version information

${BOLD}EXAMPLES:${NC}
  barf init
  barf interview auth
  barf plan auth 5
  barf plan auth --diff            # Regenerate plan and show diff
  barf plan auth --dry-run         # Show what plan would do
  barf build auth 20
  barf build auth --dry-run        # Show next task without implementing
  barf -m sonnet build auth        # Use Sonnet model for speed
  barf resume auth                 # Continue where you left off
  barf stats                       # Show all cost tracking stats
  barf stats auth                  # Show cost stats for issue
  barf list                        # Show all issues
  barf list --open                 # Show open issues
  barf status                      # Show summary
  barf status auth                 # Show issue status
  barf status auth done            # Mark issue done
  barf new feature "Add auth"      # Create feature issue from template
  barf new bug "Fix login"         # Create bug issue from template
  barf dashboard                   # Show progress dashboard
  barf audit

${BOLD}VERBOSITY LEVELS:${NC}
  (default)   Standard output - progress and results
  -q          Quiet - only errors and final results
  -v          Verbose - include detailed progress info
  -vv         Debug - include internal debugging info

${BOLD}DRY-RUN MODE:${NC}
  Shows what would happen without making changes:
  - plan --dry-run:  Show Claude prompt and planned approach
  - build --dry-run: Show next task without implementing

${BOLD}CONFIGURATION:${NC}
  Create .barf.yaml in your project root to customize behavior.
  See .barf.yaml.example for all options.

${BOLD}GIT BRANCH AUTOMATION:${NC}
  Add to .barf.yaml to auto-create branches per issue:

    git:
      auto_branch: true
      branch_format: "feat/{issue}"
      base_branch: main

  Placeholders: {issue}, {issue_number}

${BOLD}COST TRACKING:${NC}
  BARF tracks Claude API usage per issue. View with:
    barf stats          # All issues
    barf stats auth     # Specific issue

${BOLD}DOCUMENTATION:${NC}
  https://github.com/brewpirate/barf
EOF
}

show_version() {
    echo "BARF v$VERSION"
}
