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
    # Check for 'agent' command (may be separate from cursor CLI)
    if command -v agent >/dev/null 2>&1; then
        return 0
    else
        # Check if cursor has agent subcommand
        if cursor agent --help >/dev/null 2>&1; then
            return 0
        else
            log "WARN" "Cursor Agent command not found. May need to use alternative approach."
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
    
    if ! check_cursor_cli; then
        return 1
    fi
    
    # Try agent command first
    if command -v agent >/dev/null 2>&1; then
        log "INFO" "Using 'agent' command"
        # Headless mode with print output
        agent -p --force "$prompt" "${files[@]}"
        return $?
    fi
    
    # Fallback: Try cursor with agent subcommand
    if cursor agent --help >/dev/null 2>&1; then
        log "INFO" "Using 'cursor agent' command"
        cursor agent -p --force "$prompt" "${files[@]}"
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
