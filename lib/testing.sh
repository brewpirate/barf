#!/bin/bash
# BARF Library: Test Command Detection
# Auto-detect test commands for various project types

# Detect the test command for the current project
detect_test_command() {
    # Check AGENTS.md first (user preference)
    if [[ -f "AGENTS.md" ]]; then
        local agents_test
        agents_test=$(grep -A1 "# Run tests" "AGENTS.md" 2>/dev/null | tail -1 | sed 's/^#[[:space:]]*//' | tr -d '\n')
        if [[ -n "$agents_test" && "$agents_test" != "#"* ]]; then
            echo "$agents_test"
            return
        fi
    fi

    # Check package.json (Node.js)
    if [[ -f "package.json" ]]; then
        if grep -q '"test"' "package.json"; then
            echo "npm test"
            return
        fi
    fi

    # Check for pytest (Python)
    if [[ -f "pytest.ini" || -f "pyproject.toml" || -f "setup.py" ]]; then
        if command -v pytest &>/dev/null; then
            echo "pytest"
            return
        elif command -v python &>/dev/null; then
            echo "python -m pytest"
            return
        fi
    fi

    # Check Cargo.toml (Rust)
    if [[ -f "Cargo.toml" ]]; then
        echo "cargo test"
        return
    fi

    # Check go.mod (Go)
    if [[ -f "go.mod" ]]; then
        echo "go test ./..."
        return
    fi

    # Check Makefile
    if [[ -f "Makefile" ]]; then
        if grep -q "^test:" "Makefile"; then
            echo "make test"
            return
        fi
    fi

    # Check for mix.exs (Elixir)
    if [[ -f "mix.exs" ]]; then
        echo "mix test"
        return
    fi

    # Check for Gemfile (Ruby)
    if [[ -f "Gemfile" ]]; then
        if grep -q "rspec" "Gemfile"; then
            echo "bundle exec rspec"
            return
        elif [[ -d "test" ]]; then
            echo "bundle exec rake test"
            return
        fi
    fi

    # Check for build.gradle (Java/Kotlin)
    if [[ -f "build.gradle" || -f "build.gradle.kts" ]]; then
        echo "./gradlew test"
        return
    fi

    # Check for pom.xml (Maven)
    if [[ -f "pom.xml" ]]; then
        echo "mvn test"
        return
    fi

    # Default: no test command found
    echo ""
}
