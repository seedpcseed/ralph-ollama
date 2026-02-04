#!/bin/bash
# start-v2.sh - Ralph 2.0 Main Loop with Verification
# Enhanced data model, Cursor Agent integration, verification loop

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"

# Source libraries
source "$SCRIPT_DIR/lib/utils.sh" 2>/dev/null || true
source "$SCRIPT_DIR/lib/data-model.sh" 2>/dev/null || true
source "$SCRIPT_DIR/lib/cursor_agent.sh" 2>/dev/null || true
source "$SCRIPT_DIR/lib/circuit_breaker.sh" 2>/dev/null || true
source "$SCRIPT_DIR/config.sh" 2>/dev/null || true

# Defaults
MODE="${RALPH_MODE:-claude}"
MAX_CALLS_PER_HOUR="${MAX_CALLS_PER_HOUR:-100}"
AGENT_TIMEOUT_MINUTES="${AGENT_TIMEOUT_MINUTES:-20}"
MAX_ITERATIONS="${MAX_ITERATIONS:-0}"
COMPLETE_TOKEN="${COMPLETE_TOKEN:-<promise>COMPLETE</promise>}"
AIDER_MODEL=""

# Logging function
log() {
    local level=$1
    shift
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $*" >&2
}

# Setup model based on mode
setup_model() {
    local mode=$1
    
    case $mode in
        claude)
            if [[ -z "${ANTHROPIC_API_KEY:-}" ]]; then
                log "ERROR" "ANTHROPIC_API_KEY not set for Claude mode"
                exit 1
            fi
            AIDER_MODEL="anthropic/claude-sonnet-4-5"
            log "INFO" "Using Claude Sonnet 4.5 via API"
            ;;
        local)
            if ! curl -s http://localhost:11434/api/tags >/dev/null 2>&1; then
                log "ERROR" "Ollama not running. Start with: ollama serve"
                exit 1
            fi
            local start_model="${LOCAL_START_MODEL:-${LOCAL_MODEL:-deepseek-coder:33b}}"
            AIDER_MODEL="ollama/$start_model"
            log "INFO" "Using local model: $start_model"
            ;;
        hybrid)
            AIDER_MODEL="hybrid"
            log "INFO" "Using hybrid mode: Claude for priority 1-5, local for others"
            ;;
        *)
            log "ERROR" "Unknown mode '$mode'. Use: claude, local, or hybrid"
            exit 1
            ;;
    esac
}

# Check dependencies
check_dependencies() {
    local missing=()
    
    if ! command -v jq >/dev/null 2>&1; then
        missing+=("jq")
    fi
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        log "ERROR" "Missing dependencies: ${missing[*]}"
        return 1
    fi
    
    return 0
}

# Select model for story (hybrid mode)
select_model_for_story() {
    local story_priority=$1
    local story_category=$2
    
    if [[ "$MODE" != "hybrid" ]]; then
        echo "$AIDER_MODEL"
        return
    fi
    
    # Use Claude for critical/complex tasks
    if [[ "$story_priority" -le 3 ]] || [[ "$story_category" == "architecture" ]]; then
        echo "anthropic/claude-sonnet-4-5"
    else
        local start_model="${LOCAL_START_MODEL:-${LOCAL_MODEL:-deepseek-coder:33b}}"
        echo "ollama/$start_model"
    fi
}

# Generate prompt for story implementation
generate_prompt_v2() {
    local project_dir=$1
    local story_json=$2
    
    local story_id
    story_id=$(echo "$story_json" | jq -r '.id')
    local story_desc
    story_desc=$(echo "$story_json" | jq -r '.story')
    local story_steps
    story_steps=$(echo "$story_json" | jq -r '.steps[]' | sed 's/^/- /')
    local story_acceptance
    story_acceptance=$(echo "$story_json" | jq -r '.acceptance')
    local verify_cmd
    verify_cmd=$(echo "$story_json" | jq -r '.verify.command // ""')
    
    # Read progress.json for learnings
    local learnings=""
    if [[ -f "$project_dir/progress.json" ]]; then
        learnings=$(jq -r ".stories[\"$story_id\"].learnings[]?" "$project_dir/progress.json" 2>/dev/null | head -5 || echo "")
    fi
    
    # Read file-mapping.json for context
    local relevant_files=""
    if [[ -f "$project_dir/file-mapping.json" ]]; then
        relevant_files=$(jq -r ".storyFiles[\"$story_id\"] // [] | .[]" "$project_dir/file-mapping.json" 2>/dev/null | head -10 || echo "")
    fi
    
    cat << PROMPTEOF
# Implement Story $story_id

## Story
$story_desc

## Steps
$story_steps

## Acceptance Criteria
$story_acceptance

## Verification
${verify_cmd:+Run: $verify_cmd}

## Context
${learnings:+### Previous Learnings
$learnings
}

${relevant_files:+### Relevant Files
$(echo "$relevant_files" | sed 's/^/- /')
}

## Instructions
1. Implement the story completely
2. Ensure code compiles without errors
3. Run verification command: ${verify_cmd:-"N/A"}
4. If verification fails, fix errors and retry
5. Only mark complete when verification passes

Use Cursor Agent's (or Aider's) edit format for file changes.
PROMPTEOF
}

# Verify story (compilation + tests + story-specific verification)
verify_story() {
    local project_dir=$1
    local story_json=$2
    
    local verify_cmd
    verify_cmd=$(echo "$story_json" | jq -r '.verify.command // ""')
    local project_type
    project_type=$(detect_project_type "$project_dir")
    
    # 1. Compile check
    log "INFO" "Compiling project..."
    if ! compile_project "$project_dir" "$project_type"; then
        return 1
    fi
    
    # 2. Test execution (if tests exist)
    if has_tests "$project_dir" "$project_type"; then
        log "INFO" "Running tests..."
        if ! run_tests "$project_dir" "$project_type"; then
            return 1
        fi
    fi
    
    # 3. Story-specific verification
    if [[ -n "$verify_cmd" ]]; then
        log "INFO" "Running story verification: $verify_cmd"
        if ! run_verification_command "$project_dir" "$verify_cmd"; then
            return 1
        fi
    fi
    
    return 0
}

# Detect project type (Rust, Python, Node, Go, etc.)
detect_project_type() {
    local project_dir=$1
    
    if [[ -f "$project_dir/Cargo.toml" ]]; then
        echo "rust"
    elif [[ -f "$project_dir/package.json" ]]; then
        echo "node"
    elif [[ -f "$project_dir/pyproject.toml" ]] || [[ -f "$project_dir/setup.py" ]]; then
        echo "python"
    elif [[ -f "$project_dir/go.mod" ]]; then
        echo "go"
    else
        echo "unknown"
    fi
}

# Compile project (language-aware)
compile_project() {
    local project_dir=$1
    local project_type=$2
    
    cd "$project_dir"
    
    case $project_type in
        rust)
            cargo build --lib 2>&1
            return $?
            ;;
        node)
            npm run build 2>&1 || true
            return 0  # Node projects may not have build step
            ;;
        python)
            python -m py_compile *.py 2>&1 || true
            return 0  # Python doesn't always need compilation
            ;;
        go)
            go build ./... 2>&1
            return $?
            ;;
        *)
            log "WARN" "Unknown project type: $project_type"
            return 0  # Don't fail on unknown types
            ;;
    esac
}

# Check if project has tests
has_tests() {
    local project_dir=$1
    local project_type=$2
    
    case $project_type in
        rust)
            [[ -d "$project_dir/tests" ]] || find "$project_dir/src" -name "*test*.rs" -o -name "*_test.rs" | grep -q . || return 1
            ;;
        node)
            [[ -f "$project_dir/package.json" ]] && grep -q '"test"' "$project_dir/package.json" || return 1
            ;;
        python)
            [[ -d "$project_dir/tests" ]] || find "$project_dir" -name "test_*.py" | grep -q . || return 1
            ;;
        go)
            find "$project_dir" -name "*_test.go" | grep -q . || return 1
            ;;
    esac
}

# Run tests (language-aware)
run_tests() {
    local project_dir=$1
    local project_type=$2
    
    cd "$project_dir"
    
    case $project_type in
        rust)
            cargo test --lib 2>&1
            return $?
            ;;
        node)
            npm test 2>&1
            return $?
            ;;
        python)
            pytest tests/ 2>&1 || python -m unittest discover 2>&1
            return $?
            ;;
        go)
            go test ./... 2>&1
            return $?
            ;;
        *)
            return 0
            ;;
    esac
}

# Run story-specific verification command
run_verification_command() {
    local project_dir=$1
    local command=$2
    
    cd "$project_dir"
    eval "$command" >/dev/null 2>&1
    return $?
}

# Record attempt in progress.json
record_attempt() {
    local project_dir=$1
    local story_id=$2
    local action=$3  # implement, fix, verify
    local model=$4
    local files_modified=("${@:5}")
    local verification_result=$5  # pass, fail
    local compilation_result=$6  # pass, fail
    local test_result=$7  # pass, fail, not_run
    
    local progress_file="$project_dir/progress.json"
    
    # Ensure progress.json exists
    if [[ ! -f "$progress_file" ]]; then
        local project_name
        project_name=$(basename "$project_dir")
        jq -n "{
            version: \"2.0\",
            projectName: \"$project_name\",
            sessionId: \"$(date +%Y%m%d_%H%M%S)\",
            stories: {},
            sessionStats: {
                totalStories: 0,
                completedStories: 0,
                inProgressStories: 0,
                failedStories: 0,
                blockedStories: 0,
                totalAttempts: 0,
                totalDuration: 0,
                claudeApiCalls: 0,
                localModelCalls: 0
            }
        }" > "$progress_file"
    fi
    
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local tmp_file
    tmp_file=$(mktemp)
    
    jq --arg id "$story_id" \
       --arg action "$action" \
       --arg model "$model" \
       --arg ts "$timestamp" \
       --arg verify_result "$verification_result" \
       --arg compile_result "$compilation_result" \
       --arg test_result "$test_result" '
        if .stories[$id] then
            .stories[$id].attempts += [{
                timestamp: $ts,
                action: $action,
                model: $model,
                filesModified: [],
                verification: {result: $verify_result},
                compilation: {result: $compile_result},
                tests: {result: $test_result}
            }] |
            .stories[$id].totalAttempts += 1 |
            .stories[$id].lastAttempt = $ts
        else
            .stories[$id] = {
                attempts: [{
                    timestamp: $ts,
                    action: $action,
                    model: $model,
                    filesModified: [],
                    verification: {result: $verify_result},
                    compilation: {result: $compile_result},
                    tests: {result: $test_result}
                }],
                learnings: [],
                totalAttempts: 1,
                totalDuration: 0,
                firstAttempt: $ts,
                lastAttempt: $ts
            }
        end |
        .sessionStats.totalAttempts += 1 |
        if $model | startswith("anthropic/") then
            .sessionStats.claudeApiCalls += 1
        else
            .sessionStats.localModelCalls += 1
        end
    ' "$progress_file" > "$tmp_file" && mv "$tmp_file" "$progress_file"
}

# Main loop function
main_loop() {
    local project_name=$1
    local project_dir="$SCRIPT_DIR/projects/$project_name"
    
    # Ensure logs directory exists
    mkdir -p "$project_dir/logs"
    export LOG_FILE="$project_dir/logs/ralph-v2_$(date '+%Y%m%d').log"
    
    log "SUCCESS" "🚀 Ralph 2.0 starting for project: $project_name"
    log "INFO" "Max calls/hour: $MAX_CALLS_PER_HOUR | Timeout: ${AGENT_TIMEOUT_MINUTES}m"
    if [[ $MAX_ITERATIONS -gt 0 ]]; then
        log "INFO" "Max iterations: $MAX_ITERATIONS"
    else
        log "INFO" "Max iterations: unlimited"
    fi
    log "INFO" "Complete token: $COMPLETE_TOKEN"
    
    # Validate prd.json exists and is v2.0
    if [[ ! -f "$project_dir/prd.json" ]]; then
        log "ERROR" "prd.json not found. Run convert-v2.sh first."
        exit 1
    fi
    
    local version
    version=$(jq -r '.version // "1.0"' "$project_dir/prd.json" 2>/dev/null || echo "1.0")
    if [[ "$version" != "2.0" ]]; then
        log "WARN" "prd.json is not v2.0 format. Run migrate-v1-to-v2.sh first."
        log "INFO" "Attempting to migrate automatically..."
        "$SCRIPT_DIR/migrate-v1-to-v2.sh" "$project_name" 2>/dev/null || {
            log "ERROR" "Migration failed. Please run migrate-v1-to-v2.sh manually."
            exit 1
        }
    fi
    
    # Initialize progress.json, verification-results.json, file-mapping.json if missing
    if [[ ! -f "$project_dir/progress.json" ]]; then
        local project_name_basename
        project_name_basename=$(basename "$project_dir")
        jq -n "{
            version: \"2.0\",
            projectName: \"$project_name_basename\",
            sessionId: \"$(date +%Y%m%d_%H%M%S)\",
            stories: {},
            sessionStats: {
                totalStories: 0,
                completedStories: 0,
                inProgressStories: 0,
                failedStories: 0,
                blockedStories: 0,
                totalAttempts: 0,
                totalDuration: 0,
                claudeApiCalls: 0,
                localModelCalls: 0
            }
        }" > "$project_dir/progress.json"
    fi
    
    if [[ ! -f "$project_dir/verification-results.json" ]]; then
        local project_name_basename
        project_name_basename=$(basename "$project_dir")
        jq -n "{
            version: \"2.0\",
            projectName: \"$project_name_basename\",
            verifications: {}
        }" > "$project_dir/verification-results.json"
    fi
    
    if [[ ! -f "$project_dir/file-mapping.json" ]]; then
        local project_name_basename
        project_name_basename=$(basename "$project_dir")
        jq -n "{
            version: \"2.0\",
            projectName: \"$project_name_basename\",
            files: {},
            storyFiles: {}
        }" > "$project_dir/file-mapping.json"
    fi
    
    # Show initial status
    local total
    total=$(count_total_stories_v2 "$project_dir/prd.json")
    local complete
    complete=$(count_complete_stories_v2 "$project_dir/prd.json")
    log "INFO" "Stories: $complete/$total complete"
    
    # Initialize circuit breaker
    init_circuit_breaker "$project_dir" 2>/dev/null || true
    
    local loop_count=0
    local max_attempts=5  # Max attempts per story before giving up
    
    # Main loop
    while true; do
        loop_count=$((loop_count + 1))
        
        # Check max iterations
        if [[ $MAX_ITERATIONS -gt 0 ]] && [[ $loop_count -gt $MAX_ITERATIONS ]]; then
            log "INFO" "Reached max iterations ($MAX_ITERATIONS)"
            break
        fi
        
        # Check circuit breaker
        if should_halt_execution "$project_dir" 2>/dev/null; then
            log "ERROR" "Circuit breaker is open. Too many failures."
            log "INFO" "Reset with: ./start-v2.sh $project_name --reset"
            exit 1
        fi
        
        log "LOOP" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        log "LOOP" "Loop #$loop_count"
        log "LOOP" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        
        # Get next story (with dependency checking)
        local story_json
        story_json=$(get_next_story_v2 "$project_dir/prd.json" 2>/dev/null || echo "")
        
        if [[ -z "$story_json" || "$story_json" == "null" ]]; then
            log "SUCCESS" "🎉 All stories completed!"
            break
        fi
        
        local story_id
        story_id=$(echo "$story_json" | jq -r '.id')
        local story_priority
        story_priority=$(echo "$story_json" | jq -r '.priority // 999')
        local story_category
        story_category=$(echo "$story_json" | jq -r '.category // "technical"')
        
        log "INFO" "Working on story: $story_id (priority: $story_priority, category: $story_category)"
        
        # Update story status to in_progress
        update_story_status "$project_dir/prd.json" "$story_id" "in_progress"
        
        # Select model for this story
        local current_model
        current_model=$(select_model_for_story "$story_priority" "$story_category")
        log "INFO" "Using model: $current_model"
        
        # Generate prompt
        local prompt_file="$project_dir/.ralph_current_prompt.md"
        generate_prompt_v2 "$project_dir" "$story_json" > "$prompt_file"
        
        local timestamp
        timestamp=$(date '+%Y-%m-%d_%H-%M-%S')
        local output_file="$project_dir/logs/loop-v2_${timestamp}_story_${story_id}.log"
        
        # Invoke agent (Cursor Agent or Aider fallback)
        log "INFO" "Invoking agent..."
        local agent_success=false
        local files_modified=0
        
        if invoke_cursor_agent_file "$prompt_file" 2>&1 | tee "$output_file"; then
            agent_success=true
            # Count modified files (simplified - would need to parse agent output)
            files_modified=$(git -C "$project_dir" diff --name-only 2>/dev/null | wc -l || echo "0")
        else
            # Fallback to Aider
            log "WARN" "Cursor Agent failed, trying Aider..."
            local aider_cmd=(
                aider
                --model "$current_model"
                --yes
                --no-stream
                --no-show-model-warnings
                --message-file "$prompt_file"
            )
            
            if [[ "${AIDER_AUTO_COMMITS:-false}" == "true" ]]; then
                aider_cmd+=(--auto-commits)
            fi
            
            if "${aider_cmd[@]}" 2>&1 | tee "$output_file"; then
                agent_success=true
                files_modified=$(git -C "$project_dir" diff --name-only 2>/dev/null | wc -l || echo "0")
            fi
        fi
        
        rm -f "$prompt_file"
        
        if [[ "$agent_success" != "true" ]]; then
            log "ERROR" "Agent execution failed"
            update_story_status "$project_dir/prd.json" "$story_id" "failed"
            record_loop_result "$project_dir" "$loop_count" 0 true 0 "Agent execution failed" 2>/dev/null || true
            continue
        fi
        
        # Verification loop (up to max_attempts)
        local attempt=0
        local verification_passed=false
        
        while [[ $attempt -lt $max_attempts ]]; do
            attempt=$((attempt + 1))
            
            log "INFO" "Verification attempt $attempt/$max_attempts"
            
            # Run verification
            local compile_result="pass"
            local test_result="not_run"
            local verify_result="pass"
            
            if verify_story "$project_dir" "$story_json"; then
                verification_passed=true
                log "SUCCESS" "✅ Verification passed!"
                break
            else
                log "WARN" "Verification failed, attempt $attempt/$max_attempts"
                
                # Get errors for feedback
                local errors=""
                case $(detect_project_type "$project_dir") in
                    rust)
                        errors=$(cargo build --lib 2>&1 | grep -i error | head -5 || echo "")
                        ;;
                esac
                
                # If not last attempt, try to fix
                if [[ $attempt -lt $max_attempts ]]; then
                    log "INFO" "Attempting to fix errors..."
                    # Generate fix prompt with errors
                    local fix_prompt="$project_dir/.ralph_fix_prompt.md"
                    cat > "$fix_prompt" << EOF
# Fix Errors for Story $story_id

## Errors
$errors

## Story
$(echo "$story_json" | jq -r '.story')

Fix the errors and ensure verification passes.
EOF
                    
                    # Invoke agent to fix
                    if invoke_cursor_agent_file "$fix_prompt" 2>&1 | tee -a "$output_file"; then
                        log "INFO" "Fix attempt completed"
                    fi
                    rm -f "$fix_prompt"
                fi
            fi
            
            # Record attempt
            record_attempt "$project_dir" "$story_id" "fix" "$current_model" "$compile_result" "$test_result" "$verify_result"
        done
        
        # Mark story complete if verification passed
        if [[ "$verification_passed" == "true" ]] && [[ "$files_modified" -gt 0 ]]; then
            mark_story_complete_v2 "$project_dir/prd.json" "$story_id"
            log "SUCCESS" "📝 Story $story_id marked as complete"
            
            # Update progress.json
            local complete_count
            complete_count=$(count_complete_stories_v2 "$project_dir/prd.json")
            local total_count
            total_count=$(count_total_stories_v2 "$project_dir/prd.json")
            log "INFO" "Progress: $complete_count/$total_count stories complete"
        else
            log "WARN" "Story $story_id: verification failed or no file changes"
            update_story_status "$project_dir/prd.json" "$story_id" "failed"
        fi
        
        # Record loop result for circuit breaker
        record_loop_result "$project_dir" "$loop_count" "$files_modified" false 0 "" 2>/dev/null || true
        
        echo ""
    done
    
    log "SUCCESS" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log "SUCCESS" "Ralph 2.0 loop complete!"
    log "SUCCESS" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

show_help() {
    cat << EOF
Ralph 2.0 Start - Autonomous development loop with verification

Usage: $0 <project-name> [OPTIONS]

Arguments:
    project-name    Name of the Ralph project

Options:
    --model MODE    Model mode: claude, local, or hybrid (default: $MODE)
    --reset         Reset circuit breaker
    --status        Show project status
    -h, --help      Show this help

Examples:
    $0 editio
    $0 editio --model local
    $0 editio --model hybrid
    $0 editio --status
    $0 editio --reset
EOF
}

# Parse arguments
PROJECT_NAME=""
ACTION="run"

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        --model)
            MODE="$2"
            shift 2
            ;;
        --reset)
            ACTION="reset"
            shift
            ;;
        --status)
            ACTION="status"
            shift
            ;;
        *)
            if [[ -z "$PROJECT_NAME" ]]; then
                PROJECT_NAME="$1"
            fi
            shift
            ;;
    esac
done

# Validate project name
if [[ -z "$PROJECT_NAME" ]]; then
    log "ERROR" "Project name is required"
    show_help
    exit 1
fi

PROJECT_DIR="$SCRIPT_DIR/projects/$PROJECT_NAME"

# Check if project exists
if [[ ! -d "$PROJECT_DIR" ]]; then
    log "ERROR" "Project '$PROJECT_NAME' does not exist"
    exit 1
fi

# Execute action
case "$ACTION" in
    "run")
        # Setup model and check dependencies only for run action
        setup_model "$MODE"
        check_dependencies || exit 1
        main_loop "$PROJECT_NAME"
        ;;
    "status")
        if [[ -f "$PROJECT_DIR/prd.json" ]]; then
            local total
            total=$(count_total_stories_v2 "$PROJECT_DIR/prd.json" 2>/dev/null || echo "0")
            local complete
            complete=$(count_complete_stories_v2 "$PROJECT_DIR/prd.json" 2>/dev/null || echo "0")
            echo "Project: $PROJECT_NAME"
            echo "Stories: $complete/$total complete"
            echo ""
            echo "Incomplete stories:"
            jq -r '.userStories[] | select(.status != "complete") | "  [\(.id)] \(.story)"' "$PROJECT_DIR/prd.json" 2>/dev/null | head -10
        else
            log "ERROR" "prd.json not found"
        fi
        ;;
    "reset")
        reset_circuit_breaker "$PROJECT_DIR" 2>/dev/null || log "INFO" "Circuit breaker reset"
        ;;
    *)
        log "ERROR" "Unknown action: $ACTION"
        exit 1
        ;;
esac
