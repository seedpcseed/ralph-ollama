#!/bin/bash
# lib/claude_cli.sh - Claude CLI Integration for Ralph 2.0
# Supports both API models and local Ollama models via Claude CLI

# Check if Claude CLI is available
check_claude_cli() {
    if command -v claude >/dev/null 2>&1; then
        log "INFO" "Claude CLI found: $(which claude)"
        return 0
    else
        log "WARN" "Claude CLI not found. Install from: npm install -g @anthropic-ai/claude"
        return 1
    fi
}

# Invoke Claude CLI with a prompt
# Usage: invoke_claude_cli "task description" [files...]
invoke_claude_cli() {
    local prompt=$1
    shift
    local files=("$@")
    
    # Check if Claude CLI is available
    if ! check_claude_cli 2>/dev/null; then
        log "ERROR" "Claude CLI not available"
        return 1
    fi
    
    # Build enhanced prompt with file contents (since --file requires session token)
    local enhanced_prompt="$prompt"
    
    # Include file contents in prompt if provided
    if [[ ${#files[@]} -gt 0 ]]; then
        enhanced_prompt+="\n\n## Files:\n"
        for file in "${files[@]}"; do
            if [[ -f "$file" ]]; then
                enhanced_prompt+="\n### File: $file\n\`\`\`\n$(cat "$file")\n\`\`\`\n"
            fi
        done
    fi
    
    # Build Claude CLI command
    # -p, --print: Non-interactive mode for automation
    # Note: We don't use --file because it requires CLAUDE_CODE_SESSION_ACCESS_TOKEN
    # Instead, we include file contents directly in the prompt
    local claude_cmd=(
        claude
        -p
        "$enhanced_prompt"
    )
    
    # Execute and capture output
    local output
    output=$("${claude_cmd[@]}" 2>&1)
    local exit_code=$?
    
    echo "$output"
    return $exit_code
}

# Invoke Claude CLI with message file
invoke_claude_cli_file() {
    local message_file=$1
    shift
    local files=("$@")
    
    if [[ ! -f "$message_file" ]]; then
        log "ERROR" "Message file not found: $message_file"
        return 1
    fi
    
    local prompt=$(cat "$message_file")
    invoke_claude_cli "$prompt" "${files[@]}"
    return $?
}

# Check if Claude CLI can use local Ollama models
# This requires Ollama v0.14.0+ and proper configuration
check_claude_local_support() {
    # Check Ollama version
    if ! command -v ollama >/dev/null 2>&1; then
        return 1
    fi
    
    local ollama_version
    ollama_version=$(ollama --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    
    # Check if version is >= 0.14.0
    if [[ -n "$ollama_version" ]]; then
        local major minor patch
        IFS='.' read -r major minor patch <<< "$ollama_version"
        if [[ $major -gt 0 ]] || [[ $major -eq 0 && $minor -ge 14 ]]; then
            return 0
        fi
    fi
    
    return 1
}

# Setup Claude CLI for local Ollama models
# Uses: ollama launch claude
setup_claude_local() {
    if ! check_claude_local_support; then
        log "ERROR" "Ollama v0.14.0+ required for Claude CLI local support"
        log "INFO" "Update Ollama: ollama update"
        return 1
    fi
    
    log "INFO" "Setting up Claude CLI with local Ollama models..."
    
    # Check if ollama launch claude is available
    if ollama launch claude --help >/dev/null 2>&1; then
        log "INFO" "Using 'ollama launch claude' for local model setup"
        # This will guide user through model selection
        ollama launch claude
        return $?
    else
        log "WARN" "'ollama launch claude' not available"
        log "INFO" "You may need to configure Claude CLI manually for local models"
        return 1
    fi
}

# Log function
log() {
    local level=$1
    shift
    echo "[$level] $*" >&2
}
