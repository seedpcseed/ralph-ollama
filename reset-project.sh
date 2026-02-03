#!/bin/bash

# Reset a project to minimal state for re-testing convert.sh and start.sh
# Keeps prd.md and PROMPT.md; removes generated files, state, and code.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/utils.sh"

show_help() {
    cat << 'HELPEOF'
Reset project to minimal state (keeps prd.md only for re-testing convert/start)

Usage: $0 <project-name>

What is kept:
  - prd.md (your requirements)
  - PROMPT.md (refreshed from template)

What is removed:
  - prd.json, requirements.md, progress.txt, status.json
  - Circuit breaker and rate-limit state
  - Generated code (e.g. src/, Cargo.toml, etc.)
  - Logs and current prompt cache

After reset:
  1. ./convert.sh <project-name>   # regenerate prd.json and requirements.md
  2. ./start.sh <project-name>     # run the loop

HELPEOF
}

main() {
    local project_name="${1:-}"

    if [[ -z "$project_name" ]]; then
        log "ERROR" "Project name required"
        show_help
        exit 1
    fi

    local project_dir="$SCRIPT_DIR/projects/$project_name"

    if [[ ! -d "$project_dir" ]]; then
        log "ERROR" "Project '$project_name' not found at $project_dir"
        exit 1
    fi

    if [[ ! -f "$project_dir/prd.md" ]]; then
        log "ERROR" "No prd.md in project (cannot reset)"
        exit 1
    fi

    log "INFO" "Resetting project: $project_name"

    # Remove generated / state files
    rm -f "$project_dir/prd.json"
    rm -f "$project_dir/requirements.md"
    rm -f "$project_dir/progress.txt"
    rm -f "$project_dir/status.json"
    rm -f "$project_dir/.circuit_breaker.json"
    rm -f "$project_dir/.circuit_breaker.history"
    rm -f "$project_dir/.call_count"
    rm -f "$project_dir/.last_reset"
    rm -f "$project_dir/.last_analysis.json"
    rm -f "$project_dir/.ralph_current_prompt.md"

    # Remove generated code (Rust, Python, etc.)
    rm -rf "$project_dir/src"
    rm -f "$project_dir/Cargo.toml"
    rm -rf "$project_dir/crates"
    # Common other roots
    for d in lib app bin; do
        [[ -d "$project_dir/$d" ]] && rm -rf "$project_dir/$d"
    done

    # Refresh PROMPT.md from template (optional but consistent)
    if [[ -f "$SCRIPT_DIR/templates/PROMPT.md" ]]; then
        cp "$SCRIPT_DIR/templates/PROMPT.md" "$project_dir/PROMPT.md"
        log "INFO" "Refreshed PROMPT.md from template"
    fi

    # Empty logs (optional; keeps dir)
    if [[ -d "$project_dir/logs" ]]; then
        rm -f "$project_dir/logs"/*.log "$project_dir/logs"/*.txt 2>/dev/null || true
        log "INFO" "Cleared logs"
    fi

    log "SUCCESS" "Project '$project_name' reset to minimal state (prd.md + PROMPT.md kept)"
    echo ""
    echo "Next steps:"
    echo "  ./convert.sh $project_name    # regenerate prd.json and requirements.md"
    echo "  ./start.sh $project_name     # run the loop"
    echo ""
}

case "${1:-}" in
    -h|--help) show_help; exit 0 ;;
    "") show_help; exit 1 ;;
    *) main "$@" ;;
esac
