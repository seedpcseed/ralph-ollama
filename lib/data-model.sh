#!/bin/bash
# lib/data-model.sh - Enhanced Data Model API Functions for Ralph 2.0
# Provides functions for working with v2.0 format prd.json and related files

# Get next story to work on (with dependency checking)
get_next_story_v2() {
    local prd_file=$1
    
    # Get all incomplete stories, sorted by priority
    local stories
    stories=$(jq -c '
        .userStories[] | 
        select(.status != "complete") | 
        {
            id,
            priority: (.priority // 999),
            dependsOn,
            status
        }
    ' "$prd_file" 2>/dev/null)
    
    if [[ -z "$stories" ]]; then
        return 1
    fi
    
    # Find stories with no incomplete dependencies
    while IFS= read -r story; do
        local story_id
        story_id=$(echo "$story" | jq -r '.id')
        local depends_on
        depends_on=$(echo "$story" | jq -r '.dependsOn[]?' 2>/dev/null || echo "")
        
        # Check if all dependencies are complete
        local all_deps_complete=true
        if [[ -n "$depends_on" ]]; then
            for dep_id in $depends_on; do
                local dep_status
                dep_status=$(jq -r ".userStories[] | select(.id == \"$dep_id\") | .status" "$prd_file" 2>/dev/null)
                if [[ "$dep_status" != "complete" ]]; then
                    all_deps_complete=false
                    break
                fi
            done
        fi
        
        if [[ "$all_deps_complete" == "true" ]]; then
            # Return full story object
            jq -c ".userStories[] | select(.id == \"$story_id\")" "$prd_file"
            return 0
        fi
    done <<< "$stories"
    
    # If no story found, check for blocked stories
    return 1
}

# Mark story complete in v2.0 format
mark_story_complete_v2() {
    local prd_file=$1
    local story_id=$2
    
    local tmp_file
    tmp_file=$(mktemp)
    
    jq --arg id "$story_id" '
        .userStories = (.userStories | map(
            if .id == $id then
                .status = "complete" |
                .progress = 100 |
                .updatedAt = (now | strftime("%Y-%m-%dT%H:%M:%SZ"))
            else .
            end
        )) |
        .updatedAt = (now | strftime("%Y-%m-%dT%H:%M:%SZ"))
    ' "$prd_file" > "$tmp_file" && mv "$tmp_file" "$prd_file"
}

# Update story status
update_story_status() {
    local prd_file=$1
    local story_id=$2
    local status=$3  # pending, in_progress, blocked, failed, complete
    
    local tmp_file
    tmp_file=$(mktemp)
    
    jq --arg id "$story_id" --arg status "$status" '
        .userStories = (.userStories | map(
            if .id == $id then
                .status = $status |
                .updatedAt = (now | strftime("%Y-%m-%dT%H:%M:%SZ"))
            else .
            end
        )) |
        .updatedAt = (now | strftime("%Y-%m-%dT%H:%M:%SZ"))
    ' "$prd_file" > "$tmp_file" && mv "$tmp_file" "$prd_file"
}

# Update story progress
update_story_progress() {
    local prd_file=$1
    local story_id=$2
    local progress=$3  # 0-100
    
    local tmp_file
    tmp_file=$(mktemp)
    
    jq --arg id "$story_id" --argjson progress "$progress" '
        .userStories = (.userStories | map(
            if .id == $id then
                .progress = $progress |
                .updatedAt = (now | strftime("%Y-%m-%dT%H:%M:%SZ"))
            else .
            end
        )) |
        .updatedAt = (now | strftime("%Y-%m-%dT%H:%M:%SZ"))
    ' "$prd_file" > "$tmp_file" && mv "$tmp_file" "$prd_file"
}

# Check if story dependencies are complete
check_dependencies() {
    local prd_file=$1
    local story_id=$2
    
    local depends_on
    depends_on=$(jq -r ".userStories[] | select(.id == \"$story_id\") | .dependsOn[]?" "$prd_file" 2>/dev/null || echo "")
    
    if [[ -z "$depends_on" ]]; then
        return 0  # No dependencies
    fi
    
    for dep_id in $depends_on; do
        local dep_status
        dep_status=$(jq -r ".userStories[] | select(.id == \"$dep_id\") | .status" "$prd_file" 2>/dev/null)
        if [[ "$dep_status" != "complete" ]]; then
            return 1  # Dependency not complete
        fi
    done
    
    return 0  # All dependencies complete
}

# Get blocked stories (stories that depend on incomplete stories)
get_blocked_stories() {
    local prd_file=$1
    
    jq -r '.userStories[] | 
        select(.status != "complete") | 
        select(.dependsOn != []) |
        .id as $id |
        .dependsOn[] as $dep |
        .userStories[] | 
        select(.id == $dep and .status != "complete") |
        $id
    ' "$prd_file" 2>/dev/null | sort -u
}

# Count stories by status
count_stories_by_status() {
    local prd_file=$1
    local status=$2
    
    jq -r ".userStories[] | select(.status == \"$status\") | .id" "$prd_file" 2>/dev/null | wc -l
}

# Count total stories
count_total_stories_v2() {
    local prd_file=$1
    jq '.userStories | length' "$prd_file" 2>/dev/null || echo "0"
}

# Count complete stories
count_complete_stories_v2() {
    local prd_file=$1
    count_stories_by_status "$prd_file" "complete"
}

# Count incomplete stories
count_incomplete_stories_v2() {
    local prd_file=$1
    local total
    total=$(count_total_stories_v2 "$prd_file")
    local complete
    complete=$(count_complete_stories_v2 "$prd_file")
    echo $((total - complete))
}

# Record verification result
record_verification_result() {
    local verify_file=$1
    local story_id=$2
    local command=$3
    local result=$4  # pass, fail
    local exit_code=$5
    local output=$6
    
    local tmp_file
    tmp_file=$(mktemp)
    
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    jq --arg id "$story_id" \
       --arg cmd "$command" \
       --arg result "$result" \
       --argjson exit "$exit_code" \
       --arg output "$output" \
       --arg ts "$timestamp" '
        if .verifications[$id] then
            .verifications[$id].history += [{
                timestamp: $ts,
                result: $result,
                exitCode: $exit,
                output: $output,
                duration: 0
            }] |
            .verifications[$id].lastResult = $result |
            .verifications[$id].lastRun = $ts |
            .verifications[$id].totalRuns += 1 |
            if $result == "pass" then
                .verifications[$id].passCount += 1
            else
                .verifications[$id].failCount += 1
            end
        else
            .verifications[$id] = {
                command: $cmd,
                history: [{
                    timestamp: $ts,
                    result: $result,
                    exitCode: $exit,
                    output: $output,
                    duration: 0
                }],
                lastResult: $result,
                lastRun: $ts,
                totalRuns: 1,
                passCount: (if $result == "pass" then 1 else 0 end),
                failCount: (if $result == "fail" then 1 else 0 end)
            }
        end
    ' "$verify_file" > "$tmp_file" && mv "$tmp_file" "$verify_file"
}

# Update file mapping
update_file_mapping() {
    local mapping_file=$1
    local file_path=$2
    local story_id=$3
    local status=$4  # created, modified, deleted
    
    local tmp_file
    tmp_file=$(mktemp)
    
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    jq --arg path "$file_path" \
       --arg id "$story_id" \
       --arg status "$status" \
       --arg ts "$timestamp" '
        if .files[$path] then
            .files[$path].stories = (.files[$path].stories + [$id] | unique) |
            .files[$path].status = $status |
            .files[$path].lastModified = $ts
        else
            .files[$path] = {
                stories: [$id],
                status: $status,
                lastModified: $ts,
                lines: 0,
                gitCommit: ""
            }
        end |
        if .storyFiles[$id] then
            .storyFiles[$id] = (.storyFiles[$id] + [$path] | unique)
        else
            .storyFiles[$id] = [$path]
        end
    ' "$mapping_file" > "$tmp_file" && mv "$tmp_file" "$mapping_file"
}

# Get files for a story
get_story_files() {
    local mapping_file=$1
    local story_id=$2
    
    jq -r ".storyFiles[\"$story_id\"] // [] | .[]" "$mapping_file" 2>/dev/null
}

# Get stories for a file
get_file_stories() {
    local mapping_file=$1
    local file_path=$2
    
    jq -r ".files[\"$file_path\"].stories // [] | .[]" "$mapping_file" 2>/dev/null
}
