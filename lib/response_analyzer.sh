#!/bin/bash
#
# Ollama Response Analyzer
# Analyzes Ollama model responses to determine task completion
#

analyze_ollama_response() {
    local response="$1"
    local story_id="$2"
    
    # Strip ANSI escape sequences (ollama streaming adds these)
    response=$(echo "$response" | sed 's/\x1b\[[0-9;?]*[a-zA-Z]//g' 2>/dev/null || echo "$response")
    
    # Look for STATUS markers in the response
    local has_complete=$(echo "$response" | grep -i "STATUS:.*COMPLETE" || true)
    local has_incomplete=$(echo "$response" | grep -iE "STATUS:.*(INCOMPLETE|IN PROGRESS|IN_PROGRESS)" || true)
    
    # Extract learnings if present (truncate to avoid "Argument list too long" when passing to jq)
    local learnings=""
    if echo "$response" | grep -q "LEARNINGS:"; then
        learnings=$(echo "$response" | sed -n '/LEARNINGS:/,$p' | tail -n +2 | head -c 16384)
    fi
    
    # Determine completion status
    local complete="false"
    local status="working"
    
    if [ -n "$has_complete" ]; then
        complete="true"
        status="complete"
    elif [ -n "$has_incomplete" ]; then
        complete="false"
        status="incomplete"
    else
        # No explicit status - analyze the response content
        status=$(analyze_response_content "$response")
        
        # Consider it complete if the response indicates success
        if [ "$status" = "success" ]; then
            complete="true"
        fi
    fi
    
    # Return JSON analysis
    jq -n \
        --arg status "$status" \
        --arg complete "$complete" \
        --arg learnings "$learnings" \
        --arg story_id "$story_id" \
        '{
            story_id: $story_id,
            status: $status,
            complete: ($complete == "true"),
            learnings: $learnings
        }'
}

# Analyze response content when no explicit status
analyze_response_content() {
    local response="$1"
    
    # Look for success indicators
    local success_patterns=(
        "successfully implemented"
        "implementation complete"
        "task complete"
        "done"
        "finished"
        "all tests pass"
        "verified working"
    )
    
    # Look for explicit failure indicators (avoid matching "error codes", "handle errors" etc.)
    local error_patterns=(
        "Failed to"
        "Error:"
        "ERROR:"
        "implementation failed"
        "could not complete"
        "unable to complete"
        "task failed"
        "I failed"
        "I was unable"
        "I could not"
    )
    
    local has_success=false
    local has_error=false
    
    for pattern in "${success_patterns[@]}"; do
        if echo "$response" | grep -qi "$pattern"; then
            has_success=true
            break
        fi
    done
    
    for pattern in "${error_patterns[@]}"; do
        if echo "$response" | grep -qi "$pattern"; then
            has_error=true
            break
        fi
    done
    
    if [ "$has_success" = true ] && [ "$has_error" = false ]; then
        echo "success"
    elif [ "$has_error" = true ]; then
        echo "error"
    else
        echo "working"
    fi
}

# Check if response indicates the model wants to exit/stop
check_exit_signal() {
    local response="$1"
    
    # Look for explicit exit signals
    if echo "$response" | grep -qi "all.*stories.*complete"; then
        echo "true"
        return 0
    fi
    
    if echo "$response" | grep -qi "no.*more.*tasks"; then
        echo "true"
        return 0
    fi
    
    if echo "$response" | grep -qi "project.*complete"; then
        echo "true"
        return 0
    fi
    
    echo "false"
}

# Extract specific information from response
extract_response_field() {
    local response="$1"
    local field="$2"
    
    case "$field" in
        "reason")
            echo "$response" | sed -n '/REASON:/,/^$/p' | tail -n +2 | head -n -1
            ;;
        "next_steps")
            echo "$response" | sed -n '/NEXT_STEPS:/,/^$/p' | tail -n +2 | head -n -1
            ;;
        "learnings")
            echo "$response" | sed -n '/LEARNINGS:/,/^$/p' | tail -n +2 | head -n -1
            ;;
        *)
            echo ""
            ;;
    esac
}
