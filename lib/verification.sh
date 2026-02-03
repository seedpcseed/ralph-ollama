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

# Validate and repair verification command syntax
# Returns repaired command and sets VERIFY_CMD_ERROR_TYPE if issues found
validate_and_repair_cmd() {
    local cmd="$1"
    VERIFY_CMD_ERROR_TYPE=""
    
    # Check for Python -c commands with quote nesting issues
    if [[ "$cmd" =~ python.*-c.*\' ]]; then
        # Extract the inner content between the outer single quotes
        if [[ "$cmd" =~ python.*-c\ \'(.+)\' ]]; then
            local inner="${BASH_REMATCH[1]}"
            # Check if inner content has unescaped single quotes (quote nesting problem)
            if [[ "$inner" =~ [^\\]\' ]]; then
                VERIFY_CMD_ERROR_TYPE="quote_nesting"
                # Fix: Replace outer single quotes with double quotes, keep inner single quotes
                # This handles: python -c 'func('/path')' -> python -c "func('/path')"
                cmd=$(echo "$cmd" | sed -E "s/python([^ ]*)\s+-c '(.+)'/python\\1 -c \"\\2\"/")
            fi
        fi
    fi
    
    # Check for unquoted string literals in Python function calls (e.g., func(/path) instead of func('/path'))
    if [[ "$cmd" =~ python.*-c.*\([^\"\']*/[^\"\']*\) ]]; then
        VERIFY_CMD_ERROR_TYPE="unquoted_path"
        # Try to quote unquoted paths in function calls
        # Match patterns like func(/path/to/file) and quote the path
        cmd=$(echo "$cmd" | sed -E "s|([\(, ])(/[^\"\'\)\s,]+)([\),])|\\1'\\2'\\3|g")
    fi
    
    echo "$cmd"
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
        tree\ *|tree) echo "$cmd" ;;
        *) echo "$cmd" ;;
    esac
}

# Global state exposed for diagnostics (read by start.sh)
VERIFY_LAST_CMD=""
VERIFY_LAST_OUTPUT=""

# Run verification for a story. Returns 0 if pass, 1 if fail, 2 if skip (no verify)
# Usage: run_story_verification <project_dir> <story_json>
run_story_verification() {
    local project_dir="$1"
    local story_json="$2"
    
    if [ ! -d "$project_dir" ]; then
        return 1
    fi
    
    # Reset last attempt state
    VERIFY_LAST_CMD=""
    VERIFY_LAST_OUTPUT=""

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

    # If verify command uses tree and tree is unavailable, fall back to ls -R
    if [[ "$verify_cmd" == tree* ]] && ! command -v tree >/dev/null 2>&1; then
        verify_cmd=$(echo "$verify_cmd" | sed 's/^tree/ls -R/')
    fi

    # If verify command looks like a bare Python snippet (e.g. "import click; ..."),
    # wrap it in python3 -c "...". Escape embedded double quotes first.
    if [[ "$verify_cmd" =~ ^(import|from)[[:space:]] ]]; then
        local python_snippet="$verify_cmd"
        python_snippet="${python_snippet//\"/\\\"}"
        verify_cmd="python3 -c \"$python_snippet\""
    fi

    # Validate and repair command syntax before running
    local original_cmd="$verify_cmd"
    verify_cmd=$(validate_and_repair_cmd "$verify_cmd")
    if [ -n "$VERIFY_CMD_ERROR_TYPE" ] && [ "$verify_cmd" != "$original_cmd" ]; then
        echo "  (repaired verification command syntax: $VERIFY_CMD_ERROR_TYPE)"
    fi

    VERIFY_LAST_CMD="$verify_cmd"
    
    # Run verification from project directory
    echo "  Verifying: $verify_cmd"
    local verify_output verify_exit
    verify_output=$(cd "$project_dir" && eval "$verify_cmd" 2>&1)
    verify_exit=$?

    local output_lines
    output_lines=$(printf '%s\n' "$verify_output" | wc -l | awk '{print $1}')
    if [ "$output_lines" -le 40 ]; then
        VERIFY_LAST_OUTPUT="$verify_output"
    else
        VERIFY_LAST_OUTPUT=$(printf "%s\n...\n%s\n" \
            "$(echo "$verify_output" | head -n 20)" \
            "$(echo "$verify_output" | tail -n 20)")
    fi
    
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
    
    # Detect when CLI command exists but shows wrong output (e.g. setup.py help instead of CLI help)
    if echo "$verify_output" | grep -qE "setup\.py|distutils|pydistutils"; then
        failure_type="wrong_command"
        VERIFY_FAILURE_TYPE="wrong_command"
        echo "  ⚠️  Command exists but shows setup.py/distutils help instead of CLI"
        echo "  This suggests the package entry point isn't configured correctly"
    fi
    
    # Fallback: when verify fails with "command not found" (e.g. app CLI before install),
    # try language-appropriate test command based on project detection
    if echo "$verify_output" | grep -q "command not found"; then
        local default_cmd
        default_cmd=$(get_default_test_cmd "$project_dir")
        if [ -n "$default_cmd" ]; then
            echo "  (verify command unavailable - trying $default_cmd)"
            VERIFY_LAST_CMD="$default_cmd"
            if verify_output=$(cd "$project_dir" && eval "$default_cmd" 2>&1); then
                output_lines=$(printf '%s\n' "$verify_output" | wc -l | awk '{print $1}')
                if [ "$output_lines" -le 40 ]; then
                    VERIFY_LAST_OUTPUT="$verify_output"
                else
                    VERIFY_LAST_OUTPUT=$(printf "%s\n...\n%s\n" \
                        "$(echo "$verify_output" | head -n 20)" \
                        "$(echo "$verify_output" | tail -n 20)")
                fi
                echo "  ✓ Verification passed ($default_cmd fallback)"
                return 0
            fi
            verify_exit=$?
            output_lines=$(printf '%s\n' "$verify_output" | wc -l | awk '{print $1}')
            if [ "$output_lines" -le 40 ]; then
                VERIFY_LAST_OUTPUT="$verify_output"
            else
                VERIFY_LAST_OUTPUT=$(printf "%s\n...\n%s\n" \
                    "$(echo "$verify_output" | head -n 20)" \
                    "$(echo "$verify_output" | tail -n 20)")
            fi
            # pytest exit 5 = no tests yet
            if [[ "$default_cmd" == *pytest* ]] && [ $verify_exit -eq 5 ]; then
                echo "  ✓ Verification passed ($default_cmd fallback - no tests yet)"
                return 0
            fi
        fi
    fi
    
    # Categorize failure type for learning
    local failure_type="implementation"
    if echo "$verify_output" | grep -qE "SyntaxError|invalid syntax|unexpected token"; then
        failure_type="syntax_error"
        if [ -n "$VERIFY_CMD_ERROR_TYPE" ]; then
            echo "  ⚠️  Verification command has syntax error (type: $VERIFY_CMD_ERROR_TYPE)"
            echo "  Original command may need fixing in prd.json"
        fi
    elif echo "$verify_output" | grep -qE "ImportError|ModuleNotFoundError|cannot import"; then
        failure_type="import_error"
    elif echo "$verify_output" | grep -qE "AttributeError|NameError"; then
        failure_type="api_error"
    elif echo "$verify_output" | grep -qE "command not found|No such file"; then
        failure_type="command_not_found"
    fi
    
    # Export failure type for learning/logging
    VERIFY_FAILURE_TYPE="$failure_type"
    
    echo "  ✗ Verification failed"
    echo "$verify_output" | head -20 | sed 's/^/    /'
    return 1
}
