# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What is Ralph-Ollama?

Ralph-Ollama is an autonomous development loop system that uses local Ollama models to iteratively implement features from a PRD (Product Requirements Document). It's a bash-based system that:
1. Converts markdown PRDs into structured JSON tasks
2. Runs an autonomous loop where an LLM implements each task
3. Extracts code from LLM responses and writes it to files
4. Verifies implementations before marking stories complete
5. Auto-commits completed work to git

## Essential Commands

### Create a New Project
```bash
./new.sh <project-name>
# Creates project structure in projects/<project-name>/
```

### Convert PRD to JSON Tasks
```bash
./convert.sh <project-name> [model]
# Default model: llama3.1:latest
# Reads prd.md, generates prd.json with structured user stories
```

### Run the Ralph Loop
```bash
# Basic run
./start.sh <project-name>

# With monitoring (recommended)
./start.sh <project-name> --monitor

# Specify model
./start.sh <project-name> --model deepseek-coder:latest

# Check status
./start.sh <project-name> --status

# Reset circuit breaker after failures
./start.sh <project-name> --reset
```

### Monitor Progress
```bash
./monitor.sh <project-name>
# Live dashboard showing progress, completed stories, recent logs
```

### Testing During Development
When working on the ralph-ollama system itself (not a project):
- Test PRD conversion: `./convert.sh <test-project> <model>`
- Test loop iteration: `./start.sh <test-project> --model <model>`
- Inspect logs: `ls -lht projects/<project>/logs/`
- Check story status: `jq '.userStories[] | {id, passes, story}' projects/<project>/prd.json`

## Architecture

### Core Loop Flow (start.sh)
1. **Rate Limiting**: Checks call count (default 100/hour)
2. **Circuit Breaker**: Stops after 5 consecutive failures
3. **Get Next Story**: Queries prd.json for first incomplete story (passes=false)
4. **Build Prompt**: Combines story details, progress.txt learnings, existing files, PROMPT.md template
5. **Call Ollama**: Runs model with timeout (default 20min)
6. **Apply Response**: Extracts code blocks from response and writes to project files
7. **Analyze Response**: Checks for STATUS: COMPLETE/INCOMPLETE markers
8. **Verify**: Runs verification command if defined (optional)
9. **Mark Complete**: Updates prd.json passes=true, commits to git
10. **Loop**: Continues until all stories complete or circuit breaker opens

### Key Components

**lib/utils.sh**: Core utilities
- `get_next_story()`: Finds next incomplete story sorted by priority
- `mark_story_complete()`: Updates prd.json
- `build_ollama_prompt()`: Constructs full prompt with context
- `trim_progress_file()`: Prevents "argument list too long" errors

**lib/response_applier.sh**: Code extraction
- Parses model responses for code blocks
- Supports two formats:
  - ` ```path/to/file.ext` (path in fence)
  - ` ```python\n# File: path/to/file.ext`
- Writes code to project directory

**lib/verification.sh**: Test runner
- Runs `verify` field from story JSON
- Parses `RUN "command"` from acceptance criteria
- Falls back to project verify.sh script
- Language detection: auto-detects Python/Rust/Go/Node projects
- Failure categorization: syntax_error, import_error, api_error, missing_file, etc.

**lib/circuit_breaker.sh**: Safety mechanism
- Opens after 5 consecutive failures
- Auto-resets after 1 hour
- Prevents infinite loops on stuck stories

**lib/response_analyzer.sh**: Status detection
- Extracts STATUS: COMPLETE/INCOMPLETE markers
- Parses LEARNINGS sections
- Validates completion claims

**convert.sh**: PRD conversion
- Uses Ollama to convert markdown PRD to JSON
- Extracts JSON from model output (handles markdown wrapping)
- Validates against expected schema (branchName, userStories array)
- Repairs common model output issues (missing closing braces)

### Prompt Engineering

**templates/PROMPT.md**: Base instructions for models
- Explains file writing format (code blocks with paths)
- Defines STATUS markers
- Emphasizes autonomous decision-making

**Project-specific PROMPT.md**: Each project gets a copy that can be customized

**Context provided to model**:
- Current project files (up to 60 files)
- Project structure from PRD (Architecture section)
- Current story details (id, description, steps, acceptance)
- Recent learnings from progress.txt (last 15 lines, max 1000 chars)
- PROMPT.md instructions

### Progress Tracking

**progress.txt**: Learning journal
- Records learnings from STATUS: COMPLETE responses
- Used in future prompts to inform next iterations
- Auto-trimmed when >50KB (keeps header + last 50 lines)

**status.json**: Current state
```json
{
  "status": "running|completed",
  "loop_count": 5,
  "completed_stories": 3,
  "last_updated": "2024-02-02T10:30:00Z"
}
```

**logs/**: Detailed execution logs
- `session_*.log`: Overall session events
- `loop_*_*.log`: Individual loop iterations
- `response_*.txt`: Raw model outputs
- `prompt_*.txt`: Prompts sent to model

### Project Structure

```
ralph-ollama/
├── start.sh              # Main loop
├── convert.sh            # PRD → JSON converter
├── new.sh                # Project scaffolding
├── monitor.sh            # Live dashboard
├── review-session.sh     # Session analysis
├── lib/
│   ├── utils.sh          # Core utilities
│   ├── circuit_breaker.sh
│   ├── response_analyzer.sh
│   ├── response_applier.sh
│   └── verification.sh
├── templates/
│   ├── prd-template.md   # PRD template
│   ├── prd-schema.json   # JSON schema
│   └── PROMPT.md         # Base model instructions
└── projects/
    └── <project-name>/
        ├── prd.md        # Human-written requirements
        ├── prd.json      # Structured tasks
        ├── PROMPT.md     # Project-specific instructions
        ├── progress.txt  # Accumulated learnings
        ├── status.json   # Current state
        ├── verify.sh     # Optional verification script
        └── logs/         # Execution logs
```

## Common Patterns

### Story Verification
Stories can define verification in three ways:
1. **`verify` field**: Direct command (e.g., `"pytest"`, `"cargo test"`)
2. **`acceptance` field**: Use `RUN "command"` syntax
3. **Project verify.sh**: Fallback script

Commands are expanded:
- `pytest` → `python3 -m pytest`
- Language auto-detection for fallback tests

### Stuck Detection
The loop tracks identical verification failures:
- Computes failure signature from command + normalized output
- After 3 identical failures, logs guidance to progress.txt
- Categorizes failure type (syntax_error, import_error, missing_file, wrong_command)
- Provides actionable hints based on failure type

### Code Block Extraction
Models write files using code blocks:
```
```path/to/file.py
# code here
```
```

Or:
```
```python
# File: path/to/file.py
# code here
```
```

Both formats work with any language (.py, .rs, .go, .sh, etc.)

### Prompt Size Management
- Progress.txt limited to last 15 lines or 1000 chars in prompts
- Auto-trimmed when file exceeds 50KB
- Large prompts (>100KB) trigger warnings and truncation
- Prevents "argument list too long" shell errors

## Development Workflow

When modifying ralph-ollama itself:

1. **Test conversion**: Create test project, write PRD, run convert.sh
2. **Test loop**: Run start.sh with small test project
3. **Check logs**: Inspect loop_*.log for model behavior
4. **Verify extraction**: Check that code blocks are correctly written
5. **Test verification**: Ensure verify commands run correctly
6. **Test circuit breaker**: Trigger failures, verify it opens after 5

## Common Issues

### "Argument list too long"
- Caused by large progress.txt in prompt construction
- Solution: trim_progress_file() auto-runs every 10 loops
- Manual: `tail -n 50 projects/<name>/progress.txt > progress.tmp && mv progress.tmp progress.txt`

### Circuit Breaker Opens
- Check logs: `tail -20 projects/<name>/logs/loop_*.log`
- Review failure history: `cat projects/<name>/.circuit_breaker.history`
- Fix issue, then: `./start.sh <name> --reset`

### Stories Not Completing
- Check if model includes `STATUS: COMPLETE` in response
- Verify verification command is correct
- Check progress.txt for stuck detection guidance
- Try different model or simplify story

### Code Blocks Not Written
- Ensure code blocks use correct format (path in fence or File: directive)
- Check response_applier.sh parsing logic
- Verify paths don't contain spaces or ".."
- Look for "Wrote" messages in loop output

### PRD Conversion Issues
- Model returns wrong JSON format (e.g., package.json instead of PRD schema)
- Solution: Check prd.md is actually a requirements doc, not code
- Validate with: `jq '.userStories | type' projects/<name>/prd.json`

## Testing Philosophy

This system is meant to be self-improving:
- Learnings accumulate in progress.txt
- Stuck detection provides guidance
- Circuit breaker prevents wasted resources
- Each failure type gets specific hints

When enhancing the system, preserve this learning loop architecture.
