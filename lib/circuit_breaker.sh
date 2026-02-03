#!/bin/bash
#
# Circuit Breaker for Ralph-Ollama
# Prevents infinite loops on repeated failures
#

CB_MAX_FAILURES=5
CB_RESET_TIME=3600  # 1 hour

# Initialize circuit breaker
init_circuit_breaker() {
    local cb_file="$1"
    
    if [ ! -f "$cb_file" ]; then
        echo "CLOSED" > "$cb_file"
        echo "0" > "${cb_file}.failures"
        date +%s > "${cb_file}.timestamp"
    fi
}

# Check circuit breaker state
check_circuit_breaker() {
    local cb_file="$1"
    
    init_circuit_breaker "$cb_file"
    
    local state=$(cat "$cb_file")
    
    if [ "$state" = "OPEN" ]; then
        # Check if enough time has passed for auto-reset
        local timestamp=$(cat "${cb_file}.timestamp" 2>/dev/null || echo "0")
        local current=$(date +%s)
        local elapsed=$((current - timestamp))
        
        if [ $elapsed -ge $CB_RESET_TIME ]; then
            echo "Circuit breaker auto-reset after ${CB_RESET_TIME}s"
            reset_circuit_breaker "$cb_file"
            return 0
        fi
        
        return 1
    fi
    
    return 0
}

# Record a failure
record_circuit_breaker_failure() {
    local cb_file="$1"
    local failure_type="$2"
    
    init_circuit_breaker "$cb_file"
    
    local failures=$(cat "${cb_file}.failures")
    failures=$((failures + 1))
    
    echo "$failures" > "${cb_file}.failures"
    echo "$failure_type" >> "${cb_file}.history"
    
    echo "Failure recorded: $failure_type (${failures}/${CB_MAX_FAILURES})"
    
    if [ $failures -ge $CB_MAX_FAILURES ]; then
        echo "OPEN" > "$cb_file"
        date +%s > "${cb_file}.timestamp"
        echo "⚠️  Circuit breaker OPENED after $CB_MAX_FAILURES failures"
        echo "Recent failures:"
        tail -n $CB_MAX_FAILURES "${cb_file}.history" | sed 's/^/  - /'
    fi
}

# Reset circuit breaker
reset_circuit_breaker() {
    local cb_file="$1"
    
    echo "CLOSED" > "$cb_file"
    echo "0" > "${cb_file}.failures"
    date +%s > "${cb_file}.timestamp"
    
    echo "✓ Circuit breaker reset to CLOSED"
}

# Get circuit breaker status
get_circuit_breaker_status() {
    local cb_file="$1"
    
    init_circuit_breaker "$cb_file"
    
    local state=$(cat "$cb_file")
    local failures=$(cat "${cb_file}.failures")
    local timestamp=$(cat "${cb_file}.timestamp")
    
    jq -n \
        --arg state "$state" \
        --argjson failures "$failures" \
        --argjson timestamp "$timestamp" \
        --argjson max_failures "$CB_MAX_FAILURES" \
        '{
            state: $state,
            failures: $failures,
            max_failures: $max_failures,
            timestamp: $timestamp
        }'
}
