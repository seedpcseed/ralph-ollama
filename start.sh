#!/bin/bash
#
# Ralph Loop for Ollama
# Autonomous development loop using local Ollama models
#

set -e

# Source libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/utils.sh"
source "$SCRIPT_DIR/lib/circuit_breaker.sh"
source "$SCRIPT_DIR/lib/response_analyzer.sh"
source "$SCRIPT_DIR/lib/response_applier.sh"
source "$SCRIPT_DIR/lib/verification.sh"

# Configuration
PROJECTS_DIR="$SCRIPT_DIR/projects"
LIB_DIR="$SCRIPT_DIR/lib"
TEMPLATES_DIR="$SCRIPT_DIR/templates"

# Default settings
DEFAULT_MODEL="codellama:latest"
DEFAULT_TIMEOUT=20
DEFAULT_MAX_CALLS=100
SLEEP_DURATION=3600  # 1 hour

# Parse arguments
PROJECT_NAME=""
MONITOR_MODE=false
MAX_CALLS=$DEFAULT_MAX_CALLS
TIMEOUT_MINUTES=$DEFAULT_TIMEOUT
SHOW_STATUS=false
RESET_CB=false
OLLAMA_MODEL="$DEFAULT_MODEL"

show_usage() {
    cat << EOF
Usage: $0 <project-name> [options]

Options:
    -m, --monitor           Start with tmux monitoring session
    -M, --model MODEL       Ollama model to use (default: $DEFAULT_MODEL)
    -c, --calls NUM         Max calls per hour (default: $DEFAULT_MAX_CALLS)
    -t, --timeout MIN       Agent timeout in minutes (default: $DEFAULT_TIMEOUT)
    -s, --status           Show project status and exit
    -r, --reset            Reset circuit breaker
    -h, --help             Show this help message

Available Ollama Models (common):
    codellama:latest       Code-focused model (7B)
    codellama:13b          Larger code model
    codellama:34b          Largest code model
    deepseek-coder:latest  DeepSeek Coder (6.7B)
    deepseek-coder:33b     Larger DeepSeek
    llama3.1:latest        General purpose (8B)
    qwen2.5-coder:latest   Qwen Coder (7B)
    
Examples:
    $0 my-feature --monitor
    $0 my-feature --model deepseek-coder:33b
    $0 my-feature --status
    $0 my-feature --reset

EOF
    exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_usage
            ;;
        -m|--monitor)
            MONITOR_MODE=true
            shift
            ;;
        -M|--model)
            OLLAMA_MODEL="$2"
            shift 2
            ;;
        -c|--calls)
            MAX_CALLS="$2"
            shift 2
            ;;
        -t|--timeout)
            TIMEOUT_MINUTES="$2"
            shift 2
            ;;
        -s|--status)
            SHOW_STATUS=true
            shift
            ;;
        -r|--reset)
            RESET_CB=true
            shift
            ;;
        *)
            if [ -z "$PROJECT_NAME" ]; then
                PROJECT_NAME="$1"
            else
                echo "Error: Unknown option: $1"
                exit 1
            fi
            shift
            ;;
    esac
done

if [ -z "$PROJECT_NAME" ]; then
    echo "Error: Project name required"
    show_usage
fi

PROJECT_DIR="$PROJECTS_DIR/$PROJECT_NAME"

# Check if project exists
if [ ! -d "$PROJECT_DIR" ]; then
    echo "Error: Project '$PROJECT_NAME' not found in $PROJECTS_DIR"
    echo "Run: ./new.sh $PROJECT_NAME to create it"
    exit 1
fi

# Required files
PRD_JSON="$PROJECT_DIR/prd.json"
STATUS_FILE="$PROJECT_DIR/status.json"
PROGRESS_FILE="$PROJECT_DIR/progress.txt"
LOG_DIR="$PROJECT_DIR/logs"
CB_FILE="$PROJECT_DIR/.circuit_breaker"
PROMPT_FILE="$PROJECT_DIR/PROMPT.md"

mkdir -p "$LOG_DIR"

# Handle status and reset commands
if [ "$SHOW_STATUS" = true ]; then
    show_project_status "$PROJECT_DIR"
    exit 0
fi

if [ "$RESET_CB" = true ]; then
    reset_circuit_breaker "$CB_FILE"
    echo "✓ Circuit breaker reset"
    exit 0
fi

# Check Ollama installation
if ! command -v ollama &> /dev/null; then
    echo "Error: Ollama not found. Please install:"
    echo "  curl -fsSL https://ollama.com/install.sh | sh"
    exit 1
fi

# Check if model is available
echo "Checking Ollama model: $OLLAMA_MODEL"
if ! ollama list | grep -q "^${OLLAMA_MODEL%%:*}"; then
    echo "Model $OLLAMA_MODEL not found locally. Pulling..."
    ollama pull "$OLLAMA_MODEL"
fi

# Initialize status file if needed
if [ ! -f "$STATUS_FILE" ]; then
    echo '{"loop_count": 0, "completed_stories": 0, "call_count": 0}' > "$STATUS_FILE"
fi

# Start monitoring if requested
if [ "$MONITOR_MODE" = true ]; then
    SESSION_NAME="ralph-$PROJECT_NAME"
    
    if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
        echo "Session $SESSION_NAME already exists. Attaching..."
        tmux attach-session -t "$SESSION_NAME"
        exit 0
    fi
    
    echo "Starting Ralph with tmux monitoring..."
    tmux new-session -d -s "$SESSION_NAME" -n main
    tmux split-window -h -t "$SESSION_NAME":main
    # Pass through model, calls, and timeout so the loop uses them
    LOOP_CMD="$0 $PROJECT_NAME --model $OLLAMA_MODEL --calls $MAX_CALLS --timeout $TIMEOUT_MINUTES"
    tmux send-keys -t "$SESSION_NAME":main.0 "$LOOP_CMD" C-m
    tmux send-keys -t "$SESSION_NAME":main.1 "./monitor.sh $PROJECT_NAME" C-m
    tmux select-pane -t "$SESSION_NAME":main.0
    tmux attach-session -t "$SESSION_NAME"
    exit 0
fi

# Main loop
echo "=================================================="
echo "Ralph Loop for Ollama"
echo "=================================================="
echo "Project: $PROJECT_NAME"
echo "Model: $OLLAMA_MODEL"
echo "Max calls/hour: $MAX_CALLS"
echo "Timeout: ${TIMEOUT_MINUTES}m"
echo "=================================================="
echo ""

LOOP_COUNT=0
CALL_COUNT=0
HOUR_START=$(date +%s)

while true; do
    LOOP_COUNT=$((LOOP_COUNT + 1))
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    LOG_FILE="$LOG_DIR/loop_${LOOP_COUNT}_$(date +%Y%m%d_%H%M%S).log"
    
    echo "[$TIMESTAMP] Loop #$LOOP_COUNT" | tee -a "$LOG_FILE"
    
    # Check circuit breaker
    if ! check_circuit_breaker "$CB_FILE"; then
        echo "Circuit breaker OPEN. Loop stopped."
        echo "Run: $0 $PROJECT_NAME --reset to continue"
        exit 1
    fi
    
    # Rate limiting
    CURRENT_TIME=$(date +%s)
    TIME_ELAPSED=$((CURRENT_TIME - HOUR_START))
    
    if [ $TIME_ELAPSED -ge $SLEEP_DURATION ]; then
        # Reset for new hour
        CALL_COUNT=0
        HOUR_START=$CURRENT_TIME
        echo "Rate limit reset: $CALL_COUNT/$MAX_CALLS calls this hour"
    fi
    
    if [ $CALL_COUNT -ge $MAX_CALLS ]; then
        WAIT_TIME=$((SLEEP_DURATION - TIME_ELAPSED))
        echo "Rate limit reached ($MAX_CALLS calls/hour)"
        echo "Waiting ${WAIT_TIME}s for next hour..."
        sleep $WAIT_TIME
        CALL_COUNT=0
        HOUR_START=$(date +%s)
    fi
    
    # Get next task
    NEXT_STORY=$(get_next_story "$PRD_JSON")
    
    if [ "$NEXT_STORY" = "COMPLETE" ]; then
        echo "🎉 All stories complete!"
        update_status "$STATUS_FILE" "completed" "$LOOP_COUNT" 0
        exit 0
    fi
    
    if [ "$NEXT_STORY" = "ERROR" ]; then
        echo "Error reading PRD"
        record_circuit_breaker_failure "$CB_FILE" "prd_read_error"
        exit 1
    fi
    
    STORY_ID=$(echo "$NEXT_STORY" | jq -r '.id')
    echo "Working on story: $STORY_ID"
    echo "$NEXT_STORY" | jq -r '.story'
    
    # Build prompt
    FULL_PROMPT=$(build_ollama_prompt "$PROJECT_DIR" "$NEXT_STORY")
    
    # Call Ollama
    echo "Calling Ollama ($OLLAMA_MODEL)..." | tee -a "$LOG_FILE"
    CALL_COUNT=$((CALL_COUNT + 1))
    
    RESPONSE_FILE="$LOG_DIR/response_${LOOP_COUNT}.txt"
    
    # Run ollama with timeout
    if timeout "${TIMEOUT_MINUTES}m" ollama run "$OLLAMA_MODEL" "$FULL_PROMPT" > "$RESPONSE_FILE" 2>&1; then
        OLLAMA_EXIT=0
    else
        OLLAMA_EXIT=$?
    fi
    
    cat "$RESPONSE_FILE" >> "$LOG_FILE"
    
    if [ $OLLAMA_EXIT -ne 0 ]; then
        if [ $OLLAMA_EXIT -eq 124 ]; then
            echo "Timeout after ${TIMEOUT_MINUTES} minutes"
            record_circuit_breaker_failure "$CB_FILE" "timeout"
        else
            echo "Ollama failed with exit code: $OLLAMA_EXIT"
            record_circuit_breaker_failure "$CB_FILE" "ollama_error"
        fi
        continue
    fi
    
    # Apply file writes from model response (extract code blocks and write to project)
    RESPONSE_TEXT=$(cat "$RESPONSE_FILE")
    echo "Applying file writes from response..."
    apply_response_to_files "$RESPONSE_TEXT" "$PROJECT_DIR" "$STORY_ID"
    
    # Analyze response
    ANALYSIS=$(analyze_ollama_response "$RESPONSE_TEXT" "$STORY_ID")
    
    STATUS=$(echo "$ANALYSIS" | jq -r '.status')
    COMPLETE=$(echo "$ANALYSIS" | jq -r '.complete')
    
    echo "Analysis: status=$STATUS, complete=$COMPLETE"
    
    if [ "$STATUS" = "error" ]; then
        record_circuit_breaker_failure "$CB_FILE" "analysis_error"
        continue
    fi
    
    # Record learnings if any
    LEARNINGS=$(echo "$ANALYSIS" | jq -r '.learnings // empty')
    if [ -n "$LEARNINGS" ]; then
        echo "" >> "$PROGRESS_FILE"
        echo "## $(date '+%Y-%m-%d') - Story $STORY_ID" >> "$PROGRESS_FILE"
        echo "$LEARNINGS" >> "$PROGRESS_FILE"
        echo "Learnings recorded to $PROGRESS_FILE"
    fi
    
    if [ "$COMPLETE" = "true" ]; then
        # P0: Run verification before marking complete
        # Use || to prevent set -e from exiting when verification fails (returns 1)
        VERIFY_RESULT=0
        run_story_verification "$PROJECT_DIR" "$NEXT_STORY" || VERIFY_RESULT=$?
        if [ $VERIFY_RESULT -eq 1 ]; then
            echo "Story $STORY_ID not marked complete - verification failed"
            echo "Fix the implementation and Ralph will retry on next run"
        else
            echo "✓ Story $STORY_ID marked complete"
            mark_story_complete "$PRD_JSON" "$STORY_ID"
            
            # Reset circuit breaker on success
            reset_circuit_breaker "$CB_FILE"
            
            # Commit if in git repo
            if git rev-parse --git-dir > /dev/null 2>&1; then
                git add .
                git commit -m "Ralph: Completed story $STORY_ID" || true
            fi
        fi
    else
        echo "Story $STORY_ID not yet complete, continuing..."
    fi
    
    # Update status
    COMPLETED_COUNT=$(count_completed_stories "$PRD_JSON")
    update_status "$STATUS_FILE" "running" "$LOOP_COUNT" "$COMPLETED_COUNT"
    
    echo ""
    sleep 2
done
