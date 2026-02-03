#!/bin/bash
# config.sh
# Ralph Configuration

# MODEL OPTIONS:
# - "claude" (default): Uses Claude API via Aider
# - "local": Uses local Ollama model
# - "hybrid": Claude for planning, local for implementation
MODE="${RALPH_MODE:-claude}"

# Model specifications
CLAUDE_MODEL="claude-sonnet-4-5"
LOCAL_MODEL="deepseek-coder:33b"  # or llama3, codestral, qwen2.5-coder
# LOCAL_MODEL="gpt-oss:120b"

# API Keys (only needed for claude mode)
export ANTHROPIC_API_KEY="${ANTHROPIC_API_KEY:-}"

# Aider settings
AIDER_AUTO_COMMITS=true
AIDER_NO_PRETTY=true

# Rate limiting (mainly for Claude API)
MAX_CALLS_PER_HOUR=100
AGENT_TIMEOUT_MINUTES=20

# Circuit breaker
MAX_CONSECUTIVE_FAILURES=3
CIRCUIT_BREAKER_COOLDOWN=300  # 5 minutes
