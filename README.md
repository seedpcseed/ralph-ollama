# Ralph - Autonomous AI Development Loop

Ralph is an autonomous development loop system that uses **Aider** with support for Claude API and local LLM models (via Ollama) to iteratively implement features from a PRD (Product Requirements Document).

## Key Features

- ✅ **Aider Integration** - Uses Aider for AI-powered code editing
- ✅ **Multiple Model Support** - Claude API, local Ollama models, or hybrid mode
- ✅ **Free Local Option** - Use local models for cost-free development
- ✅ **Full Feature Parity** - All original Ralph features included

## Quick Start

Clone or copy this repo, then:

```bash
# 1. Run setup (one-time)
./setup.sh

# 2. Create a new project
./new.sh my-feature

# 3. Edit your PRD
code projects/my-feature/prd.md

# 4. Convert PRD to JSON tasks (Aider + your chosen model)
./convert.sh my-feature
# Or with model: ./convert.sh my-feature --model local

# 5. Start the loop (with tmux monitoring)
# Claude mode (default; requires ANTHROPIC_API_KEY):
./start.sh my-feature --monitor

# Local mode (Ollama; script auto-starts Ollama and pulls model if needed):
./start.sh my-feature --model local

# Hybrid mode (Claude for priority 1–5, local for rest):
./start.sh my-feature --model hybrid
```

## Prerequisites

Run the setup script to install dependencies:

```bash
./setup.sh
```

This will install:
- **Aider** (`pip3 install aider-chat`) - Requires Python 3.10-3.12
- **jq** (JSON processor)
- **tmux** (optional, for monitoring)

### Python Version Requirements

Aider requires Python 3.10-3.12. If you're using Python 3.13, use one of these alternatives:

**Option 1: Use pipx (Recommended)**
```bash
pipx install aider-chat
```

**Option 2: Use uv**
```bash
uv pip install aider-chat
```

**Option 3: Use Python 3.12**
```bash
# Install pyenv
curl https://pyenv.run | bash

# Install Python 3.12
pyenv install 3.12
pyenv local 3.12

# Then run setup.sh
./setup.sh
```

## Model Options

Ralph supports three modes:

### 1. Claude API Mode (Default)
High-quality results using Anthropic's Claude API.

```bash
export ANTHROPIC_API_KEY='sk-ant-...'
./start.sh my-feature
```

**Pros**: Best quality, latest Claude models  
**Cons**: API costs, rate limits (100/hour default)

### 2. Local Ollama Mode
Free, privacy-preserving development with local models.

```bash
# Install Ollama first (see Prerequisites below)
# Then run - the script will auto-start Ollama and pull the model if needed:
./start.sh my-feature --model local
# Or: RALPH_MODE=local ./start.sh my-feature
```

**Pros**: Free, no rate limits, private, offline  
**Cons**: Requires hardware (GPU recommended), quality varies  

**Note**: If your network blocks Cloudflare R2 (e.g. corporate firewall), model pulls will fail. Use Claude mode or pull the model from another network (home, VPN), then run locally.

### 3. Hybrid Mode
Automatic: Claude for critical tasks (priority 1-5), local for others.

```bash
RALPH_MODE=hybrid ./start.sh my-feature
```

**Pros**: Balance of quality and cost  
**Cons**: Requires both Claude API and Ollama setup

## Recommended Local Models

For best coding results with Ollama:

- **DeepSeek Coder 33B** - Best quality (needs 24GB+ VRAM)
- **Codestral 22B** - Good balance (Mistral-based)
- **Qwen2.5 Coder 14B** - Recent, efficient
- **DeepSeek Coder 6.7B** - For smaller hardware (16GB RAM)

## Configuration

`config.sh` is loaded automatically by `start.sh` and `convert.sh` (you do not run it yourself). Edit it to change defaults:

```bash
# Model mode: claude, local, or hybrid
MODE="${RALPH_MODE:-claude}"

# Local model to use (for --model local)
LOCAL_MODEL="deepseek-coder:33b"

# Rate limiting
MAX_CALLS_PER_HOUR=100
AGENT_TIMEOUT_MINUTES=20
```

**Environment variables** (override config): `RALPH_MODE`, `ANTHROPIC_API_KEY`, `MAX_CALLS_PER_HOUR`, `AGENT_TIMEOUT_MINUTES`

## Commands

### `./new.sh <project-name>`
Create a new project from template.

```bash
./new.sh signals
# Creates: projects/signals/
```

### `./convert.sh <project-name> [options]`
Convert your PRD.md to actionable JSON tasks using Aider.

```bash
./convert.sh signals
./convert.sh signals --model local   # Use local Ollama model
./convert.sh signals --model claude # Use Claude API (default)
# Reads: projects/signals/prd.md
# Creates: projects/signals/prd.json, requirements.md
```

Options: `--model MODE` (claude, local, hybrid). Respects `RALPH_MODE` env var.

### `./start.sh <project-name> [options]`
Run the autonomous development loop.

```bash
# Without tmux (output directly in terminal)
./start.sh signals

# With tmux monitoring (recommended)
./start.sh signals --monitor

# Check status
./start.sh signals --status

# Reset circuit breaker if stuck
./start.sh signals --reset
```

Options:
- `-m, --monitor` - Start with tmux session and live monitor
- `-c, --calls NUM` - Max calls per hour (default: 100)
- `-t, --timeout MIN` - Agent timeout in minutes (default: 20)
- `--model MODE` - Model mode: claude, local, or hybrid (default: claude)
- `-s, --status` - Show project status and exit
- `-r, --reset` - Reset circuit breaker

### `./monitor.sh <project-name>`
Live status dashboard (auto-started with `--monitor`).

```bash
./monitor.sh signals
```

## Workflow

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│  1. Write PRD (prd.md)                                          │
│     Human-readable requirements document                        │
│                                                                 │
│  2. Convert to JSON (prd.json)                                  │
│     Aider (Claude or local Ollama) converts PRD into tasks     │
│                                                                 │
│  3. Ralph Loop                                                  │
│     ┌─────────────────────────────────────────────────────┐     │
│     │  Pick next story where passes=false                 │     │
│     │  ↓                                                  │     │
│     │  Generate prompt with story + context               │     │
│     │  ↓                                                  │     │
│     │  Run Aider (Claude API or local Ollama)             │     │
│     │  ↓                                                  │     │
│     │  Analyze response (check for edits/commits)         │     │
│     │  ↓                                                  │     │
│     │  If story complete: mark passes=true, commit        │     │
│     │  ↓                                                  │     │
│     │  If all done: exit                                  │     │
│     │  Else: loop back                                    │     │
│     └─────────────────────────────────────────────────────┘     │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## PRD JSON Format

The `prd.json` file has this structure:

```json
{
  "branchName": "ralph/feature-name",
  "userStories": [
    {
      "id": "1.1",
      "category": "functional",
      "story": "Short description of what to build",
      "steps": [
        "Step 1: What to do",
        "Step 2: Next action",
        "Step 3: How to verify"
      ],
      "acceptance": "Detailed acceptance criteria",
      "priority": 1,
      "passes": false,
      "notes": ""
    }
  ]
}
```

### Fields

| Field | Description |
|-------|-------------|
| `branchName` | Git branch Ralph will create/use for this feature |
| `id` | Story identifier (phase.sequence, e.g., "1.1", "2.3") |
| `category` | One of: `technical`, `functional`, `ui` |
| `story` | One-sentence description of what to build |
| `steps` | Actionable steps to complete the story |
| `acceptance` | Definition of "done" |
| `priority` | **Lower = do first** (1-10 MVP, 11-20 Phase 2, 21+ Phase 3) |
| `passes` | Set to `true` when story is complete |
| `notes` | Ralph fills this with learnings during implementation |

## tmux Controls

When running with `--monitor`:

| Keys | Action |
|------|--------|
| `Ctrl+B`, `D` | Detach (keeps running in background) |
| `Ctrl+B`, `←/→` | Switch between panes |
| `Ctrl+B`, `[` | Enter scroll mode (`q` to exit) |
| `tmux ls` | List sessions |
| `tmux attach -t ralph-<project>` | Reattach to session |

## Safety Features

- **Rate Limiting**: Max 100 calls/hour (configurable, mainly for Claude API)
- **Circuit Breaker**: Auto-stops after repeated failures
- **Exit Detection**: Stops when Aider signals completion
- **Branch Isolation**: Each feature runs on its own git branch

## Learnings System

Ralph has a two-tier learning system:

| File | Purpose | Lifetime |
|------|---------|----------|
| `progress.txt` | Session memory for Ralph | Per-project |
| `AGENTS.md` | Permanent docs for humans & future agents | Forever |

### progress.txt Structure

```markdown
## Codebase Patterns
- Migrations: Use IF NOT EXISTS
- Types: Export from actions.ts

## Key Files
- db/schema.ts
- app/auth/actions.ts
---
## 2024-01-15 - Story 1.1
- What was implemented
- **Learnings:** patterns discovered
```

### AGENTS.md Updates

Ralph updates `AGENTS.md` files in directories where it made changes:

✅ **Good additions:**
- "When modifying X, also update Y"
- "This module uses pattern Z"
- "Tests require dev server running"

❌ **Don't add:**
- Story-specific details
- Temporary notes

## Project Structure

```
.
├── new.sh          # Create new project
├── convert.sh      # PRD → JSON converter
├── start.sh        # Main loop
├── monitor.sh      # Status dashboard
├── setup.sh        # One-time setup
├── config.sh       # Configuration
├── lib/
│   ├── utils.sh
│   ├── circuit_breaker.sh
│   └── response_analyzer.sh
├── templates/
│   ├── PROMPT.md        # Standard prompt
│   ├── prd-template.md  # PRD template
│   └── prd-schema.json  # JSON example
└── projects/
    └── <your-projects>/
        ├── prd.md         # Your PRD
        ├── prd.json       # Generated tasks
        ├── progress.txt   # Progress log
        ├── status.json    # Current status
        ├── PROMPT.md      # Standard prompt
        └── logs/          # Execution logs
```

## Troubleshooting

### Circuit breaker opened
```bash
./start.sh <project> --status  # Check what happened
./start.sh <project> --reset   # Reset and continue
```

### Rate limit hit
Ralph automatically waits for the next hour. You can detach with `Ctrl+B, D` and come back later.

### Agent not responding
Check the logs in `projects/<project>/logs/` for details.

### Ollama model pull fails (connection reset / max retries)
Your network may block Cloudflare R2 (common on corporate networks). Options:
- Use Claude mode: `./start.sh <project> --model claude` (set `ANTHROPIC_API_KEY`)
- Pull the model from another network (home, VPN), then use local mode
- Ask IT to whitelist `*.r2.cloudflarestorage.com` and `ollama.com`

### Switching Models

**Claude API is the default** - requires `ANTHROPIC_API_KEY` environment variable.

To use local models:

1. Install Ollama:
   ```bash
   # Official script (macOS/Linux/WSL)
   curl -fsSL https://ollama.com/install.sh | sh
   
   # WSL Ubuntu manual (if script fails): install zstd, then:
   # curl -L https://github.com/ollama/ollama/releases/download/v0.15.4/ollama-linux-amd64.tar.zst -o /tmp/ollama.tar.zst
   # zstd -d /tmp/ollama.tar.zst -o /tmp/ollama.tar
   # sudo tar -xf /tmp/ollama.tar -C /usr/local/bin/
   ```

2. Run with local mode (Ollama is auto-started if not running; model is auto-pulled if missing):
   ```bash
   ./start.sh my-feature --model local
   # Or: RALPH_MODE=local ./start.sh my-feature
   ```

3. Or set default in `config.sh`: `MODE="local"`

**Corporate firewall**: If `ollama pull` fails with "connection reset" or "max retries exceeded", your network may block Cloudflare R2. Use Claude mode, or pull the model from another network (e.g. home or VPN), then use local mode.
