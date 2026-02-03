#!/bin/bash
#
# Ralph-Ollama Utilities
#

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Validate prd.json has expected structure (branchName, userStories array)
# Returns 0 if valid, 1 if invalid
validate_prd_json() {
    local prd_file="$1"
    if [ ! -f "$prd_file" ]; then
        return 1
    fi
    jq -e '.userStories | type == "array"' "$prd_file" >/dev/null 2>&1
}

# Get next incomplete story from PRD
get_next_story() {
    local prd_file="$1"
    
    if [ ! -f "$prd_file" ]; then
        echo "ERROR"
        return 1
    fi
    
    # Validate structure before querying
    if ! validate_prd_json "$prd_file"; then
        echo "ERROR"
        return 1
    fi
    
    # Get first story where passes=false, sorted by priority
    local next_story
    next_story=$(jq -r '
        .userStories 
        | map(select(.passes == false))
        | sort_by(.priority)
        | .[0] // empty
    ' "$prd_file" 2>/dev/null) || { echo "ERROR"; return 1; }
    
    if [ -z "$next_story" ] || [ "$next_story" = "null" ]; then
        echo "COMPLETE"
        return 0
    fi
    
    echo "$next_story"
}

# Mark a story as complete
mark_story_complete() {
    local prd_file="$1"
    local story_id="$2"
    
    # Update the story's passes field to true
    jq --arg id "$story_id" '
        .userStories |= map(
            if .id == $id then
                .passes = true
            else
                .
            end
        )
    ' "$prd_file" > "${prd_file}.tmp" && mv "${prd_file}.tmp" "$prd_file"
}

# Count completed stories
count_completed_stories() {
    local prd_file="$1"
    jq '[.userStories[] | select(.passes == true)] | length' "$prd_file"
}

# Update status file
update_status() {
    local status_file="$1"
    local status="$2"
    local loop_count="$3"
    local completed_count="$4"
    
    jq -n \
        --arg status "$status" \
        --argjson loop "$loop_count" \
        --argjson completed "$completed_count" \
        --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        '{
            status: $status,
            loop_count: $loop,
            completed_stories: $completed,
            last_updated: $timestamp
        }' > "$status_file"
}

# Show project status
show_project_status() {
    local project_dir="$1"
    local status_file="$project_dir/status.json"
    local prd_file="$project_dir/prd.json"
    local cb_file="$project_dir/.circuit_breaker"
    
    echo "=================================================="
    echo "Project Status"
    echo "=================================================="
    
    if [ -f "$status_file" ]; then
        echo "Status: $(jq -r '.status' "$status_file")"
        echo "Loops: $(jq -r '.loop_count' "$status_file")"
        echo "Completed: $(jq -r '.completed_stories' "$status_file")"
        echo "Last update: $(jq -r '.last_updated' "$status_file")"
    fi
    
    echo ""
    
    if [ -f "$prd_file" ]; then
        local total=$(jq '[.userStories[]] | length' "$prd_file")
        local complete=$(jq '[.userStories[] | select(.passes == true)] | length' "$prd_file")
        local incomplete=$(jq '[.userStories[] | select(.passes == false)] | length' "$prd_file")
        
        echo "Stories: $complete/$total complete ($incomplete remaining)"
        
        if [ $incomplete -gt 0 ]; then
            echo ""
            echo "Next stories:"
            jq -r '
                .userStories 
                | map(select(.passes == false))
                | sort_by(.priority)
                | .[0:3]
                | .[]
                | "  [\(.id)] \(.story)"
            ' "$prd_file"
        fi
    fi
    
    echo ""
    
    if [ -f "$cb_file" ]; then
        local cb_state=$(cat "$cb_file")
        if [ "$cb_state" = "OPEN" ]; then
            echo -e "${RED}Circuit Breaker: OPEN${NC}"
            echo "Run with --reset to continue"
        else
            echo -e "${GREEN}Circuit Breaker: CLOSED${NC}"
        fi
    fi
    
    echo "=================================================="
}

# Extract project structure from PRD if available (Architecture section)
get_project_structure() {
    local prd_file="$1"
    if [ -f "$prd_file" ]; then
        # Capture from ### Architecture or ## Architecture until next ## or ###
        sed -n '/^### Architecture/,/^## /p' "$prd_file" 2>/dev/null | head -35 || true
        sed -n '/^## Architecture/,/^## /p' "$prd_file" 2>/dev/null | head -35 || true
    fi
}

# Build prompt for Ollama
build_ollama_prompt() {
    local project_dir="$1"
    local story_json="$2"
    
    local prompt_template="$project_dir/PROMPT.md"
    local progress_file="$project_dir/progress.txt"
    local prd_file="$project_dir/prd.md"
    
    local story_id=$(echo "$story_json" | jq -r '.id')
    local story=$(echo "$story_json" | jq -r '.story')
    local steps=$(echo "$story_json" | jq -r '.steps | join("\n")')
    local acceptance=$(echo "$story_json" | jq -r '.acceptance')
    
    # P1: Codebase context - existing files and structure
    local project_files=""
    if [ -d "$project_dir" ]; then
        project_files=$(find "$project_dir" -type f \( -name "*.py" -o -name "*.rs" -o -name "*.go" -o -name "*.sh" -o -name "*.md" -o -name "*.json" -o -name "*.toml" -o -name "Cargo.toml" -o -name "go.mod" -o -name "package.json" -o -name "*.txt" \) \
            ! -path "*/logs/*" ! -path "*/.git/*" 2>/dev/null | sed "s|$project_dir/||" | sort | head -60)
    fi
    
    local project_structure
    project_structure=$(get_project_structure "$prd_file")
    
    # Build the prompt
    cat << EOF
You are an autonomous AI developer working on implementing a user story.

CURRENT PROJECT FILES (extend or modify these):
$project_files

EOF
    if [ -n "$project_structure" ]; then
        cat << EOF
PROJECT STRUCTURE (from PRD - follow this layout):
$project_structure

EOF
    fi
    cat << EOF
CURRENT TASK:
Story ID: $story_id
Description: $story

IMPLEMENTATION STEPS:
$steps

ACCEPTANCE CRITERIA:
$acceptance

EOF

    # Add progress/learnings if available (limit size aggressively to avoid "argument list too long")
    if [ -f "$progress_file" ]; then
        PROGRESS_SIZE=$(wc -c < "$progress_file" 2>/dev/null || echo "0")
        # Limit to last 1000 chars or last 15 lines (whichever is smaller) to keep prompt manageable
        if [ "$PROGRESS_SIZE" -gt 1000 ]; then
            PROGRESS_CONTENT=$(tail -n 15 "$progress_file" | tail -c 1000)
            PROGRESS_CONTENT="(Showing last 15 lines, truncated for size)\n$PROGRESS_CONTENT"
        else
            PROGRESS_CONTENT=$(cat "$progress_file")
        fi
        cat << EOF
PREVIOUS LEARNINGS (recent):
$PROGRESS_CONTENT

EOF
    fi

    # Add template instructions if available
    if [ -f "$prompt_template" ]; then
        cat "$prompt_template"
        echo ""
    fi

    cat << 'EOF'

IMPORTANT INSTRUCTIONS:
1. Implement the story according to the steps and acceptance criteria
2. To create/update files, use code blocks with the file path in the fence:
   ```path/to/file.ext
   # file contents (any language: .py, .rs, .go, .js, etc.)
   ```
   Or put # File: path/to/file.ext on the first line of a code block.
3. When you've completed the story, end your response with:
   
   STATUS: COMPLETE
   LEARNINGS: [Any patterns, gotchas, or important notes for future iterations]

4. If you cannot complete the story, explain what's blocking you and end with:
   
   STATUS: INCOMPLETE
   REASON: [Why you couldn't complete it]
   NEXT_STEPS: [What needs to happen next]

5. Your code blocks will be written to the project - use the file path format above
6. Document any important patterns or learnings for future tasks

Begin your implementation now:
EOF
}

# Check if prd.md is unchanged from template (project not set up)
# Returns 0 if unchanged, 1 if customized or files missing
is_prd_template_unchanged() {
    local prd_file="$1"
    local template_file="$2"
    [ -f "$prd_file" ] && [ -f "$template_file" ] || return 1
    cmp -s "$prd_file" "$template_file"
}

# Trim progress.txt if it gets too large (prevent "argument list too long" errors)
trim_progress_file() {
    local progress_file="$1"
    local max_size="${2:-50000}"  # Default 50KB
    
    if [ ! -f "$progress_file" ]; then
        return 0
    fi
    
    local size=$(wc -c < "$progress_file" 2>/dev/null || echo "0")
    if [ "$size" -gt "$max_size" ]; then
        # Keep header and last 50 lines
        {
            head -n 15 "$progress_file"
            echo ""
            echo "--- (File trimmed on $(date '+%Y-%m-%d %H:%M:%S') - was ${size} bytes) ---"
            echo ""
            tail -n 50 "$progress_file"
        } > "${progress_file}.tmp" && mv "${progress_file}.tmp" "$progress_file"
    fi
}

# Extract JSON safely
extract_json() {
    local file="$1"
    local field="$2"
    jq -r ".$field // empty" "$file" 2>/dev/null || echo ""
}
