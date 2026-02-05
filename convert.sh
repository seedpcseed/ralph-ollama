#!/bin/bash
# convert-v2.sh - Convert PRD.md to v2.0 prd.json and requirements.md using Cursor Agent
# Ralph 2.0 - Enhanced data model with Cursor Agent + MCP integration

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"

# Source libraries (optional - convert-v2.sh is self-contained)
source "$SCRIPT_DIR/lib/cursor_agent.sh" 2>/dev/null || true
source "$SCRIPT_DIR/lib/claude_cli.sh" 2>/dev/null || true
source "$SCRIPT_DIR/config.sh" 2>/dev/null || true

# Load config defaults if config.sh doesn't exist
LOCAL_MODEL="${LOCAL_MODEL:-deepseek-coder:33b}"
LOCAL_CONVERT_MODEL="${LOCAL_CONVERT_MODEL:-${LOCAL_MODEL}}"
AIDER_AUTO_COMMITS="${AIDER_AUTO_COMMITS:-false}"

# Default mode
MODE="${RALPH_MODE:-claude}"
AIDER_MODEL=""

# Logging function
log() {
    local level=$1
    shift
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $*" >&2
}

# Spinner functions (from convert.sh)
SPINNER_CHARS='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
SPINNER_PID=""

start_spinner() {
    local phase_desc="${1:-Processing...}"
    if [[ -n "$SPINNER_PID" ]] && kill -0 "$SPINNER_PID" 2>/dev/null; then
        return
    fi
    
    (
        local i=0
        while true; do
            printf "\r%s %s" "${SPINNER_CHARS:$((i % ${#SPINNER_CHARS})):1}" "$phase_desc" >&2
            sleep 0.1
            i=$((i + 1))
        done
    ) &
    SPINNER_PID=$!
}

stop_spinner() {
    if [[ -n "$SPINNER_PID" ]]; then
        kill "$SPINNER_PID" 2>/dev/null || true
        SPINNER_PID=""
        printf "\r\033[K" >&2  # Clear spinner line
    fi
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
            local convert_model="${LOCAL_CONVERT_MODEL:-${LOCAL_MODEL:-deepseek-coder:33b}}"
            AIDER_MODEL="ollama/$convert_model"
            log "INFO" "Using local model: $convert_model (will use Aider, not Cursor Agent)"
            log "WARN" "Local models may struggle to generate 50-150+ stories in one response"
            log "WARN" "Consider using --model claude for better conversion quality"
            log "WARN" "You can use local models for implementation (start-v2.sh) after conversion"
            
            # Check if model is available
            if ! ollama list 2>/dev/null | grep -q "$convert_model"; then
                log "WARN" "Model '$convert_model' is not available locally"
                log "INFO" "Pulling model (this may take several minutes)..."
                if ollama pull "$convert_model" 2>&1; then
                    log "SUCCESS" "Model '$convert_model' pulled successfully"
                else
                    log "ERROR" "Failed to pull model '$convert_model'"
                    log "INFO" "Try manually: ollama pull $convert_model"
                    exit 1
                fi
            else
                log "INFO" "Model '$convert_model' is available"
            fi
            ;;
        hybrid)
            AIDER_MODEL="hybrid"
            log "INFO" "Using hybrid mode: Claude for conversion (better quality)"
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
        log "INFO" "Install with: sudo apt install jq  # or brew install jq"
        return 1
    fi
    
    return 0
}

# Create conversion prompt for v2.0 format (compact for small context windows)
create_conversion_prompt_v2() {
    local project_name=$1
    local project_dir=$2

    cat << 'PROMPTEOF' | sed "s|\$project_name|$project_name|g"
# PRD → prd.json (v2.0) – compact

## Task
1. Read projects/$project_name/prd.md (in chat); understand ALL requirements.
2. Edit projects/$project_name/prd.json: replace entire file with one JSON: "version":"2.0", "branchName":"ralph/$project_name", "createdAt", "updatedAt", "userStories":[ ... ].
3. Edit projects/$project_name/requirements.md: replace with technical specs from PRD.

## Story rules
- Granular: each P0 feature → 5–15 stories (not 1–3). One concept per story; 1–2 iterations each.
- Order: dependency order (infra → core → features).
- Verify: every story has verifiable command in "acceptance" or "verify.command".

## Per-story fields (v2.0, all required)
id, category, story, steps, acceptance, priority, status "pending", progress 0, lastAttempt null, attemptCount 0, dependsOn, blocks, verify{command, lastRun, lastResult "not_run", expectedResult "pass"}, files, tests, errors, notes "", createdAt, updatedAt.

## Output
Full prd.json with ALL stories (no "..."). Break each PRD feature into many small stories; 50–150+ for a complex PRD. Use Aider whole-file format: path on one line, then ```, then full file contents, then ```. Edit projects/$project_name/prd.json and projects/$project_name/requirements.md now.
PROMPTEOF
}

# Create verification prompt for v2.0
create_verification_prompt_v2() {
    local project_dir=$1
    cat << PROMPTEOF
# PRD to JSON Verification (v2.0 Format)

You are verifying that a generated prd.json comprehensively covers all requirements from the original PRD.

## Files to work with:
- READ: $project_dir/prd.md (the original PRD - source of truth)
- READ & EDIT: $project_dir/prd.json (the generated user stories in v2.0 format)
- READ & EDIT: $project_dir/requirements.md (the generated technical specs)

## Instructions:

### 1. Carefully read the original PRD.md and understand ALL requirements, features, and details.

### 2. Read the generated prd.json and requirements.md.

### 3. Compare and verify:
- Does prd.json cover ALL features mentioned in the PRD? (Check every P0 feature!)
- Are stories granular enough? (Each should be 1-2 iterations, not require multiple passes)
  - **CRITICAL**: Each P0 feature should be broken into 5-15 stories, not 1-3!
  - If a story says "Implement X" where X is a major feature, it needs to be split further
  - If a story has 5+ steps, it's too broad - break it down
- Do stories have verifiable acceptance criteria? (RUN commands, verify fields, or file checks)
- Are there any edge cases, error handling, or UX details in the PRD that are missing from the stories?
- Does requirements.md capture all technical specifications from the PRD?
- **Story count check**: For a PRD with 10+ P0 features, you should have 50-150+ stories. If you have fewer than 30, you're not granular enough!
- **v2.0 format check**: All stories must have status, progress, dependsOn, blocks, verify object, files, tests, errors arrays

### 4. If anything is missing or incomplete:
- ADD new user stories to cover missing features (break down large ones into smaller, verifiable tasks)
- SPLIT stories that are too broad (if a story has 5+ steps or multiple components, break it down)
- UPDATE existing stories if their scope is incomplete or lacks verification
- ADD verify objects or RUN commands to stories that don't have them
- UPDATE requirements.md if technical details are missing
- Ensure all additions follow v2.0 format and guidelines (granular, verifiable, 1-2 iterations each).
PROMPTEOF
}

# Create requirements fill prompt
create_requirements_fill_prompt() {
    local project_name=$1
    cat << 'PROMPTEOF' | sed "s|\$project_name|$project_name|g"
You are running inside Cursor Agent. The files prd.md and requirements.md are in this chat. You MUST edit requirements.md.

TASK: Replace the contents of projects/$project_name/requirements.md with technical specifications extracted from the PRD. Include: architecture, data models, APIs, UI/UX constraints, performance and security requirements, tech stack, and any other technical details from the PRD. Write in clear markdown sections.

Use the edit format: on one line the path projects/$project_name/requirements.md, then a line with \`\`\`, then the full file content, then \`\`\`. Apply the edit now.
PROMPTEOF
}

# Check if requirements.md is placeholder
is_requirements_placeholder() {
    local req_file=$1
    [[ ! -f "$req_file" ]] && return 0
    local lines
    lines=$(wc -l < "$req_file" 2>/dev/null || echo "0")
    [[ "${lines:-0}" -gt 3 ]] && return 1
    grep -q "^# Technical requirements" "$req_file" 2>/dev/null && \
        ! grep -v "^#" "$req_file" 2>/dev/null | grep -q . && return 0
    return 1
}

# Invoke agent: use Aider for conversion (it edits files; Cursor Agent does not)
invoke_agent() {
    local prompt_file=$1
    local output_file=$2
    local model=$3
    shift 3
    local files=("$@")
    
    # Use Aider for both local (ollama) and API (anthropic) models.
    # Cursor Agent does not edit files - it suggests scripts or instructions.
    # Aider actually writes prd.json and requirements.md, so we always use it for conversion.
    if [[ "$model" == ollama/* ]] || [[ "$model" == anthropic/* ]] || [[ "$model" == "hybrid" ]]; then
        log "INFO" "Using Aider for conversion: $model"
        log "INFO" "Note: v2.0 verification loop will catch and fix any issues"

        # Check if Aider is available
        if ! command -v aider >/dev/null 2>&1; then
            log "ERROR" "Aider not available. Install with: pip install aider-chat"
            return 1
        fi
        
        # Use timeout to prevent hanging (default 20 minutes from config.sh)
        local timeout_minutes="${AGENT_TIMEOUT_MINUTES:-20}"
        local timeout_seconds=$((timeout_minutes * 60))

        # Build Aider command (--timeout so Ollama/litellm allows >600s; default is 10 min)
        local aider_cmd=(
            aider
            "${files[@]}"
            --model "$model"
            --yes
            --no-stream
            --no-show-model-warnings
            --message-file "$prompt_file"
            --timeout "$timeout_seconds"
        )
        
        if [[ "${AIDER_AUTO_COMMITS:-false}" == "true" ]]; then
            aider_cmd+=(--auto-commits)
        fi

        # LiteLLM (used by Aider for Ollama) defaults to 600s; ensure it allows our timeout
        export LITELLM_REQUEST_TIMEOUT="${LITELLM_REQUEST_TIMEOUT:-$timeout_seconds}"
        log "INFO" "Aider/Ollama timeout: ${timeout_seconds}s (LITELLM_REQUEST_TIMEOUT=${LITELLM_REQUEST_TIMEOUT})"
        
        # Check for timeout command
        local timeout_cmd=""
        if command -v timeout >/dev/null 2>&1; then
            timeout_cmd="timeout"
        elif command -v gtimeout >/dev/null 2>&1; then
            timeout_cmd="gtimeout"
        fi
        
        # Run Aider with timeout if available
        if [[ -n "$timeout_cmd" ]]; then
            log "INFO" "Running Aider with ${timeout_minutes} minute timeout..."
            if $timeout_cmd ${timeout_seconds}s "${aider_cmd[@]}" > "$output_file" 2>&1; then
                return 0
            else
                local exit_code=$?
                if [[ $exit_code -eq 124 ]]; then
                    log "WARN" "Aider timed out after ${timeout_minutes} minutes"
                    log "INFO" "Checking if prd.json was written before timeout..."
                    # Check if prd.json exists and has content
                    if [[ -f "${files[0]}" ]] && jq -e '.userStories | length > 0' "${files[0]}" >/dev/null 2>&1; then
                        log "SUCCESS" "prd.json was written before timeout - extraction may recover it"
                        return 0  # Consider it success if file was written
                    fi
                fi
                log "ERROR" "Aider execution failed (exit code: $exit_code). Check log: $output_file"
                return 1
            fi
        else
            # No timeout command available - warn user
            log "WARN" "No timeout command available - Aider may hang indefinitely"
            log "WARN" "Install timeout: sudo apt install coreutils (Linux) or brew install coreutils (macOS)"
            if "${aider_cmd[@]}" > "$output_file" 2>&1; then
                return 0
            else
                log "ERROR" "Aider execution failed. Check log: $output_file"
                return 1
            fi
        fi
    fi

    # Fallback: Cursor Agent (not used for convert - it does not edit files, only suggests scripts)
    log "WARN" "Unexpected model '$model'; using Cursor Agent (may not write files)"
    
    # Check if Cursor Agent is available
    if ! check_cursor_agent 2>/dev/null; then
        log "ERROR" "Cursor Agent not available. Install from: curl https://cursor.com/install -fsS | bash"
        log "ERROR" "Or ensure 'agent' command is in PATH"
        return 1
    fi
    
    # Invoke Cursor Agent
    local agent_output
    agent_output=$(invoke_cursor_agent_file "$prompt_file" "${files[@]}" 2>&1)
    local agent_exit_code=$?
    
    # Write output to log file
    echo "$agent_output" > "$output_file"
    
    # Check for API usage limit
    if echo "$agent_output" | grep -qi "usage limit\|hit your usage limit"; then
        log "ERROR" "Cursor Agent API usage limit reached"
        log "ERROR" "Your usage limits will reset when your monthly cycle ends"
        log "ERROR" "Consider: 1) Waiting for limit reset, 2) Using a different API key, 3) Setting a Spend Limit"
        return 1
    fi
    
    if [[ $agent_exit_code -eq 0 ]]; then
        return 0
    else
        log "ERROR" "Cursor Agent execution failed (exit code: $agent_exit_code)"
        log "ERROR" "Check log: $output_file"
        return 1
    fi
}

# Normalize prd.json v2.0 format
normalize_prd_json_v2() {
    local json_file=$1
    
    if ! jq -e '.userStories | length > 0' "$json_file" >/dev/null 2>&1; then
        return 1
    fi
    
    # Normalize: pretty-print and ensure v2.0 format compliance
    local normalized
    normalized=$(jq '{
        version: "2.0",
        branchName: .branchName,
        createdAt: (.createdAt // (now | strftime("%Y-%m-%dT%H:%M:%SZ"))),
        updatedAt: (now | strftime("%Y-%m-%dT%H:%M:%SZ")),
        userStories: [.userStories[] | {
            id,
            category,
            story,
            steps,
            acceptance,
            priority,
            status: (.status // "pending"),
            progress: (.progress // 0),
            lastAttempt: (.lastAttempt // null),
            attemptCount: (.attemptCount // 0),
            dependsOn: (.dependsOn // []),
            blocks: (.blocks // []),
            verify: (if (.verify | type) == "string" then {
                command: .verify,
                lastRun: null,
                lastResult: "not_run",
                expectedResult: "pass"
            } else (.verify // {
                command: "",
                lastRun: null,
                lastResult: "not_run",
                expectedResult: "pass"
            }) end),
            files: (.files // []),
            tests: (.tests // []),
            errors: (.errors // []),
            notes: (.notes // ""),
            createdAt: (.createdAt // (now | strftime("%Y-%m-%dT%H:%M:%SZ"))),
            updatedAt: (now | strftime("%Y-%m-%dT%H:%M:%SZ"))
        }]
    }' "$json_file" 2>/dev/null)
    
    if [[ -n "$normalized" ]]; then
        echo "$normalized" | jq '.' > "${json_file}.tmp" && mv "${json_file}.tmp" "$json_file"
        return 0
    fi
    
    return 1
}

# Main conversion function
main() {
    local project_name="$1"
    
    # Validate arguments
    if [[ -z "$project_name" ]]; then
        log "ERROR" "Project name is required"
        show_help
        exit 1
    fi
    
    local project_dir="$SCRIPT_DIR/projects/$project_name"
    local prd_file="$project_dir/prd.md"
    local json_file="$project_dir/prd.json"
    local req_file="$project_dir/requirements.md"
    
    # Check if project exists
    if [[ ! -d "$project_dir" ]]; then
        log "ERROR" "Project '$project_name' does not exist"
        log "INFO" "Create it first with: ./new.sh $project_name"
        exit 1
    fi
    
    # Check if PRD exists
    if [[ ! -f "$prd_file" ]]; then
        log "ERROR" "PRD file not found: $prd_file"
        exit 1
    fi
    
    # Check if prd.json already has stories
    if [[ -f "$json_file" ]]; then
        local existing_count
        existing_count=$(jq '.userStories | length' "$json_file" 2>/dev/null || echo "0")
        if [[ "$existing_count" -gt 0 ]]; then
            log "WARN" "prd.json already has $existing_count stories"
            echo -n "Overwrite? [y/N] "
            read -r response
            if [[ ! "$response" =~ ^[Yy]$ ]]; then
                log "INFO" "Cancelled"
                exit 0
            fi
        fi
    fi
    
    # Ensure prd.json and requirements.md exist with valid content
    if [[ ! -s "$json_file" ]] || ! jq -e '.userStories | type == "array"' "$json_file" 2>/dev/null; then
        local now_iso
        now_iso=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
        jq -n "{
            version: \"2.0\",
            branchName: \"ralph/$project_name\",
            createdAt: \"$now_iso\",
            updatedAt: \"$now_iso\",
            userStories: []
        }" > "$json_file"
    fi
    if [[ ! -s "$req_file" ]]; then
        echo "# Technical requirements (generated from PRD)" > "$req_file"
    fi
    
    log "INFO" "Converting PRD to tasks for project: $project_name"
    log "INFO" "Agent will edit prd.json and requirements.md directly..."
    log "INFO" "Using model: $AIDER_MODEL"
    
    # Clean up Git state
    cd "$REPO_ROOT"
    local deleted_files
    deleted_files=$(git ls-files --deleted "projects/$project_name/" 2>/dev/null || true)
    local staged_deletions
    staged_deletions=$(git diff --cached --name-only --diff-filter=D "projects/$project_name/" 2>/dev/null || true)
    
    if [[ -n "$deleted_files" ]]; then
        log "INFO" "Staging deletions for files removed from filesystem..."
        echo "$deleted_files" | while IFS= read -r file; do
            if [[ -n "$file" ]]; then
                git rm "$file" >/dev/null 2>&1 || true
            fi
        done
    fi
    
    if [[ -n "$staged_deletions" ]] || [[ -n "$deleted_files" ]]; then
        log "INFO" "Committing file deletions to clean up Git state..."
        git commit -m "chore($project_name): remove deleted files from Git tracking" >/dev/null 2>&1 || true
    fi
    
    # Create log directory
    local timestamp=$(date '+%Y-%m-%d_%H-%M-%S')
    mkdir -p "$project_dir/logs"
    
    # ═══════════════════════════════════════════════════════════════════════════
    # PHASE 1: Initial Conversion
    # ═══════════════════════════════════════════════════════════════════════════
    echo ""
    log "INFO" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log "INFO" "PHASE 1: Converting PRD to tasks (v2.0 format)"
    log "INFO" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    # Create temp file with conversion prompt
    local temp_prompt=$(mktemp)
    create_conversion_prompt_v2 "$project_name" "$project_dir" > "$temp_prompt"
    
    local convert_log="$project_dir/logs/convert-v2_${timestamp}.log"
    log "INFO" "Log file: $(basename "$convert_log")"
    
    # Run agent with spinner
    start_spinner "(Phase 1: Initial conversion)..."
    local convert_success=true
    
    cd "$REPO_ROOT"
    local prd_rel="projects/$project_name/prd.md"
    local json_rel="projects/$project_name/prd.json"
    local req_rel="projects/$project_name/requirements.md"
    
    # Invoke agent (Cursor Agent or Aider fallback)
    if ! invoke_agent "$temp_prompt" "$convert_log" "$AIDER_MODEL" "$prd_rel" "$json_rel" "$req_rel"; then
        convert_success=false
    fi
    stop_spinner
    
    rm -f "$temp_prompt"
    
    if [[ "$convert_success" != "true" ]]; then
        log "ERROR" "Agent conversion failed"
        log "INFO" "Check log: $convert_log"
        exit 1
    fi
    
    # Verify files were created/updated
    local story_count=0
    if [[ -f "$json_file" ]]; then
        story_count=$(jq '.userStories | length' "$json_file" 2>/dev/null || echo "0")
    fi
    
    # Normalize prd.json to ensure v2.0 format compliance
    if [[ "$story_count" -gt 0 ]]; then
        if normalize_prd_json_v2 "$json_file"; then
            log "INFO" "Normalized prd.json to v2.0 format"
        fi
    fi
    
    # Fallback: if model output prd.json in the log but agent didn't apply it, extract and write
    if [[ "$story_count" -eq 0 ]] && [[ -f "$convert_log" ]]; then
        log "WARN" "No stories found in prd.json, attempting to extract from log..."
        
        # Source extraction library
        source "$SCRIPT_DIR/lib/extract_json.sh" 2>/dev/null || true
        
        # Try to extract JSON from log using multiple strategies
        if extract_json_from_output "$convert_log" "$json_file"; then
            story_count=$(jq '.userStories | length' "$json_file" 2>/dev/null || echo "0")
            if [[ "${story_count:-0}" -gt 0 ]]; then
                normalize_prd_json_v2 "$json_file"
                log "INFO" "Recovered prd.json from log ($story_count stories)"
            fi
        else
            log "WARN" "Could not extract JSON from log - model may not have generated valid JSON"
            if grep -qi "rate limit\|RateLimitError\|30,000 input tokens" "$convert_log" 2>/dev/null; then
                log "INFO" "API rate limit detected. Wait a few minutes and re-run, or use --model local"
            fi
        fi
    fi
    
    if [[ "$story_count" -eq 0 ]]; then
        log "ERROR" "prd.json has no stories - conversion failed"
        log "INFO" "Check the log file: $convert_log"
        exit 1
    fi
    
    # Warn if story count seems too low
    if [[ "$story_count" -lt 30 ]]; then
        log "WARN" "Only $story_count stories generated - this may be too few for a complex PRD"
        log "WARN" "Expected 50-150+ stories for a PRD with multiple P0 features"
        log "WARN" "Consider re-running convert-v2.sh or manually reviewing prd.json for missing breakdowns"
    fi
    
    log "SUCCESS" "Phase 1 complete: Generated $story_count stories"
    echo ""
    
    # ═══════════════════════════════════════════════════════════════════════════
    # PHASE 1.5: Populate requirements.md if Phase 1 left it as placeholder
    # ═══════════════════════════════════════════════════════════════════════════
    if is_requirements_placeholder "$req_file"; then
        log "INFO" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        log "INFO" "PHASE 1.5: Populating requirements.md"
        log "INFO" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        
        local req_prompt=$(mktemp)
        create_requirements_fill_prompt "$project_name" > "$req_prompt"
        
        local req_log="$project_dir/logs/convert-v2_requirements_${timestamp}.log"
        start_spinner "(Phase 1.5: Filling requirements.md)..."
        
        if invoke_agent "$req_prompt" "$req_log" "$AIDER_MODEL" "$prd_rel" "$req_rel"; then
            log "SUCCESS" "requirements.md populated"
        else
            log "WARN" "Failed to populate requirements.md, but continuing..."
        fi
        
        stop_spinner
        rm -f "$req_prompt"
        echo ""
    fi
    
    # ═══════════════════════════════════════════════════════════════════════════
    # PHASE 2: Verification & Gap Analysis
    # ═══════════════════════════════════════════════════════════════════════════
    echo ""
    log "INFO" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log "INFO" "PHASE 2: Verification & gap analysis"
    log "INFO" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    local verify_prompt=$(mktemp)
    create_verification_prompt_v2 "$project_dir" > "$verify_prompt"
    
    local verify_log="$project_dir/logs/convert-v2_verify_${timestamp}.log"
    log "INFO" "Log file: $(basename "$verify_log")"
    
    start_spinner "(Phase 2: Verification & gap analysis)..."
    local verify_success=true
    
    if ! invoke_agent "$verify_prompt" "$verify_log" "$AIDER_MODEL" "$prd_rel" "$json_rel" "$req_rel"; then
        verify_success=false
    fi
    stop_spinner
    
    rm -f "$verify_prompt"
    
    if [[ "$verify_success" != "true" ]]; then
        log "WARN" "Verification phase failed - but initial conversion succeeded"
        log "INFO" "Check log: $verify_log"
    else
        # Re-normalize after verification phase
        if normalize_prd_json_v2 "$json_file"; then
            story_count=$(jq '.userStories | length' "$json_file" 2>/dev/null || echo "0")
            log "SUCCESS" "Verification complete: $story_count stories total"
        fi
    fi
    
    echo ""
    log "SUCCESS" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log "SUCCESS" "Conversion complete!"
    log "SUCCESS" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    echo "Summary:"
    echo "  Stories generated: $story_count"
    echo "  Format: v2.0 (enhanced)"
    echo ""
    echo "First 5 stories (by priority):"
    jq -r '.userStories | sort_by(.priority // 999) | .[:5][] | "  ○ [\(.id)] P\(.priority // "?") (\(.category)) \(.story | .[0:45])"' "$json_file" 2>/dev/null || echo "  (none)"
    echo ""
    echo "═══════════════════════════════════════════════════════"
    echo ""
    echo "Logs:"
    echo "  - Conversion: $convert_log"
    echo "  - Verification: $verify_log"
    echo ""
    echo "Next steps:"
    echo "  1. Review: cat $json_file | jq ."
    echo "  2. Start:  ./start-v2.sh $project_name"
    echo ""
}

show_help() {
    cat << EOF
Ralph Convert v2.0 - Convert PRD.md to v2.0 prd.json and requirements.md

Usage: $0 <project-name> [OPTIONS]

Arguments:
    project-name    Name of the Ralph project to convert

Options:
    --model MODE    Model mode: claude, local, or hybrid (default: $MODE)
    -h, --help      Show this help

Examples:
    $0 editio
    $0 editio --model local
    $0 editio --model hybrid

This will run a two-phase conversion process:

Phase 1 - Initial Conversion:
  - Read projects/<project-name>/prd.md
  - Generate prd.json (v2.0 format with enhanced fields)
  - Generate requirements.md (technical specifications)

Phase 2 - Verification:
  - Re-read the original PRD and generated files
  - Verify comprehensive coverage of all requirements
  - Add any missing stories or technical details

Environment Variables:
    RALPH_MODE      Model mode: claude, local, or hybrid (default: claude)
    ANTHROPIC_API_KEY   Required for Claude mode
EOF
}

# Parse command line arguments
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
        *)
            if [[ -z "${PROJECT_NAME:-}" ]]; then
                PROJECT_NAME="$1"
            fi
            shift
            ;;
    esac
done

# Setup model based on mode
setup_model "$MODE"

# Check dependencies
check_dependencies || exit 1

# Validate project name
if [[ -z "${PROJECT_NAME:-}" ]]; then
    log "ERROR" "Project name is required"
    show_help
    exit 1
fi

# Run main function
main "$PROJECT_NAME"
