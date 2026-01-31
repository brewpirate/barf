#!/bin/bash
# BARF Library: Plan Diffing
# Generate and analyze differences between plan versions

# Generate a diff between old and new plan
generate_plan_diff() {
    local issue="$1"
    local old_plan="$2"
    local new_plan="$3"

    echo -e "\n${BOLD}Plan Diff for Issue: ${issue}${NC}"
    echo -e "${DIM}$(printf '%.0s=' {1..60})${NC}\n"

    # Use diff with color
    diff -u "$old_plan" "$new_plan" 2>/dev/null | while IFS= read -r line; do
        case "$line" in
            ---*) echo -e "${RED}$line${NC}" ;;
            +++*) echo -e "${GREEN}$line${NC}" ;;
            @@*) echo -e "${CYAN}$line${NC}" ;;
            -*) echo -e "${RED}$line${NC}" ;;
            +*) echo -e "${GREEN}$line${NC}" ;;
            *) echo "$line" ;;
        esac
    done || true

    echo -e "\n${DIM}$(printf '%.0s=' {1..60})${NC}"

    local added removed
    added=$(diff "$old_plan" "$new_plan" 2>/dev/null | grep -c "^>" || echo "0")
    removed=$(diff "$old_plan" "$new_plan" 2>/dev/null | grep -c "^<" || echo "0")

    echo -e "\n${BOLD}Summary:${NC}"
    echo -e "  ${GREEN}+ $added lines added${NC}"
    echo -e "  ${RED}- $removed lines removed${NC}"
    echo
}

# Analyze plan changes semantically
analyze_plan_changes() {
    local old_plan="$1"
    local new_plan="$2"

    python3 << EOF
import re

def extract_tasks(content):
    tasks = []
    current_task = None
    for line in content.split('\n'):
        if re.match(r'^###\s+Task\s*\d*:?\s*', line):
            if current_task:
                tasks.append(current_task)
            current_task = {'title': line.strip('#').strip(), 'content': ''}
        elif current_task:
            current_task['content'] += line + '\n'
    if current_task:
        tasks.append(current_task)
    return tasks

def extract_checklist(content):
    items = []
    for line in content.split('\n'):
        match = re.match(r'^\s*[-*]\s*\[([ xX])\]\s*(.+)', line)
        if match:
            checked = match.group(1).lower() == 'x'
            items.append({'text': match.group(2), 'checked': checked})
    return items

try:
    with open('$old_plan', 'r') as f:
        old_content = f.read()
    with open('$new_plan', 'r') as f:
        new_content = f.read()
except FileNotFoundError as e:
    print(f"Error: {e}")
    exit(1)

old_tasks = extract_tasks(old_content)
new_tasks = extract_tasks(new_content)
old_checklist = extract_checklist(old_content)
new_checklist = extract_checklist(new_content)

print("\n\033[1mSemantic Analysis:\033[0m")
print("-" * 40)

old_titles = {t['title'] for t in old_tasks}
new_titles = {t['title'] for t in new_tasks}
added_tasks = new_titles - old_titles
removed_tasks = old_titles - new_titles

if added_tasks:
    print(f"\n\033[32mNew Tasks Added ({len(added_tasks)}):\033[0m")
    for t in added_tasks:
        print(f"  + {t}")

if removed_tasks:
    print(f"\n\033[31mTasks Removed ({len(removed_tasks)}):\033[0m")
    for t in removed_tasks:
        print(f"  - {t}")

old_items = {i['text'] for i in old_checklist}
new_items = {i['text'] for i in new_checklist}
added_items = new_items - old_items
removed_items = old_items - new_items

if added_items or removed_items:
    print(f"\n\033[33mChecklist Changes:\033[0m")
    for item in added_items:
        print(f"  \033[32m+ {item}\033[0m")
    for item in removed_items:
        print(f"  \033[31m- {item}\033[0m")

old_checked = sum(1 for i in old_checklist if i['checked'])
new_checked = sum(1 for i in new_checklist if i['checked'])
if old_checked != new_checked:
    print(f"\n\033[34mProgress: {old_checked} -> {new_checked} tasks completed\033[0m")

if not (added_tasks or removed_tasks or added_items or removed_items):
    print("\n  No significant structural changes detected.")
print()
EOF
}
