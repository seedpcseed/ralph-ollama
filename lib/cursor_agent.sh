#!/bin/bash
# lib/cursor_agent.sh - Cursor Agent Integration for Ralph 2.0
# Provides functions for invoking Cursor Agent programmatically

# Check if Cursor CLI is available
check_cursor_cli() {
    if command -v cursor >/dev/null 2>&1; then
        return 0
    else
        log "ERROR" "Cursor CLI not found. Install from https://cursor.com/cli"
        return 1
    fi
}

# Check if Cursor Agent command exists
check_cursor_agent() {
    # Check for 'agent' command (this is the Cursor Agent CLI)
    if command -v agent >/dev/null 2>&1; then
        log "INFO" "Cursor Agent CLI found: $(which agent)"
        return 0
    else
        # Check if cursor has agent subcommand
        if cursor agent --help >/dev/null 2>&1; then
            log "INFO" "Cursor Agent found via 'cursor agent' subcommand"
            return 0
        else
            log "WARN" "Cursor Agent command not found. Install from: curl https://cursor.com/install -fsS | bash"
            return 1
        fi
    fi
}

# Invoke Cursor Agent with a prompt
# Usage: invoke_cursor_agent "task description" [files...]
invoke_cursor_agent() {
    local prompt=$1
    shift
    local files=("$@")
    
    # Try agent command first (this is the Cursor Agent CLI)
    if command -v agent >/dev/null 2>&1; then
        log "INFO" "Using Cursor Agent CLI (agent command)"
        # Headless mode with print output and force flag for file modifications
        # -p, --print: Non-interactive mode for automation
        # --force: Allow file modifications in scripts
        if [[ ${#files[@]} -gt 0 ]]; then
            agent -p --force "$prompt" "${files[@]}"
        else
            agent -p --force "$prompt"
        fi
        return $?
    fi
    
    # Fallback: Try cursor with agent subcommand (if exists)
    if cursor agent --help >/dev/null 2>&1; then
        log "INFO" "Using 'cursor agent' command"
        if [[ ${#files[@]} -gt 0 ]]; then
            cursor agent -p --force "$prompt" "${files[@]}"
        else
            cursor agent -p --force "$prompt"
        fi
        return $?
    fi
    
    # If no agent command, log warning and return error
    log "ERROR" "Cursor Agent not available. Consider using Aider or local models instead."
    return 1
}

# Invoke Cursor Agent with message file (similar to Aider)
# Usage: invoke_cursor_agent_file "message_file.md" [files...]
invoke_cursor_agent_file() {
    local message_file=$1
    shift
    local files=("$@")
    
    if [[ ! -f "$message_file" ]]; then
        log "ERROR" "Message file not found: $message_file"
        return 1
    fi
    
    local prompt=$(cat "$message_file")
    invoke_cursor_agent "$prompt" "${files[@]}"
    return $?
}

# Log function
log() {
    local level=$1
    shift
    echo "[$level] $*" >&2
}
