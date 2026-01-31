#!/bin/bash
# BARF Library: Logging and Output
# Provides colored output functions and logging utilities

# Colors for output (disabled with --quiet or when not a tty)
if [[ -t 1 ]] && [[ -z "${NO_COLOR:-}" ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    MAGENTA='\033[0;35m'
    CYAN='\033[0;36m'
    BOLD='\033[1m'
    DIM='\033[2m'
    NC='\033[0m' # No Color
else
    RED='' GREEN='' YELLOW='' BLUE='' MAGENTA='' CYAN='' BOLD='' DIM='' NC=''
fi

log_info() {
    [[ $QUIET -eq 1 ]] && return
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    [[ $QUIET -eq 1 ]] && return
    echo -e "${GREEN}[OK]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_verbose() {
    [[ $VERBOSE -eq 0 ]] && return
    echo -e "${DIM}  $*${NC}"
}

log_debug() {
    [[ $VERBOSE -lt 2 ]] && return
    echo -e "${DIM}[DEBUG] $*${NC}"
}

log_dry_run() {
    echo -e "${MAGENTA}[DRY-RUN]${NC} $*"
}

# Print section header
print_header() {
    [[ $QUIET -eq 1 ]] && return
    echo ""
    echo -e "${BOLD}$*${NC}"
    echo -e "${DIM}$(printf '%.0s─' {1..50})${NC}"
}
