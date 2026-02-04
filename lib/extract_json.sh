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
    
    # Strategy 1: Look for JSON object starting with { and containing "userStories"
    extracted_json=$(grep -oP '\{[^}]*"userStories"[^}]*\}' "$output_file" 2>/dev/null | head -1)
    
    # Strategy 2: Extract JSON between ```json and ```
    if [[ -z "$extracted_json" ]]; then
        extracted_json=$(sed -n '/```json/,/```/p' "$output_file" 2>/dev/null | sed '1d;$d' | jq -c . 2>/dev/null || echo "")
    fi
    
    # Strategy 3: Extract JSON between ``` and ``` (any language)
    if [[ -z "$extracted_json" ]]; then
        extracted_json=$(sed -n '/```$/,/```/p' "$output_file" 2>/dev/null | sed '1d;$d' | jq -c . 2>/dev/null || echo "")
    fi
    
    # Strategy 4: Find lines that look like JSON and try to reconstruct
    if [[ -z "$extracted_json" ]]; then
        # Look for lines starting with { and try to find the complete JSON
        local json_start=$(grep -n '^{' "$output_file" | head -1 | cut -d: -f1)
        if [[ -n "$json_start" ]]; then
            # Try to extract from that line to end of file or next non-JSON line
            extracted_json=$(sed -n "${json_start},\$p" "$output_file" | head -200 | jq -c . 2>/dev/null || echo "")
        fi
    fi
    
    # Strategy 5: Use jq to parse the entire file and extract JSON
    if [[ -z "$extracted_json" ]]; then
        extracted_json=$(jq -c '{version, branchName, createdAt, updatedAt, userStories}' "$output_file" 2>/dev/null || echo "")
    fi
    
    # Strategy 6: Look for prd.json file content in the output
    if [[ -z "$extracted_json" ]]; then
        # Find the section that mentions prd.json and extract JSON after it
        local prd_section=$(grep -n "prd.json\|projects/editio/prd.json" "$output_file" | head -1 | cut -d: -f1)
        if [[ -n "$prd_section" ]]; then
            extracted_json=$(sed -n "${prd_section},\$p" "$output_file" | grep -oP '\{[^}]*"userStories"[^}]*\}' | head -1 || echo "")
        fi
    fi
    
    # If we found JSON, validate and write it
    if [[ -n "$extracted_json" ]]; then
        # Validate JSON structure
        if echo "$extracted_json" | jq -e '.userStories | type == "array"' >/dev/null 2>&1; then
            # Pretty print and write
            echo "$extracted_json" | jq '.' > "$target_json_file"
            return 0
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
