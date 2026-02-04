#!/bin/bash
# lib/ollama_agent.sh - Direct Ollama API integration for Ralph 2.0
# Alternative to Aider for local models - uses Ollama API directly

# Invoke Ollama API for code generation
# Usage: invoke_ollama_agent "prompt" "model" [files...]
invoke_ollama_agent() {
    local prompt=$1
    local model=$2
    shift 2
    local files=("$@")
    
    # Check if Ollama is running
    if ! curl -s http://localhost:11434/api/tags >/dev/null 2>&1; then
        log "ERROR" "Ollama not running. Start with: ollama serve"
        return 1
    fi
    
    # Check if model is available
    if ! curl -s http://localhost:11434/api/tags | jq -e ".models[] | select(.name == \"$model\")" >/dev/null 2>&1; then
        log "ERROR" "Model '$model' not available. Pull with: ollama pull $model"
        return 1
    fi
    
    # Read file contents if provided
    local file_context=""
    if [[ ${#files[@]} -gt 0 ]]; then
        file_context="\n\n## Files to edit:\n"
        for file in "${files[@]}"; do
            if [[ -f "$file" ]]; then
                file_context+="\n### $file\n\`\`\`\n$(cat "$file")\n\`\`\`\n"
            fi
        done
    fi
    
    # Build full prompt
    local full_prompt="${prompt}${file_context}"
    
    # Call Ollama API
    local response
    response=$(curl -s http://localhost:11434/api/generate \
        -d "{
            \"model\": \"$model\",
            \"prompt\": $(jq -Rs . <<< "$full_prompt"),
            \"stream\": false,
            \"options\": {
                \"temperature\": 0.2,
                \"top_p\": 0.9
            }
        }" | jq -r '.response')
    
    if [[ -z "$response" ]]; then
        log "ERROR" "Ollama API call failed"
        return 1
    fi
    
    # Output response
    echo "$response"
    return 0
}

# Invoke Ollama with message file
invoke_ollama_agent_file() {
    local message_file=$1
    local model=$2
    shift 2
    local files=("$@")
    
    if [[ ! -f "$message_file" ]]; then
        log "ERROR" "Message file not found: $message_file"
        return 1
    fi
    
    local prompt=$(cat "$message_file")
    invoke_ollama_agent "$prompt" "$model" "${files[@]}"
    return $?
}

# Log function
log() {
    local level=$1
    shift
    echo "[$level] $*" >&2
}
