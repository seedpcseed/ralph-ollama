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
# LOCAL_MODEL="deepseek-coder:33b"  # or llama3, codestral, qwen2.5-coder
# LOCAL_MODEL="gpt-oss:120b"

# Optional: different models for convert vs start (when unset, both use LOCAL_MODEL)
# Convert = PRD → prd.json + requirements.md (can use smaller/faster model if context fits)
# Start   = implementation loop (often benefits from larger model)
LOCAL_CONVERT_MODEL="codellama:latest"
LOCAL_START_MODEL="glm-4.7-flash:latest"  # 120B model too slow/hangs; using 33B for now

# API Keys (only needed for claude mode)
export ANTHROPIC_API_KEY="${ANTHROPIC_API_KEY:-}"

# Aider settings
AIDER_AUTO_COMMITS=true
AIDER_NO_PRETTY=true
# For testing: set AIDER_NO_GIT=true to avoid "file not found" / repo-map errors when
# files were deleted from disk but still in git. Set AIDER_AUTO_COMMITS=false to avoid
# commits on Ctrl+C or failed runs. Neither causes memory/context issues.
# export AIDER_NO_GIT=true
# export AIDER_AUTO_COMMITS=false

# Skip Aider's automatic lint-after-edit and "Attempt to fix lint errors?" (saves time
# with slow/local models; we run verification ourselves). For manual Aider, add --no-auto-lint.
# export AIDER_AUTO_LINT=true   # uncomment to let Aider run linters and offer to fix

# Rate limiting (mainly for Claude API)
MAX_CALLS_PER_HOUR=100
AGENT_TIMEOUT_MINUTES=20

# Ollama/LiteLLM: default request timeout is 600s. Aider uses LiteLLM; long prompts
# or slow models often exceed 600s. Set this so both start.sh and manual Aider
# runs get a longer timeout (start.sh also passes --timeout to aider).
# For manual runs: source this file first, or export before starting aider:
#   source config.sh   # or: export LITELLM_REQUEST_TIMEOUT=1200
#   aider --model ollama/... --timeout 1200 ...
export LITELLM_REQUEST_TIMEOUT="${LITELLM_REQUEST_TIMEOUT:-$((AGENT_TIMEOUT_MINUTES * 60))}"

# Circuit breaker
MAX_CONSECUTIVE_FAILURES=3
CIRCUIT_BREAKER_COOLDOWN=300  # 5 minutes
