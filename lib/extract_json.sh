#!/bin/bash
# lib/extract_json.sh - Extract JSON from model output when edit format fails
# Used when Aider's edit format isn't followed correctly

# Extract JSON from model output
# Usage: extract_json_from_output "output_file" "target_json_file"
extract_json_from_output() {
    local output_file=$1
    local target_json_file=$2
    
    if [[ ! -f "$output_file" ]]; then
        return 1
    fi
    
    # Try multiple extraction strategies
    local extracted_json=""
    
    # Strategy 1: Find JSON object with "userStories" - look for opening brace
    local json_start=$(grep -n '"userStories"' "$output_file" | head -1 | cut -d: -f1)
    if [[ -n "$json_start" ]]; then
        # Go backwards to find opening brace
        local brace_line=$(sed -n "1,${json_start}p" "$output_file" | tac | grep -n '^{' | head -1 | cut -d: -f1)
        if [[ -n "$brace_line" ]]; then
            local actual_start=$((json_start - brace_line + 1))
            # Extract JSON block (look for closing brace)
            local json_block=$(sed -n "${actual_start},\$p" "$output_file")
            
            # Find the matching closing brace (simplified - take first 500 lines)
            local brace_count=0
            local json_lines=""
            while IFS= read -r line; do
                json_lines+="$line"$'\n'
                # Count braces
                brace_count=$((brace_count + $(echo "$line" | grep -o '{' | wc -l) - $(echo "$line" | grep -o '}' | wc -l)))
                # Stop when braces balance
                if [[ $brace_count -eq 0 ]] && [[ -n "$json_lines" ]]; then
                    break
                fi
                # Safety limit
                if [[ $(echo "$json_lines" | wc -l) -gt 500 ]]; then
                    break
                fi
            done <<< "$json_block"
            
            extracted_json="$json_lines"
        fi
    fi
    
    # Clean up: remove comments, fix JSON
    if [[ -n "$extracted_json" ]]; then
        # Remove // comments (entire lines and inline)
        extracted_json=$(echo "$extracted_json" | sed '/^\s*\/\//d' | sed 's|//.*$||g')
        # Remove trailing commas before } or ]
        extracted_json=$(echo "$extracted_json" | sed 's|,\s*}|}|g' | sed 's|,\s*]|]|g')
        # Remove empty lines
        extracted_json=$(echo "$extracted_json" | grep -v '^[[:space:]]*$')
        # Try to parse
        extracted_json=$(echo "$extracted_json" | jq -c . 2>/dev/null || echo "")
    fi
    
    # Strategy 2: Extract JSON between ```json and ```
    if [[ -z "$extracted_json" ]] || ! echo "$extracted_json" | jq -e '.userStories' >/dev/null 2>&1; then
        extracted_json=$(sed -n '/```json/,/```/p' "$output_file" 2>/dev/null | sed '1d;$d' | jq -c . 2>/dev/null || echo "")
    fi
    
    # Strategy 3: Extract JSON between ``` and ``` (any language, look for JSON structure)
    if [[ -z "$extracted_json" ]] || ! echo "$extracted_json" | jq -e '.userStories' >/dev/null 2>&1; then
        # Find all ``` blocks and check if they contain JSON
        local in_block=false
        local block_content=""
        while IFS= read -r line; do
            if [[ "$line" =~ ^\`\`\` ]]; then
                if [[ "$in_block" == true ]]; then
                    # End of block, check if it's JSON
                    if echo "$block_content" | jq -e '.userStories' >/dev/null 2>&1; then
                        extracted_json=$(echo "$block_content" | jq -c .)
                        break
                    fi
                    block_content=""
                    in_block=false
                else
                    in_block=true
                fi
            elif [[ "$in_block" == true ]]; then
                block_content+="$line"$'\n'
            fi
        done < "$output_file"
    fi
    
    # Strategy 4: Look for JSON object starting with { and containing "userStories" (multiline)
    if [[ -z "$extracted_json" ]] || ! echo "$extracted_json" | jq -e '.userStories' >/dev/null 2>&1; then
        # Find line with { and "userStories", then extract complete JSON
        local json_start=$(grep -n '"userStories"' "$output_file" | head -1 | cut -d: -f1)
        if [[ -n "$json_start" ]]; then
            # Go back to find opening brace
            local brace_line=$(sed -n "1,${json_start}p" "$output_file" | tac | grep -n '^{' | head -1 | cut -d: -f1)
            if [[ -n "$brace_line" ]]; then
                local actual_start=$((json_start - brace_line + 1))
                # Extract until matching closing brace (simplified - extract next 500 lines)
                extracted_json=$(sed -n "${actual_start},\$p" "$output_file" | head -500 | jq -c . 2>/dev/null || echo "")
            fi
        fi
    fi
    
    # Strategy 5: Use awk to extract JSON block (like convert.sh does)
    if [[ -z "$extracted_json" ]] || ! echo "$extracted_json" | jq -e '.userStories' >/dev/null 2>&1; then
        local project_name=$(basename "$(dirname "$target_json_file")")
        extracted_json=$(awk -v path="projects/$project_name/prd.json" '
            $0 ~ "^" path " *$" { want=1; next }
            want && $0 ~ "^```" && !capturing { capturing=1; buf=""; next }
            want && capturing && $0 ~ "^```" { print buf; exit }
            capturing { buf = (buf == "" ? $0 : buf "\n" $0) }
        ' "$output_file" 2>/dev/null | jq -c . 2>/dev/null || echo "")
    fi
    
    # Strategy 6: Try to parse the entire file as JSON (if it's mostly JSON)
    if [[ -z "$extracted_json" ]] || ! echo "$extracted_json" | jq -e '.userStories' >/dev/null 2>&1; then
        extracted_json=$(jq -c '{version, branchName, createdAt, updatedAt, userStories}' "$output_file" 2>/dev/null || echo "")
    fi
    
    # If we found JSON, validate and write it
    if [[ -n "$extracted_json" ]]; then
        # Validate JSON structure
        if echo "$extracted_json" | jq -e '.userStories | type == "array"' >/dev/null 2>&1; then
            # Ensure v2.0 format fields exist
            local story_count
            story_count=$(echo "$extracted_json" | jq -r '.userStories | length' 2>/dev/null || echo "0")
            if [[ "${story_count:-0}" -gt 0 ]]; then
                # Pretty print and write
                echo "$extracted_json" | jq '.' > "$target_json_file"
                return 0
            fi
        fi
    fi
    
    return 1
}

# Extract markdown content from model output
# Usage: extract_markdown_from_output "output_file" "target_md_file"
extract_markdown_from_output() {
    local output_file=$1
    local target_md_file=$2
    
    if [[ ! -f "$output_file" ]]; then
        return 1
    fi
    
    # Try to extract markdown content
    local extracted_md=""
    
    # Strategy 1: Extract between ```markdown and ```
    extracted_md=$(sed -n '/```markdown/,/```/p' "$output_file" 2>/dev/null | sed '1d;$d' || echo "")
    
    # Strategy 2: Extract between ``` and ``` (if it looks like markdown)
    if [[ -z "$extracted_md" ]]; then
        extracted_md=$(sed -n '/```$/,/```/p' "$output_file" 2>/dev/null | sed '1d;$d' | head -100 || echo "")
    fi
    
    # Strategy 3: Look for requirements.md section
    if [[ -z "$extracted_md" ]]; then
        local req_section=$(grep -n "requirements.md\|Technical Specifications\|# Technical" "$output_file" | head -1 | cut -d: -f1)
        if [[ -n "$req_section" ]]; then
            extracted_md=$(sed -n "${req_section},\$p" "$output_file" | head -200 || echo "")
        fi
    fi
    
    # If we found content, write it
    if [[ -n "$extracted_md" ]] && [[ ${#extracted_md} -gt 50 ]]; then
        echo "$extracted_md" > "$target_md_file"
        return 0
    fi
    
    return 1
}
