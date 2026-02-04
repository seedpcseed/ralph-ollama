# Ralph + Aider Integration: Implementation Guide

## Executive Summary

This document provides complete instructions for modifying the Ralph autonomous development loop to use **Aider** with support for both Claude API and local LLM models via Ollama.

**Current State**: Ralph uses Cursor Agent (built-in with Cursor IDE, free, no limits)

**Target State**: Ralph uses Aider, supporting:
- Claude API mode (paid, high quality)
- Local Ollama mode (free, privacy-preserving)
- Hybrid mode (Claude for critical tasks, local for others)

**Why**: Enable cost-free autonomous development with local models while maintaining option for Claude API quality when needed.

---

## Background: What is Ralph?

Ralph is an autonomous development loop that implements software features from PRD (Product Requirements Document) files:

1. **Human writes PRD** (`prd.md`) - Natural language requirements
2. **AI converts to tasks** (`prd.json`) - Structured user stories with acceptance criteria
3. **Autonomous loop executes**:
   - Pick next incomplete story (where `passes=false`)
   - Generate prompt with story + context
   - Run AI agent to implement
   - Analyze response for completion
   - Mark complete (`passes=true`) and commit
   - Repeat until all done

**Key files**:
- `prd.json` - Source of truth (user stories with pass/fail status)
- `progress.txt` - Session memory and learnings
- `start.sh` - Main loop orchestration
- `AGENTS.md` - Permanent documentation for future agents

---

## What is Aider?

Aider is a CLI tool that gives AI models file editing and git capabilities:
- Works with Claude API, OpenAI API, or local Ollama models
- Built-in file operations (create, edit, delete)
- Git integration (auto-commits)
- Battle-tested by thousands of developers
- Perfect drop-in replacement for Cursor Agent

**Installation**: `pip install aider-chat`

---

## What is jq?

jq is a command-line JSON processor used extensively by Ralph to manipulate `prd.json`:

```bash
# Find incomplete stories
jq '.userStories[] | select(.passes == false)' prd.json

# Mark story complete
jq --arg id "1.2" '.userStories |= map(if .id == $id then .passes = true else . end)' prd.json
```

**Installation**: `brew install jq` (macOS) or `apt-get install jq` (Linux)

---

## Implementation Tasks

### Task 1: Create Configuration File

**File**: `ralph/config.sh` (new file)

**Purpose**: Centralize configuration for model selection and settings

```bash
#!/bin/bash
# ralph/config.sh
# Ralph Configuration

# MODEL OPTIONS:
# - "claude" (default): Uses Claude API via Aider
# - "local": Uses local Ollama model
# - "hybrid": Claude for planning, local for implementation
MODE="${RALPH_MODE:-claude}"

# Model specifications
CLAUDE_MODEL="claude-sonnet-4-5"
LOCAL_MODEL="deepseek-coder:33b"  # or llama3, codestral, qwen2.5-coder

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
```

---

### Task 2: Modify start.sh

**File**: `ralph/start.sh` (major modifications)

**Changes**:
1. Source the new config file
2. Add `setup_aider()` function to configure model based on mode
3. Replace Cursor Agent calls with Aider calls
4. Add model selection logic for hybrid mode
5. Update command construction for Aider syntax

**Key additions**:

```bash
# At top of file, after sourcing other libs
source "$SCRIPT_DIR/config.sh"  # Load configuration

# Add this function after option parsing
setup_aider() {
    local mode=$1
    
    case $mode in
        claude)
            if [ -z "$ANTHROPIC_API_KEY" ]; then
                echo "Error: ANTHROPIC_API_KEY not set for Claude mode"
                exit 1
            fi
            AIDER_MODEL="anthropic/claude-sonnet-4-5"
            echo "Using Claude Sonnet 4.5 via API"
            ;;
        local)
            # Check if Ollama is running
            if ! curl -s http://localhost:11434/api/tags >/dev/null 2>&1; then
                echo "Error: Ollama not running. Start with: ollama serve"
                exit 1
            fi
            AIDER_MODEL="ollama/$LOCAL_MODEL"
            echo "Using local model: $LOCAL_MODEL"
            ;;
        hybrid)
            AIDER_MODEL="hybrid"  # Will be set per-story
            echo "Using hybrid mode: Claude for priority 1-5, local for others"
            ;;
        *)
            echo "Error: Unknown mode '$mode'. Use: claude, local, or hybrid"
            exit 1
            ;;
    esac
}

setup_aider "$MODE"

# In main loop, replace Cursor Agent execution with:

    # Select model for hybrid mode
    if [ "$MODE" = "hybrid" ]; then
        if [ "$STORY_PRIORITY" -le 5 ]; then
            AIDER_MODEL="anthropic/claude-sonnet-4-5"
            echo "   Using Claude (high priority)"
        else
            AIDER_MODEL="ollama/$LOCAL_MODEL"
            echo "   Using local model (lower priority)"
        fi
    fi
    
    # Generate prompt
    PROMPT_FILE="$PROJECT_DIR/.ralph_current_prompt.md"
    generate_prompt "$PROJECT_DIR" "$STORY_JSON" > "$PROMPT_FILE"
    
    # Run Aider (replaces old agent call)
    echo "🤖 Running Aider..."
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    LOG_FILE="$PROJECT_DIR/logs/${TIMESTAMP}_story_${STORY_ID}.log"
    
    AIDER_CMD=(
        aider
        --model "$AIDER_MODEL"
        --yes
        --message-file "$PROMPT_FILE"
    )
    
    if [ "$AIDER_AUTO_COMMITS" = true ]; then
        AIDER_CMD+=(--auto-commits --commit)
    fi
    
    if [ "$AIDER_NO_PRETTY" = true ]; then
        AIDER_CMD+=(--no-pretty)
    fi
    
    # Execute with timeout
    RESPONSE=""
    EXIT_CODE=0
    
    if timeout "${AGENT_TIMEOUT_MINUTES}m" "${AIDER_CMD[@]}" > "$LOG_FILE" 2>&1; then
        RESPONSE=$(cat "$LOG_FILE")
        EXIT_CODE=0
    else
        EXIT_CODE=$?
        RESPONSE=$(cat "$LOG_FILE")
        echo "⚠️  Aider timed out or failed (exit code: $EXIT_CODE)"
    fi
```

**Add --model option parsing** in the options section:

```bash
while [[ $# -gt 1 ]]; do
    case $2 in
        -m|--monitor) MONITOR=true ;;
        -s|--status) SHOW_STATUS=true ;;
        -r|--reset) RESET_BREAKER=true ;;
        --model) MODE="$3"; shift ;;  # ADD THIS LINE
        *) echo "Unknown option: $2"; exit 1 ;;
    esac
    shift
done
```

---

### Task 3: Update Response Analyzer

**File**: `ralph/lib/response_analyzer.sh` (modify existing)

**Purpose**: Recognize Aider-specific completion signals instead of Cursor Agent signals

Replace the `analyze_response()` function:

```bash
#!/bin/bash
# ralph/lib/response_analyzer.sh - Updated for Aider

analyze_response() {
    local response="$1"
    local story_id="$2"
    
    # Aider completion signals:
    # 1. "Applied edit to <file>" - file was modified
    # 2. "Commit <hash>" - changes were committed
    # 3. No errors/warnings about unable to complete
    # 4. Exit code 0
    
    local has_edits=false
    local has_commit=false
    local has_errors=false
    
    # Check for file edits
    if echo "$response" | grep -q "Applied edit to\|Created\|Modified"; then
        has_edits=true
    fi
    
    # Check for git commit
    if echo "$response" | grep -q "Commit [0-9a-f]\{7\}"; then
        has_commit=true
    fi
    
    # Check for error signals
    if echo "$response" | grep -qi "error\|failed\|cannot\|unable to"; then
        has_errors=true
    fi
    
    # Also check for explicit completion signals
    local has_completion_signal=false
    if echo "$response" | grep -qi "task complete\|story complete\|implementation complete"; then
        has_completion_signal=true
    fi
    
    # Decision logic
    if [ "$has_errors" = true ]; then
        echo "❌ Errors detected in response"
        return 1
    fi
    
    if [ "$has_edits" = true ] || [ "$has_commit" = true ] || [ "$has_completion_signal" = true ]; then
        echo "✅ Success indicators found"
        return 0
    fi
    
    echo "⚠️  No clear success indicators"
    return 1
}

append_to_progress() {
    local project_dir="$1"
    local story_id="$2"
    local response="$3"
    
    local progress_file="$project_dir/progress.txt"
    local timestamp=$(date "+%Y-%m-%d %H:%M")
    
    # Extract learnings from response (Aider often explains what it did)
    local summary=$(echo "$response" | grep -A 5 "Applied edit\|Created\|Modified" | head -10)
    
    cat >> "$progress_file" <<EOF

---
## $timestamp - Story $story_id
$summary

EOF
}
```

---

### Task 4: Add Utility Functions

**File**: `ralph/lib/utils.sh` (add these functions)

**Purpose**: Helper functions for prompt generation and rate limiting

Add to the end of the file:

```bash
generate_prompt() {
    local project_dir="$1"
    local story_json="$2"
    
    local story_id=$(echo "$story_json" | jq -r '.id')
    local story_text=$(echo "$story_json" | jq -r '.story')
    local steps=$(echo "$story_json" | jq -r '.steps | join("\n")')
    local acceptance=$(echo "$story_json" | jq -r '.acceptance')
    
    # Read progress for context
    local progress=""
    if [ -f "$project_dir/progress.txt" ]; then
        progress=$(tail -50 "$project_dir/progress.txt")
    fi
    
    cat <<EOF
# Implementation Task: Story $story_id

## Story
$story_text

## Steps
$steps

## Acceptance Criteria
$acceptance

## Recent Progress
$progress

## Instructions
1. Implement this story completely
2. Follow the steps provided
3. Ensure acceptance criteria are met
4. Write clean, tested code
5. When complete, respond with "Task complete" or "Story complete"

Begin implementation now.
EOF
}

check_rate_limit() {
    local project_dir="$1"
    local max_per_hour="$2"
    local state_file="$project_dir/.ralph_rate_limit"
    
    # Simple rate limiting based on call count
    local current_hour=$(date +%Y%m%d%H)
    
    if [ -f "$state_file" ]; then
        local stored_hour=$(head -1 "$state_file")
        local call_count=$(tail -1 "$state_file")
        
        if [ "$stored_hour" = "$current_hour" ]; then
            if [ "$call_count" -ge "$max_per_hour" ]; then
                echo "⏸️  Rate limit reached ($call_count/$max_per_hour calls this hour)"
                echo "   Waiting for next hour..."
                sleep 3600
                echo "$current_hour" > "$state_file"
                echo "0" >> "$state_file"
            else
                echo "$stored_hour" > "$state_file"
                echo "$((call_count + 1))" >> "$state_file"
            fi
        else
            # New hour
            echo "$current_hour" > "$state_file"
            echo "1" >> "$state_file"
        fi
    else
        echo "$current_hour" > "$state_file"
        echo "1" >> "$state_file"
    fi
}
```

---

### Task 5: Create Setup Script

**File**: `ralph/setup.sh` (new file)

**Purpose**: One-time setup and validation

```bash
#!/bin/bash
# ralph/setup.sh - One-time setup

echo "Ralph + Aider Setup"
echo "==================="

# Check Python
if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 not found. Install Python 3.8+."
    exit 1
fi

echo "✅ Python 3 found"

# Install Aider
echo ""
echo "Installing Aider..."
pip3 install aider-chat

if ! command -v aider &> /dev/null; then
    echo "❌ Aider installation failed"
    exit 1
fi

echo "✅ Aider installed"

# Check for API key (optional for local mode)
echo ""
if [ -z "$ANTHROPIC_API_KEY" ]; then
    echo "⚠️  ANTHROPIC_API_KEY not set"
    echo "   For Claude mode, set it with:"
    echo "   export ANTHROPIC_API_KEY='your-key-here'"
    echo "   Or add to ~/.bashrc or ~/.zshrc"
else
    echo "✅ ANTHROPIC_API_KEY found"
fi

# Check Ollama (optional for local mode)
echo ""
if command -v ollama &> /dev/null; then
    echo "✅ Ollama installed"
    
    if curl -s http://localhost:11434/api/tags >/dev/null 2>&1; then
        echo "✅ Ollama server running"
        
        # List available models
        echo ""
        echo "Available models:"
        ollama list
    else
        echo "⚠️  Ollama not running. Start with: ollama serve"
    fi
else
    echo "⚠️  Ollama not installed"
    echo "   For local mode, install from: https://ollama.ai"
fi

# Check jq
echo ""
if command -v jq &> /dev/null; then
    echo "✅ jq installed"
else
    echo "❌ jq not found. Install with:"
    echo "   macOS: brew install jq"
    echo "   Linux: apt-get install jq"
    exit 1
fi

echo ""
echo "Setup complete! 🎉"
echo ""
echo "Quick start:"
echo "  1. Create project:    ./ralph/new.sh my-feature"
echo "  2. Edit PRD:          code ralph/projects/my-feature/prd.md"
echo "  3. Convert:           ./ralph/convert.sh my-feature"
echo "  4. Run (Claude):      ./ralph/start.sh my-feature"
echo "  5. Run (local):       RALPH_MODE=local ./ralph/start.sh my-feature"
```

Make executable: `chmod +x ralph/setup.sh`

---

### Task 6: Update Documentation

**File**: `ralph/README.md` (update existing)

Add section after "Prerequisites":

```markdown
## Model Options

Ralph now supports three modes:

### 1. Claude API Mode (Default)
High-quality results using Anthropic's Claude API.

```bash
export ANTHROPIC_API_KEY='sk-ant-...'
./ralph/start.sh my-feature
```

**Pros**: Best quality, latest Claude models
**Cons**: API costs, rate limits (100/hour default)

### 2. Local Ollama Mode
Free, privacy-preserving development with local models.

```bash
# Start Ollama server
ollama serve

# Pull a model
ollama pull deepseek-coder:33b

# Run Ralph with local model
RALPH_MODE=local ./ralph/start.sh my-feature
```

**Pros**: Free, no rate limits, private, offline
**Cons**: Requires hardware (GPU recommended), quality varies

### 3. Hybrid Mode
Automatic: Claude for critical tasks (priority 1-5), local for others.

```bash
RALPH_MODE=hybrid ./ralph/start.sh my-feature
```

**Pros**: Balance of quality and cost
**Cons**: Requires both Claude API and Ollama setup

## Recommended Local Models

For best coding results with Ollama:

- **DeepSeek Coder 33B** - Best quality (needs 24GB+ VRAM)
- **Codestral 22B** - Good balance (Mistral-based)
- **Qwen2.5 Coder 14B** - Recent, efficient
- **DeepSeek Coder 6.7B** - For smaller hardware (16GB RAM)
```

---

## Testing Plan

### Phase 1: Setup Validation

```bash
# 1. Install dependencies
./ralph/setup.sh

# Verify:
# - Python 3 installed
# - Aider installed (aider --version)
# - jq installed (jq --version)
# - Ollama installed for local mode (ollama --version)
```

### Phase 2: Test with Claude API

```bash
# 1. Set API key
export ANTHROPIC_API_KEY='your-key-here'

# 2. Create test project
./ralph/new.sh test-calc

# 3. Create simple PRD
cat > ralph/projects/test-calc/prd.md <<'EOF'
# Calculator App

Build a simple Python calculator.

## Stories
1. Create calculator.py with add and subtract functions
2. Add multiply and divide functions
3. Add error handling for division by zero
EOF

# 4. Convert PRD
./ralph/convert.sh test-calc

# 5. Run with Claude
./ralph/start.sh test-calc --monitor

# 6. Verify:
# - Stories execute sequentially
# - Files are created (calculator.py)
# - Git commits happen automatically
# - progress.txt is updated
# - Stories marked passes=true in prd.json
```

### Phase 3: Test with Local Model

```bash
# 1. Start Ollama (in separate terminal)
ollama serve

# 2. Pull model
ollama pull deepseek-coder:6.7b  # Start with smaller model

# 3. Run same project with local
RALPH_MODE=local ./ralph/start.sh test-calc --monitor

# 4. Verify same behaviors as Claude mode
```

### Phase 4: Test Hybrid Mode

```bash
# 1. Create project with mixed priorities
cat > ralph/projects/test-hybrid/prd.json <<'EOF'
{
  "branchName": "ralph/test-hybrid",
  "userStories": [
    {
      "id": "1.1",
      "story": "Critical feature",
      "priority": 1,
      "passes": false
    },
    {
      "id": "1.2", 
      "story": "Low priority feature",
      "priority": 10,
      "passes": false
    }
  ]
}
EOF

# 2. Run hybrid mode
RALPH_MODE=hybrid ./ralph/start.sh test-hybrid --monitor

# 3. Verify:
# - Story 1.1 uses Claude (check logs)
# - Story 1.2 uses local model (check logs)
```

### Phase 5: Error Handling Tests

```bash
# Test circuit breaker
# - Force a few failures by creating impossible tasks
# - Verify circuit breaker opens
# - Verify --reset flag works

# Test rate limiting
# - Set MAX_CALLS_PER_HOUR=2 in config.sh
# - Verify rate limit triggers
# - Verify wait behavior

# Test timeout
# - Set AGENT_TIMEOUT_MINUTES=1
# - Create complex task
# - Verify timeout triggers
```

---

## File Checklist

After implementation, verify these files exist/are modified:

- [x] **ralph/config.sh** - New configuration file
- [x] **ralph/setup.sh** - New setup script (make executable)
- [x] **ralph/start.sh** - Modified with Aider integration
- [x] **ralph/lib/response_analyzer.sh** - Modified for Aider signals
- [x] **ralph/lib/utils.sh** - Added generate_prompt() and check_rate_limit()
- [x] **ralph/README.md** - Updated with model options documentation

---

## Usage Examples

### Quick Start - Claude API

```bash
./ralph/setup.sh
export ANTHROPIC_API_KEY='sk-ant-...'
./ralph/new.sh my-feature
# Edit ralph/projects/my-feature/prd.md
./ralph/convert.sh my-feature
./ralph/start.sh my-feature --monitor
```

### Quick Start - Local Model

```bash
./ralph/setup.sh
ollama serve &  # In background
ollama pull deepseek-coder:33b
./ralph/new.sh my-feature
# Edit ralph/projects/my-feature/prd.md
./ralph/convert.sh my-feature
RALPH_MODE=local ./ralph/start.sh my-feature --monitor
```

### Switch Models Mid-Project

```bash
# Start with local
RALPH_MODE=local ./ralph/start.sh my-feature

# Later, use Claude for difficult stories
# Edit config.sh or use environment variable
RALPH_MODE=claude ./ralph/start.sh my-feature
```

### Permanent Configuration

```bash
# Edit ralph/config.sh to set default
MODE="local"  # or "claude" or "hybrid"
LOCAL_MODEL="qwen2.5-coder:14b"  # your preferred model

# Then just run without RALPH_MODE variable
./ralph/start.sh my-feature
```

---

## Troubleshooting Guide

### "Ollama not running"
```bash
# Solution: Start Ollama server
ollama serve

# Or run in background
ollama serve > /dev/null 2>&1 &
```

### "ANTHROPIC_API_KEY not set"
```bash
# Solution: Export API key
export ANTHROPIC_API_KEY='sk-ant-...'

# Or add to ~/.bashrc / ~/.zshrc for persistence
echo 'export ANTHROPIC_API_KEY="sk-ant-..."' >> ~/.bashrc
```

### "aider: command not found"
```bash
# Solution: Install Aider
pip3 install aider-chat

# Or run setup script
./ralph/setup.sh
```

### "jq: command not found"
```bash
# macOS
brew install jq

# Ubuntu/Debian
sudo apt-get install jq
```

### Model quality issues with local
```bash
# Try larger models
ollama pull deepseek-coder:33b  # Instead of 6.7b

# Or switch to Claude for difficult stories
RALPH_MODE=hybrid ./ralph/start.sh project
```

### Aider not making changes
```bash
# Check the log files
cat ralph/projects/my-feature/logs/*.log

# Verify Aider can access files
cd ralph/projects/my-feature
aider --message "Create test.txt with 'hello'"
```

---

## Success Criteria

After implementation, Ralph should:

1. ✅ Support three modes: claude, local, hybrid
2. ✅ Use Aider instead of Cursor Agent
3. ✅ Work with local Ollama models without API costs
4. ✅ Maintain backward compatibility (Claude API still works)
5. ✅ Preserve all existing features (circuit breaker, rate limiting, monitoring)
6. ✅ Generate same quality output (files created, tests pass)
7. ✅ Update prd.json correctly (mark stories complete)
8. ✅ Create proper git commits
9. ✅ Log execution properly
10. ✅ Handle errors gracefully

---

## Additional Notes

### Why Aider vs Building Custom Wrapper

- **Aider is production-ready**: Thousands of users, well-tested
- **Built-in file tools**: No need to parse LLM output and execute manually
- **Git integration**: Auto-commits match Ralph's expectations
- **Active development**: Regular updates and improvements
- **Community support**: Large user base for help

### Performance Expectations

**Claude API mode**:
- Speed: 10-30 seconds per story
- Quality: Highest, first-time success rate ~80%+
- Cost: ~$0.50-2.00 per story

**Local mode (DeepSeek Coder 33B)**:
- Speed: 20-60 seconds per story (depends on hardware)
- Quality: Good, first-time success rate ~60-70%
- Cost: $0 (free after hardware investment)

**Hybrid mode**:
- Best of both: Quality where needed, cost-free for routine tasks
- Average: ~$0.10-0.50 per story (much cheaper than all-Claude)

### Hardware Requirements for Local

**Minimum**:
- 16GB RAM
- CPU-only (slow but works)
- Model: deepseek-coder:6.7b or qwen2.5-coder:7b

**Recommended**:
- 32GB RAM
- GPU with 16GB+ VRAM (RTX 4080, A4000, etc.)
- Model: deepseek-coder:33b or codestral:22b

**Optimal**:
- 64GB RAM
- GPU with 24GB+ VRAM (RTX 4090, A5000, etc.)
- Model: deepseek-coder:33b or qwen2.5-coder:32b

---

## End of Document

This guide provides complete instructions for implementing Aider integration into Ralph with support for local LLM models via Ollama. Follow the tasks sequentially, test each phase, and verify the success criteria.

**Next Steps**: 
1. Run `./ralph/setup.sh` after implementation
2. Test with a simple project in Claude mode
3. Test with same project in local mode
4. Deploy to production projects