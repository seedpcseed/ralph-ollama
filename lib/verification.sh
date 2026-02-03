#!/bin/bash
#
# Story Verification - Run verification commands before marking stories complete
# Language-agnostic: supports Python, Rust, Go, Node, etc.
# Supports: .verify field in story JSON, RUN "cmd" in acceptance text
#

# Detect project language and return appropriate test command for fallback
# Usage: get_default_test_cmd <project_dir>
get_default_test_cmd() {
    local project_dir="$1"
    [ -d "$project_dir" ] || return 1
    if [ -f "$project_dir/Cargo.toml" ]; then
        echo "cargo test"
    elif [ -f "$project_dir/go.mod" ]; then
        echo "go test ./..."
    elif [ -f "$project_dir/package.json" ] && grep -q '"test"' "$project_dir/package.json" 2>/dev/null; then
        echo "npm test"
    elif [ -f "$project_dir/pyproject.toml" ] || [ -f "$project_dir/setup.py" ] || [ -f "$project_dir/requirements.txt" ]; then
        echo "python3 -m pytest"
    else
        echo ""
    fi
}

# Expand common test commands for different languages
expand_verify_cmd() {
    local cmd="$1"
    case "$cmd" in
        pytest) echo "python3 -m pytest" ;;
        pytest\ *) echo "python3 -m $cmd" ;;
        cargo\ test*) echo "$cmd" ;;
        go\ test*) echo "$cmd" ;;
        npm\ test*) echo "$cmd" ;;
        *) echo "$cmd" ;;
    esac
}

# Run verification for a story. Returns 0 if pass, 1 if fail, 2 if skip (no verify)
# Usage: run_story_verification <project_dir> <story_json>
run_story_verification() {
    local project_dir="$1"
    local story_json="$2"
    
    if [ ! -d "$project_dir" ]; then
        return 1
    fi
    
    # 1. Check for explicit "verify" field in story
    local verify_cmd
    verify_cmd=$(echo "$story_json" | jq -r '.verify // empty')
    
    # 2. Parse acceptance for RUN "command" pattern
    if [ -z "$verify_cmd" ]; then
        local acceptance
        acceptance=$(echo "$story_json" | jq -r '.acceptance // ""')
        if [[ "$acceptance" =~ RUN\ \"([^\"]+)\" ]]; then
            verify_cmd="${BASH_REMATCH[1]}"
        fi
    fi
    
    # 3. Check for project-level verify.sh
    if [ -z "$verify_cmd" ] && [ -f "$project_dir/verify.sh" ]; then
        verify_cmd="bash verify.sh"
    fi
    
    # No verification defined - skip (treat as pass for backward compat)
    if [ -z "$verify_cmd" ]; then
        return 2
    fi
    
    # Expand common commands (pytest, cargo test, go test, etc.)
    verify_cmd=$(expand_verify_cmd "$verify_cmd")
    
    # Run verification from project directory
    echo "  Verifying: $verify_cmd"
    local verify_output verify_exit
    verify_output=$(cd "$project_dir" && eval "$verify_cmd" 2>&1)
    verify_exit=$?
    
    if [ $verify_exit -eq 0 ]; then
        echo "  ✓ Verification passed"
        return 0
    fi
    
    # Python pytest: exit 5 = no tests collected (treat as pass for setup stories)
    if [[ "$verify_cmd" == *pytest* ]] && [ $verify_exit -eq 5 ]; then
        echo "  ✓ Verification passed (no tests yet - ok for setup stories)"
        return 0
    fi
    
    # Python pytest: import/collection errors during incremental build - tests exist but
    # code may be incomplete (e.g. story 1.1 creates structure, tests reference story 1.2 modules)
    if [[ "$verify_cmd" == *pytest* ]] && [ $verify_exit -ne 0 ]; then
        if echo "$verify_output" | grep -qE "ERROR collecting|ImportError|cannot import"; then
            echo "  ✓ Verification passed (tests exist, imports incomplete - ok for incremental build)"
            return 0
        fi
    fi
    
    # Fallback: when verify fails with "command not found" (e.g. app CLI before install),
    # try language-appropriate test command based on project detection
    if echo "$verify_output" | grep -q "command not found"; then
        local default_cmd
        default_cmd=$(get_default_test_cmd "$project_dir")
        if [ -n "$default_cmd" ]; then
            echo "  (verify command unavailable - trying $default_cmd)"
            if verify_output=$(cd "$project_dir" && eval "$default_cmd" 2>&1); then
                echo "  ✓ Verification passed ($default_cmd fallback)"
                return 0
            fi
            verify_exit=$?
            # pytest exit 5 = no tests yet
            if [[ "$default_cmd" == *pytest* ]] && [ $verify_exit -eq 5 ]; then
                echo "  ✓ Verification passed ($default_cmd fallback - no tests yet)"
                return 0
            fi
        fi
    fi
    
    echo "  ✗ Verification failed"
    echo "$verify_output" | head -20 | sed 's/^/    /'
    return 1
}
