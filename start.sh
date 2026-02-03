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
STUCK_THRESHOLD=3

declare -A STORY_FAILURE_COUNT
declare -A STORY_FAILURE_SIGNATURE
declare -A STORY_STUCK_SIGNATURE

record_stuck_failure() {
    local story_id="$1"
    local verify_cmd="$2"
    local verify_output="$3"
    local progress_file="$4"
    local attempts="$5"
    local failure_type="${6:-unknown}"

    echo "⚠️  Detected repeated verification failure for story $story_id ($attempts attempts). Logging guidance for next attempt."
    touch "$progress_file"

    {
        echo ""
        echo "## $(date '+%Y-%m-%d %H:%M:%S') - Stuck on story $story_id"
        echo "Verification command failing repeatedly ($attempts attempts, type: $failure_type):"
        echo "    $verify_cmd"
        if [ -n "$verify_output" ]; then
            echo "Latest output (truncated):"
            echo "$verify_output" | head -n 20 | sed 's/^/    /'
        fi
        
        # Provide specific guidance based on failure type
        case "$failure_type" in
            syntax_error)
                echo ""
                echo "⚠️  VERIFICATION COMMAND HAS SYNTAX ERROR"
                echo "The verify command in prd.json is malformed. Common issues:"
                echo "  - Unmatched quotes (e.g., python -c 'func(\"/path\")' should be python -c 'func(\"/path\")')"
                echo "  - Unquoted paths in Python expressions"
                echo "ACTION: Fix the verify field in prd.json for story $story_id"
                echo "Example fix: Use double quotes for outer, single for inner: python -c \"from mod import func; func('/path')\""
                ;;
            import_error)
                echo ""
                echo "Guidance: Import errors suggest missing modules or incorrect import paths."
                echo "Check that:"
                echo "  - Required modules exist and are in the correct location"
                echo "  - Import paths match the actual file structure"
                echo "  - __init__.py files exist where needed"
                ;;
            api_error)
                echo ""
                echo "Guidance: API errors suggest the function/class exists but has wrong signature or doesn't work as expected."
                echo "Check the actual implementation matches what the verification expects."
                ;;
            missing_file)
                echo ""
                echo "⚠️  REQUIRED FILES ARE MISSING"
                echo "The verification is failing because required files don't exist."
                echo "Check the error message to see which files are missing."
                echo "ACTION: Ensure the story implementation creates the required files."
                echo "Common missing files: setup.py, pyproject.toml, __init__.py, or other project files"
                ;;
            command_not_found)
                echo ""
                echo "Guidance: Command not found - the tool/script may not be installed or in PATH."
                ;;
            wrong_command)
                echo ""
                echo "⚠️  VERIFICATION COMMAND SHOWS WRONG OUTPUT"
                echo "The command exists but shows setup.py/distutils help instead of CLI help."
                echo "This suggests:"
                echo "  - Package entry point isn't configured correctly in setup.py/pyproject.toml"
                echo "  - Or the verify command is testing CLI before package is installed"
                echo "ACTION: Either fix the entry point config OR change verify command to test implementation directly"
                echo "Example: Use 'python -m loglens' or test the actual code, not 'loglens --help'"
                ;;
            *)
                echo ""
                echo "Guidance: Investigate why this verification is failing and try a different approach instead of repeating the same steps."
                if [[ "$verify_cmd" == *"pip install"* ]]; then
                    echo "Hint: For pip/install failures, confirm packaging metadata (setup.py/pyproject) and entry points are correct."
                fi
                ;;
        esac
    } >> "$progress_file"
}

compute_failure_signature() {
    if command -v md5sum >/dev/null 2>&1; then
        md5sum | awk '{print $1}'
    elif command -v sha1sum >/dev/null 2>&1; then
        sha1sum | awk '{print $1}'
    else
        python3 - <<'PY'
import sys, hashlib
data = sys.stdin.buffer.read()
print(hashlib.sha256(data).hexdigest())
PY
    fi
}

normalize_output_for_signature() {
    sed -E '
        s/[0-9a-f]{8,}/<HEX>/g;
        s#[0-9]{4,}#<NUM>#g;
        s#/tmp/[^[:space:]]+#/tmp/<PATH>#g;
        s#/home/[^[:space:]]+#/home/<PATH>#g;
    '
}

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

if [ ! -f "$PRD_JSON" ]; then
    echo "Error: prd.json not found. Run ./convert.sh $PROJECT_NAME first."
    exit 1
fi

if ! validate_prd_json "$PRD_JSON"; then
    echo "Error: prd.json is invalid or missing userStories."
    echo "Run ./convert.sh $PROJECT_NAME to regenerate from prd.md"
    exit 1
fi
PROGRESS_FILE="$PROJECT_DIR/progress.txt"
LOG_DIR="$PROJECT_DIR/logs"
CB_FILE="$PROJECT_DIR/.circuit_breaker"
PROMPT_FILE="$PROJECT_DIR/PROMPT.md"

mkdir -p "$LOG_DIR"

# Require PRD to be customized (not still the template)
if [ -f "$PROJECT_DIR/prd.md" ] && is_prd_template_unchanged "$PROJECT_DIR/prd.md" "$TEMPLATES_DIR/prd-template.md"; then
    echo "Error: PRD has not been customized from the template."
    echo "Edit $PROJECT_DIR/prd.md with your project requirements."
    echo "Then run: ./convert.sh $PROJECT_NAME"
    echo "Then run: $0 $PROJECT_NAME"
    exit 1
fi

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
SESSION_START=$(date +%s)
SESSION_LOG="$LOG_DIR/session_$(date +%Y%m%d_%H%M%S).log"

# Initialize session log
{
    echo "=================================================="
    echo "Ralph Session Log"
    echo "=================================================="
    echo "Project: $PROJECT_NAME"
    echo "Model: $OLLAMA_MODEL"
    echo "Started: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "=================================================="
    echo ""
} > "$SESSION_LOG"

# Log session event
log_session_event() {
    local event_type="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$event_type] $message" | tee -a "$SESSION_LOG"
}

log_session_event "SESSION" "Started Ralph loop"

while true; do
    LOOP_COUNT=$((LOOP_COUNT + 1))
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    LOG_FILE="$LOG_DIR/loop_${LOOP_COUNT}_$(date +%Y%m%d_%H%M%S).log"
    
    echo "[$TIMESTAMP] Loop #$LOOP_COUNT" | tee -a "$LOG_FILE"
    
    # Check circuit breaker
    if ! check_circuit_breaker "$CB_FILE"; then
        echo "Circuit breaker OPEN. Loop stopped."
        SESSION_DURATION=$(( $(date +%s) - SESSION_START ))
        log_session_event "SESSION" "Stopped: Circuit breaker OPEN after $LOOP_COUNT loops ($(($SESSION_DURATION / 60))m $(($SESSION_DURATION % 60))s)"
        echo "Session log: $SESSION_LOG"
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
        SESSION_DURATION=$(( $(date +%s) - SESSION_START ))
        log_session_event "SESSION" "Completed all stories after $LOOP_COUNT loops ($(($SESSION_DURATION / 60))m $(($SESSION_DURATION % 60))s)"
        update_status "$STATUS_FILE" "completed" "$LOOP_COUNT" 0
        echo "Session log: $SESSION_LOG"
        exit 0
    fi
    
    if [ "$NEXT_STORY" = "ERROR" ]; then
        echo "Error reading PRD"
        record_circuit_breaker_failure "$CB_FILE" "prd_read_error"
        exit 1
    fi
    
    STORY_ID=$(echo "$NEXT_STORY" | jq -r '.id')
    STORY_DESC=$(echo "$NEXT_STORY" | jq -r '.story')
    echo "Working on story: $STORY_ID"
    echo "$STORY_DESC"
    log_session_event "STORY" "Starting story $STORY_ID: $STORY_DESC"
    
    # Build prompt
    FULL_PROMPT=$(build_ollama_prompt "$PROJECT_DIR" "$NEXT_STORY")
    
    # Call Ollama
    echo "Calling Ollama ($OLLAMA_MODEL)..." | tee -a "$LOG_FILE"
    CALL_COUNT=$((CALL_COUNT + 1))
    
    RESPONSE_FILE="$LOG_DIR/response_${LOOP_COUNT}.txt"
    PROMPT_FILE="$LOG_DIR/prompt_${LOOP_COUNT}.txt"
    
    # Write prompt to file to avoid "argument list too long" errors
    # Use printf to preserve exact content (echo might add newlines)
    printf '%s' "$FULL_PROMPT" > "$PROMPT_FILE"
    
    # Run ollama with timeout, using process substitution to avoid argument length limits
    # Check prompt size and warn if very large
    PROMPT_SIZE=$(wc -c < "$PROMPT_FILE" 2>/dev/null || echo "0")
    if [ "$PROMPT_SIZE" -gt 100000 ]; then
        log_session_event "WARN" "Story $STORY_ID: Large prompt ($PROMPT_SIZE bytes), may cause issues"
    fi
    
    # Use process substitution to pass prompt file content
    # This avoids shell argument length limits by not expanding the prompt in the command line
    if timeout "${TIMEOUT_MINUTES}m" bash -c "ollama run '$OLLAMA_MODEL' \"\$(cat '$PROMPT_FILE')\"" > "$RESPONSE_FILE" 2>&1; then
        OLLAMA_EXIT=0
    else
        OLLAMA_EXIT=$?
        # If we got "argument list too long", try alternative method
        if grep -q "Argument list too long" "$RESPONSE_FILE" 2>/dev/null; then
            log_session_event "ERROR" "Story $STORY_ID: Prompt too large ($PROMPT_SIZE bytes), truncating progress.txt"
            # Truncate progress.txt to prevent future issues
            if [ -f "$PROJECT_DIR/progress.txt" ]; then
                tail -n 20 "$PROJECT_DIR/progress.txt" > "${PROJECT_DIR}/progress.txt.tmp" && mv "${PROJECT_DIR}/progress.txt.tmp" "$PROJECT_DIR/progress.txt"
            fi
        fi
    fi
    
    # Keep prompt file for debugging (truncate if very large)
    if [ -f "$PROMPT_FILE" ]; then
        PROMPT_SIZE=$(wc -c < "$PROMPT_FILE" 2>/dev/null || echo "0")
        if [ "$PROMPT_SIZE" -gt 100000 ]; then
            # Truncate very large prompts to last 50KB for debugging
            tail -c 50000 "$PROMPT_FILE" > "${PROMPT_FILE}.truncated" && mv "${PROMPT_FILE}.truncated" "$PROMPT_FILE"
        fi
    fi
    
    cat "$RESPONSE_FILE" >> "$LOG_FILE"
    
    if [ $OLLAMA_EXIT -ne 0 ]; then
        if [ $OLLAMA_EXIT -eq 124 ]; then
            echo "Timeout after ${TIMEOUT_MINUTES} minutes"
            log_session_event "ERROR" "Story $STORY_ID: Ollama timeout after ${TIMEOUT_MINUTES}m"
            record_circuit_breaker_failure "$CB_FILE" "timeout"
        else
            echo "Ollama failed with exit code: $OLLAMA_EXIT"
            ERROR_PREVIEW=$(head -n 5 "$RESPONSE_FILE" | tr '\n' ' ' | cut -c1-200)
            log_session_event "ERROR" "Story $STORY_ID: Ollama failed (exit $OLLAMA_EXIT). Preview: $ERROR_PREVIEW"
            record_circuit_breaker_failure "$CB_FILE" "ollama_error"
        fi
        continue
    fi
    
    # Apply file writes from model response (extract code blocks and write to project)
    RESPONSE_TEXT=$(cat "$RESPONSE_FILE")
    echo "Applying file writes from response..."
    FILES_OUTPUT=$(apply_response_to_files "$RESPONSE_TEXT" "$PROJECT_DIR" "$STORY_ID" 2>&1)
    echo "$FILES_OUTPUT"
    if echo "$FILES_OUTPUT" | grep -q "Wrote"; then
        FILES_LIST=$(echo "$FILES_OUTPUT" | grep "Wrote" | sed 's/.*Wrote //' | tr '\n' ',' | sed 's/,$//')
        log_session_event "FILES" "Story $STORY_ID: Wrote files: $FILES_LIST"
    fi
    
    # Analyze response
    ANALYSIS=$(analyze_ollama_response "$RESPONSE_TEXT" "$STORY_ID")
    
    STATUS=$(echo "$ANALYSIS" | jq -r '.status')
    COMPLETE=$(echo "$ANALYSIS" | jq -r '.complete')
    
    echo "Analysis: status=$STATUS, complete=$COMPLETE"
    
    if [ "$STATUS" = "error" ]; then
        ERROR_MSG=$(echo "$ANALYSIS" | jq -r '.error // "unknown error"' 2>/dev/null || echo "unknown error")
        log_session_event "ERROR" "Story $STORY_ID: Response analysis failed - $ERROR_MSG"
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
        # Trim progress file if it gets too large (every 10 loops to avoid overhead)
        if [ $((LOOP_COUNT % 10)) -eq 0 ]; then
            trim_progress_file "$PROGRESS_FILE"
        fi
    fi
    
    if [ "$COMPLETE" = "true" ]; then
        # P0: Run verification before marking complete
        # Use || to prevent set -e from exiting when verification fails (returns 1)
        VERIFY_RESULT=0
        run_story_verification "$PROJECT_DIR" "$NEXT_STORY" || VERIFY_RESULT=$?
        if [ $VERIFY_RESULT -eq 1 ]; then
            echo "Story $STORY_ID not marked complete - verification failed"
            echo "Fix the implementation and Ralph will retry on next run"
            VERIFY_ERROR=$(echo "$VERIFY_LAST_OUTPUT" | head -n 3 | tr '\n' ' ' | cut -c1-150)
            FAILURE_TYPE_MSG=""
            if [ -n "${VERIFY_FAILURE_TYPE:-}" ]; then
                FAILURE_TYPE_MSG=" (type: ${VERIFY_FAILURE_TYPE})"
            fi
            log_session_event "VERIFY_FAIL" "Story $STORY_ID: Verification failed$FAILURE_TYPE_MSG. Command: $VERIFY_LAST_CMD. Error: $VERIFY_ERROR"

            # Detect repeated failures (stuck loops) for this story
            normalized_output=$(printf '%s' "$VERIFY_LAST_OUTPUT" | normalize_output_for_signature)
            tmp_signature=$(printf '%s\n%s\n' "$VERIFY_LAST_CMD" "$normalized_output" | compute_failure_signature)
            prev_signature="${STORY_FAILURE_SIGNATURE[$STORY_ID]}"

            current_count=${STORY_FAILURE_COUNT[$STORY_ID]:-0}

            if [ -n "$prev_signature" ] && [ "$tmp_signature" = "$prev_signature" ]; then
                current_count=$((current_count + 1))
            else
                current_count=1
                STORY_FAILURE_SIGNATURE[$STORY_ID]="$tmp_signature"
            fi
            STORY_FAILURE_COUNT[$STORY_ID]=$current_count

            if [ $current_count -gt 1 ]; then
                echo "  (stuck detection: same failure pattern seen ${current_count} times)"
            fi

            if [ $current_count -ge $STUCK_THRESHOLD ]; then
                last_logged="${STORY_STUCK_SIGNATURE[$STORY_ID]}"
                if [ "$last_logged" != "$tmp_signature" ]; then
                    record_stuck_failure "$STORY_ID" "$VERIFY_LAST_CMD" "$VERIFY_LAST_OUTPUT" "$PROGRESS_FILE" "$current_count" "${VERIFY_FAILURE_TYPE:-unknown}"
                    log_session_event "STUCK" "Story $STORY_ID: Detected stuck loop ($current_count identical failures, type: ${VERIFY_FAILURE_TYPE:-unknown}). Guidance logged to progress.txt"
                    STORY_STUCK_SIGNATURE[$STORY_ID]="$tmp_signature"
                else
                    echo "  (stuck note already recorded for this pattern)"
                fi
                STORY_FAILURE_COUNT[$STORY_ID]=0
            fi
        else
            echo "✓ Story $STORY_ID marked complete"
            log_session_event "SUCCESS" "Story $STORY_ID completed: $STORY_DESC"
            mark_story_complete "$PRD_JSON" "$STORY_ID"
            
            # Reset circuit breaker on success
            reset_circuit_breaker "$CB_FILE"
            
            # Commit if in git repo
            if git rev-parse --git-dir > /dev/null 2>&1; then
                git add .
                git commit -m "Ralph: Completed story $STORY_ID" || true
            fi

            STORY_FAILURE_COUNT[$STORY_ID]=0
            STORY_FAILURE_SIGNATURE[$STORY_ID]=""
            STORY_STUCK_SIGNATURE[$STORY_ID]=""
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
