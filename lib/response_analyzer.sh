#!/bin/bash

# Ralph Response Analyzer - Analyzes Aider output
# Detects completion signals, errors, and progress

# Analysis result file
ANALYSIS_FILE=".last_analysis.json"

# Analyze Aider response
analyze_response() {
    local output_file=$1
    local project_dir=$2
    local story_id=${3:-""}
    local analysis_file="$project_dir/$ANALYSIS_FILE"
    
    if [[ ! -f "$output_file" ]]; then
        log "WARN" "No output file to analyze"
        return 1
    fi
    
    local output_content=$(cat "$output_file")
    local output_length=${#output_content}
    
    # Aider completion signals:
    # 1. "Applied edit to <file>" - file was modified
    # 2. "Created <file>" - file was created
    # 3. "Commit <hash>" - changes were committed
    # 4. No errors/warnings about unable to complete
    # 5. Exit code 0
    
    local has_edits=false
    local has_commit=false
    local has_errors=false
    local files_modified=0
    
    # Check for file edits
    if echo "$output_content" | grep -q "Applied edit to\|Created\|Modified"; then
        has_edits=true
        files_modified=$(echo "$output_content" | grep -c "Applied edit to\|Created\|Modified" || echo "0")
    fi
    
    # Check for git commit
    if echo "$output_content" | grep -q "Commit [0-9a-f]\{7\}"; then
        has_commit=true
    fi
    
    # Check for error signals
    if echo "$output_content" | grep -qi "error\|failed\|cannot\|unable to"; then
        has_errors=true
    fi
    
    # Also check for explicit completion signals
    local has_completion_signal=false
    local completion_signals=0
    if echo "$output_content" | grep -qi "task complete\|story complete\|implementation complete"; then
        has_completion_signal=true
        completion_signals=1
    fi
    
    # Status determination
    local status="UNKNOWN"
    local exit_signal="false"
    
    if [ "$has_errors" = true ]; then
        status="ERROR"
    elif [ "$has_edits" = true ] || [ "$has_commit" = true ] || [ "$has_completion_signal" = true ]; then
        status="SUCCESS"
        exit_signal="true"
    else
        status="NO_CHANGES"
    fi
    
    # Extract error message if present
    local error_count=0
    local error_message=""
    
    if [ "$has_errors" = true ]; then
        error_count=$(echo "$output_content" | grep -ci "error\|failed\|cannot\|unable to" || echo "0")
        error_message=$(echo "$output_content" | grep -i "error\|failed\|cannot\|unable to" | head -1 | head -c 200)
    fi
    
    # Write analysis result
    cat > "$analysis_file" << EOF
{
    "timestamp": "$(date -u '+%Y-%m-%dT%H:%M:%SZ')",
    "output_length": $output_length,
    "status": "$status",
    "files_modified": $files_modified,
    "exit_signal": $exit_signal,
    "completion_signals": $completion_signals,
    "has_errors": $([ "$has_errors" = true ] && echo "true" || echo "false"),
    "has_edits": $([ "$has_edits" = true ] && echo "true" || echo "false"),
    "has_commit": $([ "$has_commit" = true ] && echo "true" || echo "false"),
    "error_count": $error_count,
    "error_message": "$(echo "$error_message" | head -c 200 | sed 's/"/\\"/g')"
}
EOF
    
    # Append to progress if story_id provided
    if [[ -n "$story_id" ]]; then
        append_to_progress "$project_dir" "$story_id" "$output_content"
    fi
    
    # Return appropriate exit code
    if [[ "$exit_signal" == "true" ]]; then
        return 0  # Success - story complete
    elif [[ "$has_errors" == "true" ]]; then
        return 1  # Has errors
    else
        return 1  # No clear success indicators
    fi
}

# Get last analysis result
get_analysis_result() {
    local project_dir=$1
    local field=$2
    local analysis_file="$project_dir/$ANALYSIS_FILE"
    
    if [[ -f "$analysis_file" ]]; then
        jq -r ".$field" "$analysis_file"
    else
        echo ""
    fi
}

# Check if should exit based on analysis
should_exit_gracefully() {
    local project_dir=$1
    local analysis_file="$project_dir/$ANALYSIS_FILE"
    
    if [[ ! -f "$analysis_file" ]]; then
        return 1  # Don't exit
    fi
    
    local exit_signal=$(jq -r '.exit_signal' "$analysis_file")
    local completion_signals=$(jq -r '.completion_signals' "$analysis_file")
    
    # Exit if Claude signaled completion
    if [[ "$exit_signal" == "true" ]]; then
        echo "exit_signal"
        return 0
    fi
    
    # Exit if multiple completion signals detected
    if [[ $completion_signals -ge 2 ]]; then
        echo "completion_signals"
        return 0
    fi
    
    return 1
}

# Log analysis summary
log_analysis_summary() {
    local project_dir=$1
    local analysis_file="$project_dir/$ANALYSIS_FILE"
    
    if [[ ! -f "$analysis_file" ]]; then
        return
    fi
    
    local status=$(jq -r '.status' "$analysis_file")
    local files=$(jq -r '.files_modified' "$analysis_file")
    local has_edits=$(jq -r '.has_edits' "$analysis_file")
    local has_commit=$(jq -r '.has_commit' "$analysis_file")
    local exit_sig=$(jq -r '.exit_signal' "$analysis_file")
    local has_errors=$(jq -r '.has_errors' "$analysis_file")
    
    log "INFO" "Analysis: status=$status, files=$files, edits=$has_edits, commit=$has_commit, exit=$exit_sig, errors=$has_errors"
}

# Append to progress file
append_to_progress() {
    local project_dir=$1
    local story_id=$2
    local response=$3
    
    local progress_file="$project_dir/progress.txt"
    local timestamp=$(date "+%Y-%m-%d %H:%M")
    
    # Extract learnings from response (Aider often explains what it did)
    local summary=$(echo "$response" | grep -A 5 "Applied edit\|Created\|Modified" | head -10)
    
    cat >> "$progress_file" <<EOF

---
## $timestamp - Story $story_id
$summary

EOF
}
