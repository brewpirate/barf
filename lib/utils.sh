#!/bin/bash
# BARF Library: Utility Functions
# Basic helper functions used throughout BARF

# Exit with error message
die() {
    log_error "$1"
    exit 1
}

# Check if a command exists
require_cmd() {
    command -v "$1" &> /dev/null || die "Required command not found: $1"
}
