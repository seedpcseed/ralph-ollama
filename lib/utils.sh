#!/bin/bash

# Ralph Utils - Common utility functions
# Sourced by other Ralph scripts

# Colors for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Log function with timestamps and colors
log() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local color=""
    
    case $level in
        "INFO")    color=$BLUE ;;
        "WARN")    color=$YELLOW ;;
        "ERROR")   color=$RED ;;
        "SUCCESS") color=$GREEN ;;
        "LOOP")    color=$PURPLE ;;
        "DEBUG")   color=$CYAN ;;
    esac
    
    echo -e "${color}[$timestamp] [$level] $message${NC}"
    
    # Also log to file if LOG_FILE is set
    if [[ -n "$LOG_FILE" ]]; then
        echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    fi
}

# Get Ralph root directory
get_ralph_root() {
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)"
    # Go up one level from lib/ or stay if already at ralph/
    if [[ "$(basename "$script_dir")" == "lib" ]]; then
        echo "$(dirname "$script_dir")"
    else
        echo "$script_dir"
    fi
}

# Get project directory
get_project_dir() {
    local project_name=$1
    local ralph_root=$(get_ralph_root)
    echo "$ralph_root/projects/$project_name"
}

# Check if project exists
project_exists() {
    local project_name=$1
    local project_dir=$(get_project_dir "$project_name")
    [[ -d "$project_dir" ]]
}

# Get ISO timestamp
get_iso_timestamp() {
    date -u '+%Y-%m-%dT%H:%M:%SZ'
}

# Get time until next hour (for rate limit reset)
get_seconds_until_next_hour() {
    local current_minute=$(date +%M)
    local current_second=$(date +%S)
    echo $(((60 - current_minute - 1) * 60 + (60 - current_second)))
}

# Format seconds as HH:MM:SS
format_duration() {
    local seconds=$1
    local hours=$((seconds / 3600))
    local minutes=$(((seconds % 3600) / 60))
    local secs=$((seconds % 60))
    printf "%02d:%02d:%02d" $hours $minutes $secs
}

# Check if a command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Read JSON value using jq
json_get() {
    local file=$1
    local path=$2
    jq -r "$path" "$file" 2>/dev/null
}

# Update JSON value using jq
json_set() {
    local file=$1
    local path=$2
    local value=$3
    local tmp_file=$(mktemp)
    jq "$path = $value" "$file" > "$tmp_file" && mv "$tmp_file" "$file"
}

# Count incomplete stories in prd.json (supports both old array and new object format)
count_incomplete_stories() {
    local prd_file=$1
    # Handle new format with userStories wrapper or old array format
    jq 'if type == "object" then .userStories else . end | [.[] | select(.passes == false)] | length' "$prd_file" 2>/dev/null || echo "0"
}

# Count complete stories in prd.json
count_complete_stories() {
    local prd_file=$1
    jq 'if type == "object" then .userStories else . end | [.[] | select(.passes == true)] | length' "$prd_file" 2>/dev/null || echo "0"
}

# Count total stories in prd.json
count_total_stories() {
    local prd_file=$1
    jq 'if type == "object" then .userStories else . end | length' "$prd_file" 2>/dev/null || echo "0"
}

# Get next incomplete story from prd.json (sorted by priority, then id)
get_next_story() {
    local prd_file=$1
    jq -c 'if type == "object" then .userStories else . end | [.[] | select(.passes == false)] | sort_by(.priority // 999, .id) | first' "$prd_file" 2>/dev/null
}

# Mark story as complete in prd.json
mark_story_complete() {
    local prd_file=$1
    local story_id=$2
    local tmp_file=$(mktemp)
    jq --arg id "$story_id" '
        if type == "object" then
            .userStories = [.userStories[] | if .id == $id then .passes = true else . end]
        else
            map(if .id == $id then .passes = true else . end)
        end
    ' "$prd_file" > "$tmp_file" && mv "$tmp_file" "$prd_file"
}

# Get branch name from prd.json
get_branch_name() {
    local prd_file=$1
    jq -r '.branchName // empty' "$prd_file" 2>/dev/null
}

# Update story notes in prd.json
update_story_notes() {
    local prd_file=$1
    local story_id=$2
    local notes=$3
    local tmp_file=$(mktemp)
    jq --arg id "$story_id" --arg notes "$notes" '
        if type == "object" then
            .userStories = [.userStories[] | if .id == $id then .notes = $notes else . end]
        else
            map(if .id == $id then .notes = $notes else . end)
        end
    ' "$prd_file" > "$tmp_file" && mv "$tmp_file" "$prd_file"
}

# Append to progress file (format matches X guide)
append_progress() {
    local progress_file=$1
    local story_id=$2
    local message=$3
    local timestamp=$(get_iso_timestamp)
    
    cat >> "$progress_file" << EOF

---
## $(date '+%Y-%m-%d') - Story $story_id

$message

**Learnings:**
- (Add any patterns discovered)
- (Add any gotchas encountered)

**Gotchas:**
- (Things you've encountered)
EOF
}

# Parse reset time from "You're out of extra usage · resets 3am (Asia/Makassar)" message
# Returns: seconds to wait until reset time, or empty if can't parse
# Assumes the script runs in the same timezone as reported by Claude
parse_usage_reset_time() {
    local output_file=$1
    
    # Look for the pattern: "resets Xam/pm"
    local reset_time=$(grep -oE "resets [0-9]{1,2}(am|pm)" "$output_file" 2>/dev/null | grep -oE "[0-9]{1,2}(am|pm)" | head -1)
    
    if [[ -z "$reset_time" ]]; then
        return 1
    fi
    
    # Convert 12-hour to 24-hour format
    local hour=$(echo "$reset_time" | grep -oE "[0-9]+")
    local ampm=$(echo "$reset_time" | grep -oE "(am|pm)")
    
    if [[ "$ampm" == "pm" ]] && [[ $hour -ne 12 ]]; then
        hour=$((hour + 12))
    elif [[ "$ampm" == "am" ]] && [[ $hour -eq 12 ]]; then
        hour=0
    fi
    
    # Get current epoch time
    local current_epoch=$(date +%s)
    
    # Calculate seconds until reset hour today
    # Using date arithmetic for cross-platform compatibility
    local today=$(date +%Y-%m-%d)
    local reset_epoch
    
    # Try GNU date first (gdate on macOS, date on Linux)
    if command -v gdate &>/dev/null; then
        reset_epoch=$(gdate -d "${today} ${hour}:00:00" +%s 2>/dev/null)
    else
        # Try GNU date syntax (Linux)
        reset_epoch=$(date -d "${today} ${hour}:00:00" +%s 2>/dev/null)
    fi
    
    # Fallback for BSD date (macOS without coreutils)
    if [[ -z "$reset_epoch" ]]; then
        reset_epoch=$(date -j -f "%Y-%m-%d %H:%M:%S" "${today} ${hour}:00:00" +%s 2>/dev/null)
    fi
    
    if [[ -z "$reset_epoch" ]]; then
        return 1
    fi
    
    # If reset time has already passed today, wait until tomorrow
    if [[ $reset_epoch -le $current_epoch ]]; then
        reset_epoch=$((reset_epoch + 86400))
    fi
    
    # Calculate seconds to wait
    local wait_seconds=$((reset_epoch - current_epoch))
    
    echo "$wait_seconds"
    return 0
}

# Wait for Claude usage limit to reset with countdown
# Usage: wait_for_usage_reset <output_file>
wait_for_usage_reset() {
    local output_file=$1
    
    local wait_seconds
    # Use || true to prevent set -e from exiting if parsing fails
    wait_seconds=$(parse_usage_reset_time "$output_file") || true
    
    if [[ -z "$wait_seconds" ]] || [[ $wait_seconds -le 0 ]]; then
        # Fallback: wait 1 hour if we can't parse the time
        log "WARN" "Could not parse reset time, defaulting to 1 hour wait"
        wait_seconds=3600
    fi
    
    # Extract reset info for logging
    local reset_info=$(grep -oE "resets [0-9]{1,2}(am|pm) \([A-Za-z/_]+\)" "$output_file" 2>/dev/null | head -1)
    
    # Add 60 second buffer after reset time to be safe
    wait_seconds=$((wait_seconds + 60))
    
    log "WARN" "🚫 Claude usage limit reached"
    log "INFO" "⏰ Reset time: ${reset_info:-unknown}"
    log "INFO" "💤 Waiting $(format_duration $wait_seconds) until reset (+60s buffer)..."
    
    # Countdown with periodic updates
    while [[ $wait_seconds -gt 0 ]]; do
        local remaining=$(format_duration $wait_seconds)
        printf "\r${YELLOW}⏳ Time until reset: %s ${NC}" "$remaining"
        
        # Log every 10 minutes
        if [[ $((wait_seconds % 600)) -eq 0 ]] && [[ $wait_seconds -gt 0 ]]; then
            log "INFO" "Still waiting... $remaining remaining"
        fi
        
        sleep 1
        wait_seconds=$((wait_seconds - 1))
    done
    printf "\n"
    
    log "SUCCESS" "✅ Reset time reached! Resuming..."
    return 0
}

# Check if output indicates Claude usage limit
check_usage_limit() {
    local output_file=$1
    grep -qi "out of extra usage\|You're out of extra usage" "$output_file" 2>/dev/null
}

# Generate prompt for a specific story
generate_prompt() {
    local project_dir="$1"
    local story_json="$2"
    
    local story_id=$(echo "$story_json" | jq -r '.id')
    local story_text=$(echo "$story_json" | jq -r '.story')
    local steps=$(echo "$story_json" | jq -r '.steps | join("\n")')
    local acceptance=$(echo "$story_json" | jq -r '.acceptance')
    local project_name
    project_name=$(basename "$project_dir")
    
    # Read progress for context
    local progress=""
    if [ -f "$project_dir/progress.txt" ]; then
        progress=$(tail -50 "$project_dir/progress.txt")
    fi
    
    # Read PRD for full context
    local prd_content=""
    if [ -f "$project_dir/prd.md" ]; then
        prd_content=$(head -100 "$project_dir/prd.md")
    fi
    
    cat <<EOF
# Implementation Task: Story $story_id

## Story
$story_text

## Steps
$steps

## Acceptance Criteria
$acceptance

## Project Context
$prd_content

## Recent Progress
$progress

## How to edit files (REQUIRED - you MUST follow this format)
You are inside Aider. To create or edit a file you MUST use this exact format:
- Line 1: file path only, e.g. projects/$project_name/README.md
- Line 2: exactly \`\`\` (three backticks, no space after)
- Next lines: full file contents
- Last line: exactly \`\`\`
No blank line between the path and the \`\`\`. 

CRITICAL: Do NOT edit projects/$project_name/prd.json - it contains task definitions, not code.

Example for creating a Rust crate (Cargo.toml):

projects/$project_name/Cargo.toml
\`\`\`
[package]
name = "editio-core"
version = "0.1.0"
edition = "2021"

[dependencies]
\`\`\`

Example for creating a Rust source file:

projects/$project_name/src/lib.rs
\`\`\`
pub fn hello() {
    println!("Hello, world!");
}
\`\`\`

You MUST output at least one file in this format. Do not describe code or show examples in \`\`\`rust blocks—you must use the path-plus-backticks format above so Aider applies the edit.

## Instructions
1. Create the actual files needed for this story (see format above). For Rust crates, create Cargo.toml and src/lib.rs or src/main.rs.
2. Do NOT edit prd.json - it is a task definition file, not code.
3. Follow the steps and meet acceptance criteria.
4. When done, respond with "Task complete" or "Story complete".

Begin implementation now. Output files using the format above.
EOF
}

# Check rate limit (simple implementation)
check_rate_limit() {
    local project_dir="$1"
    local max_per_hour="$2"
    local state_file="$project_dir/.ralph_rate_limit"
    
    # Simple rate limiting based on call count
    local current_hour=$(date +%Y%m%d%H)
    
    if [ -f "$state_file" ]; then
        local stored_hour=$(head -1 "$state_file")
        local call_count=$(tail -1 "$state_file")
        
        if [ "$stored_hour" = "$current_hour" ]; then
            if [ "$call_count" -ge "$max_per_hour" ]; then
                log "WARN" "⏸️  Rate limit reached ($call_count/$max_per_hour calls this hour)"
                log "INFO" "   Waiting for next hour..."
                sleep 3600
                echo "$current_hour" > "$state_file"
                echo "0" >> "$state_file"
            else
                echo "$stored_hour" > "$state_file"
                echo "$((call_count + 1))" >> "$state_file"
            fi
        else
            # New hour
            echo "$current_hour" > "$state_file"
            echo "1" >> "$state_file"
        fi
    else
        echo "$current_hour" > "$state_file"
        echo "1" >> "$state_file"
    fi
}

# Check dependencies
check_dependencies() {
    local missing=()
    
    if ! command_exists "aider"; then
        missing+=("aider (Aider CLI)")
    fi
    
    if ! command_exists "jq"; then
        missing+=("jq (JSON processor)")
    fi
    
    if ! command_exists "tmux"; then
        missing+=("tmux (terminal multiplexer)")
    fi
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        log "ERROR" "Missing dependencies:"
        for dep in "${missing[@]}"; do
            echo "  - $dep"
        done
        echo ""
        echo "Install with:"
        echo "  ./setup.sh"
        echo ""
        echo "Or manually:"
        echo "  brew install jq tmux"
        if command -v pipx &> /dev/null; then
            echo "  pipx install aider-chat  # Recommended for Python 3.13"
        elif command -v uv &> /dev/null; then
            echo "  uv pip install aider-chat  # Alternative for Python 3.13"
        else
            echo "  pip3 install aider-chat  # Requires Python 3.10-3.12"
        fi
        return 1
    fi
    
    return 0
}
