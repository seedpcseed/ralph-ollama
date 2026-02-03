# Ralph - Autonomous AI Development Loop

Ralph is an autonomous development loop system that uses **Aider** with support for Claude API and local LLM models (via Ollama) to iteratively implement features from a PRD (Product Requirements Document).

## Key Features

- ✅ **Aider Integration** - Uses Aider for AI-powered code editing
- ✅ **Multiple Model Support** - Claude API, local Ollama models, or hybrid mode
- ✅ **Free Local Option** - Use local models for cost-free development
- ✅ **Full Feature Parity** - All original Ralph features included

## Quick Start

To add Ralph to your existing project, copy the entire `ralph` directory into your repo:

```bash
cp -r path/to/ralph your-project/
```

Or if you are starting from this repo, clone and copy:

```bash
git clone https://github.com/danielsinewe/ralph-cursor.git
cp -r ralph-cursor your-project/ralph
```


```bash
# 1. Run setup (one-time)
./setup.sh

# 2. Create a new project
./new.sh my-feature

# 3. Edit your PRD
code projects/my-feature/prd.md

# 4. Convert PRD to JSON tasks
./convert.sh my-feature

# 5. Start the loop (with tmux monitoring)
# Claude mode (default):
./start.sh my-feature --monitor

# Local mode:
RALPH_MODE=local ./start.sh my-feature --monitor

# Hybrid mode:
RALPH_MODE=hybrid ./start.sh my-feature --monitor
```

## Prerequisites

Run the setup script to install dependencies:

```bash
./setup.sh
```

This will install:
- **Aider** (`pip3 install aider-chat`)
- **jq** (JSON processor)
- **tmux** (optional, for monitoring)

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
# Start Ollama server
ollama serve

# Pull a model
ollama pull deepseek-coder:33b

# Run Ralph with local model
RALPH_MODE=local ./start.sh my-feature
```

**Pros**: Free, no rate limits, private, offline  
**Cons**: Requires hardware (GPU recommended), quality varies

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

Edit `config.sh` to customize settings:

```bash
# Model mode: claude, local, or hybrid
MODE="${RALPH_MODE:-claude}"

# Local model to use
LOCAL_MODEL="deepseek-coder:33b"

# Rate limiting
MAX_CALLS_PER_HOUR=100
AGENT_TIMEOUT_MINUTES=20
```

## Commands

### `./new.sh <project-name>`
Create a new project from template.

```bash
./new.sh signals
# Creates: projects/signals/
```

### `./convert.sh <project-name>`
Convert your PRD.md to actionable JSON tasks using Aider.

```bash
./convert.sh signals
# Reads: projects/signals/prd.md
# Creates: projects/signals/prd.json
```

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
./ralph/monitor.sh signals
```

## Workflow

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│  1. Write PRD (prd.md)                                          │
│     Human-readable requirements document                        │
│                                                                 │
│  2. Convert to JSON (prd.json)                                  │
│     Cursor Agent (or Claude) breaks down PRD into tasks        │
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

- **Rate Limiting**: Max 100 calls/hour (configurable, mainly for Claude Code)
- **Circuit Breaker**: Auto-stops after repeated failures
- **Exit Detection**: Stops when Agent signals completion
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

### Switching Models

**Claude API is the default** - requires `ANTHROPIC_API_KEY` environment variable.

To use local models:

1. Install Ollama:
   ```bash
   # macOS/Linux
   curl -fsSL https://ollama.ai/install.sh | sh
   ```

2. Start Ollama server:
   ```bash
   ollama serve
   ```

3. Pull a model:
   ```bash
   ollama pull deepseek-coder:33b
   ```

4. Run with local mode:
   ```bash
   RALPH_MODE=local ./start.sh my-feature
   ```

Or edit `config.sh` to set `MODE="local"` as default.
