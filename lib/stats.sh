#!/bin/bash
# BARF Library: Cost Tracking
# Statistics and cost tracking for Claude API usage

# Initialize barf data directory
init_barf_data() {
    mkdir -p "$BARF_DATA_DIR"
    if [[ ! -f "$STATS_FILE" ]]; then
        echo '{"issues": {}, "total": {"input_tokens": 0, "output_tokens": 0, "api_calls": 0}}' > "$STATS_FILE"
    fi
}

# Update stats for an issue
update_stats() {
    local issue="$1"
    local input_tokens="$2"
    local output_tokens="$3"
    local model="${4:-sonnet}"

    init_barf_data

    python3 << EOF
import json

try:
    with open('$STATS_FILE', 'r') as f:
        stats = json.load(f)
except:
    stats = {"issues": {}, "total": {"input_tokens": 0, "output_tokens": 0, "api_calls": 0}}

issue = "$issue"
input_tokens = $input_tokens
output_tokens = $output_tokens
model = "$model"

if issue not in stats["issues"]:
    stats["issues"][issue] = {
        "input_tokens": 0,
        "output_tokens": 0,
        "api_calls": 0,
        "model_usage": {}
    }

stats["issues"][issue]["input_tokens"] += input_tokens
stats["issues"][issue]["output_tokens"] += output_tokens
stats["issues"][issue]["api_calls"] += 1

if model not in stats["issues"][issue]["model_usage"]:
    stats["issues"][issue]["model_usage"][model] = {"input": 0, "output": 0, "calls": 0}
stats["issues"][issue]["model_usage"][model]["input"] += input_tokens
stats["issues"][issue]["model_usage"][model]["output"] += output_tokens
stats["issues"][issue]["model_usage"][model]["calls"] += 1

stats["total"]["input_tokens"] += input_tokens
stats["total"]["output_tokens"] += output_tokens
stats["total"]["api_calls"] += 1

with open('$STATS_FILE', 'w') as f:
    json.dump(stats, f, indent=2)
EOF
}

# Show stats for an issue or all issues
show_stats() {
    local issue="${1:-}"

    init_barf_data

    if [[ ! -f "$STATS_FILE" ]]; then
        log_warn "No stats recorded yet."
        return
    fi

    python3 << EOF
import json
import sys

PRICING_INPUT = {"opus": 15.00, "sonnet": 3.00, "haiku": 0.25}
PRICING_OUTPUT = {"opus": 75.00, "sonnet": 15.00, "haiku": 1.25}

def calc_cost(input_tokens, output_tokens, model="sonnet"):
    input_price = PRICING_INPUT.get(model, 3.00)
    output_price = PRICING_OUTPUT.get(model, 15.00)
    return (input_tokens / 1000000) * input_price + (output_tokens / 1000000) * output_price

def format_tokens(n):
    if n >= 1000000:
        return f"{n/1000000:.2f}M"
    elif n >= 1000:
        return f"{n/1000:.1f}K"
    return str(n)

try:
    with open('$STATS_FILE', 'r') as f:
        stats = json.load(f)
except:
    print("No stats recorded yet.")
    sys.exit(0)

issue = "$issue"

if issue:
    if issue not in stats.get("issues", {}):
        print(f"No stats found for issue '{issue}'")
        sys.exit(1)

    data = stats["issues"][issue]
    print(f"\n{'='*60}")
    print(f"  Cost Tracking for Issue: {issue}")
    print(f"{'='*60}\n")

    total_cost = 0
    for model, usage in data.get("model_usage", {}).items():
        cost = calc_cost(usage["input"], usage["output"], model)
        total_cost += cost

    print(f"  {'Metric':<25} {'Value':>15}")
    print(f"  {'-'*25} {'-'*15}")
    print(f"  {'Input Tokens':<25} {format_tokens(data['input_tokens']):>15}")
    print(f"  {'Output Tokens':<25} {format_tokens(data['output_tokens']):>15}")
    print(f"  {'API Calls':<25} {data['api_calls']:>15}")
    print(f"  {'Estimated Cost':<25} {'$' + f'{total_cost:.4f}':>15}")

    if data.get("model_usage"):
        print(f"\n  Model Breakdown:")
        print(f"  {'-'*50}")
        for model, usage in data["model_usage"].items():
            model_cost = calc_cost(usage["input"], usage["output"], model)
            print(f"    {model:<20} {usage['calls']:>5} calls  \${model_cost:.4f}")
    print()
else:
    print(f"\n{'='*60}")
    print(f"  BARF Cost Tracking Summary")
    print(f"{'='*60}\n")

    total = stats.get("total", {})
    print(f"  Overall Statistics:")
    print(f"  {'-'*50}")
    print(f"  {'Total Input Tokens':<25} {format_tokens(total.get('input_tokens', 0)):>15}")
    print(f"  {'Total Output Tokens':<25} {format_tokens(total.get('output_tokens', 0)):>15}")
    print(f"  {'Total API Calls':<25} {total.get('api_calls', 0):>15}")

    issues = stats.get("issues", {})
    if issues:
        print(f"\n  Per-Issue Breakdown:")
        print(f"  {'-'*50}")
        print(f"  {'Issue':<15} {'Input':>10} {'Output':>10} {'Calls':>8} {'Cost':>10}")
        print(f"  {'-'*15} {'-'*10} {'-'*10} {'-'*8} {'-'*10}")

        total_cost = 0
        for issue_id, data in sorted(issues.items()):
            issue_cost = 0
            for model, usage in data.get("model_usage", {}).items():
                issue_cost += calc_cost(usage["input"], usage["output"], model)
            total_cost += issue_cost

            print(f"  {issue_id:<15} {format_tokens(data['input_tokens']):>10} {format_tokens(data['output_tokens']):>10} {data['api_calls']:>8} {'\$' + f'{issue_cost:.4f}':>10}")

        print(f"  {'-'*15} {'-'*10} {'-'*10} {'-'*8} {'-'*10}")
        print(f"  {'TOTAL':<15} {'':<10} {'':<10} {'':<8} {'\$' + f'{total_cost:.4f}':>10}")
    print()
EOF
}
