#!/bin/bash
#
# Response Applier - Extracts code blocks from model output and writes them to files
# Enables Ralph-Ollama to actually create/update project files
#
# Supported formats (any language):
#   1. ```path/to/file.ext ... ```  (path in fence: .py, .rs, .go, etc.)
#   2. ```python
#      # File: path/to/file.ext
#      ... ```
#

apply_response_to_files() {
    local response="$1"
    local project_dir="$2"
    local story_id="${3:-unknown}"
    
    if [ ! -d "$project_dir" ]; then
        echo "Error: Project directory does not exist: $project_dir"
        return 1
    fi
    
    # Strip ANSI escape sequences
    response=$(echo "$response" | sed 's/\x1b\[[0-9;?]*[a-zA-Z]//g' 2>/dev/null || echo "$response")
    
    local files_written=0
    local temp_file=$(mktemp)
    
    # Parse: output ":::START::: fence" then content lines, then ":::END:::"
    echo "$response" | awk '
        /^```/ {
            if (inblock) {
                inblock = 0
                print ":::END:::"
            } else {
                inblock = 1
                fence = $0
                sub(/^``` */, "", fence)
                sub(/ *$/, "", fence)
                print ":::START::: " fence
            }
            next
        }
        inblock { print }
    ' > "$temp_file"
    
    local in_block=0
    local block_path=""
    local block_content=""
    
    while IFS= read -r line; do
        if [[ "$line" =~ ^:::START::: ]]; then
            block_path="${line#:::START::: }"
            block_path=$(echo "$block_path" | tr -d '\r')
            in_block=1
            block_content=""
            continue
        fi
        if [[ "$line" == :::END::: ]]; then
            in_block=0
            if [ -n "$block_content" ] || [ -n "$block_path" ]; then
                local file_path=""
                # Fence is a path only if it looks like a real path (no spaces, not instructional text)
                if [[ "$block_path" == */* ]] || [[ "$block_path" == *.* ]]; then
                    if [[ "$block_path" != *" "* ]] && [[ "$block_path" != *"Or put"* ]] && [[ "$block_path" != *"code block"* ]] && [[ "$block_path" != *"first line"* ]]; then
                        file_path="$block_path"
                    fi
                fi
                if [ -z "$file_path" ] && [ -n "$block_content" ]; then
                    local first_line=$(echo "$block_content" | head -1)
                    if [[ "$first_line" =~ \#\ *([Ff]ile|[Pp]ath):\ *([^[:space:]]+) ]]; then
                        file_path="${BASH_REMATCH[2]}"
                        block_content=$(echo "$block_content" | tail -n +2)
                    fi
                fi
                # Reject paths with spaces or that look like instructions
                if [ -n "$file_path" ] && [[ "$file_path" != *" "* ]] && [[ "$file_path" != *".."* ]] && [[ "$file_path" != */ ]]; then
                    file_path=$(echo "$file_path" | sed 's|^\./||')
                    local full_path="$project_dir/$file_path"
                    local dir_path=$(dirname "$full_path")
                    mkdir -p "$dir_path"
                    if [ -d "$full_path" ]; then
                        echo "  (skipped directory path $file_path)"
                    else
                        printf '%s' "$block_content" > "$full_path"
                        echo "  ✓ Wrote $file_path"
                        files_written=$((files_written + 1))
                    fi
                fi
            fi
            block_path=""
            block_content=""
            continue
        fi
        if [ $in_block -eq 1 ]; then
            if [ -n "$block_content" ]; then
                block_content="${block_content}
${line}"
            else
                block_content="$line"
            fi
        fi
    done < "$temp_file"
    
    rm -f "$temp_file"
    
    if [ $files_written -gt 0 ]; then
        echo "  ($files_written file(s) written)"
    fi
    
    return 0
}
