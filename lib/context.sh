#!/bin/bash
# BARF Library: Context Tracking
# Token estimation and context limit handling

# Estimate token count from character count
estimate_tokens() {
    local text="$1"
    local char_count=${#text}
    echo $((char_count / CHARS_PER_TOKEN))
}

# Get token limit for a model
get_token_limit() {
    local model="$1"
    case "$model" in
        haiku)
            echo $TOKEN_LIMIT_HAIKU
            ;;
        sonnet)
            echo $TOKEN_LIMIT_SONNET
            ;;
        opus)
            echo $TOKEN_LIMIT_OPUS
            ;;
        *)
            echo $TOKEN_LIMIT_SONNET
            ;;
    esac
}

# Check if we're approaching context limit
check_context_limit() {
    local content="$1"
    local model="$2"
    local threshold="${3:-0.8}"  # 80% by default

    local estimated_tokens
    estimated_tokens=$(estimate_tokens "$content")

    local limit
    limit=$(get_token_limit "$model")

    local threshold_tokens
    threshold_tokens=$(echo "$limit * $threshold" | bc 2>/dev/null || echo $((limit * 8 / 10)))

    if [[ $estimated_tokens -gt $threshold_tokens ]]; then
        return 0  # True: approaching limit
    else
        return 1  # False: still have room
    fi
}

# Parse Claude CLI output for context errors
detect_context_error() {
    local output="$1"

    # Check for various context limit indicators
    if echo "$output" | grep -qiE "context.*(limit|window|length|exceeded|full)"; then
        return 0
    fi
    if echo "$output" | grep -qiE "token.*(limit|exceeded|maximum)"; then
        return 0
    fi
    if echo "$output" | grep -qiE "maximum.*(context|length|tokens)"; then
        return 0
    fi
    if echo "$output" | grep -qiE "too (long|large|many tokens)"; then
        return 0
    fi
    if echo "$output" | grep -qiE "input.*truncated"; then
        return 0
    fi

    return 1  # No context error detected
}
