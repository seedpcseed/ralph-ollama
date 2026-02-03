# Ralph-Ollama: Autonomous Development Loop with Local LLMs

Ralph-Ollama is an autonomous development loop system that uses **Ollama** with local language models to iteratively implement features from a PRD (Product Requirements Document).

## Why Ralph-Ollama?

- ✅ **100% Local** - No API keys, no cloud services, complete privacy
- ✅ **Zero Cost** - No API charges, run unlimited loops
- ✅ **Model Choice** - Use any Ollama-compatible model
- ✅ **No Rate Limits** - Only limited by your hardware
- ✅ **Offline Capable** - Works without internet (after models are downloaded)

## Prerequisites

### 1. Install Ollama
```bash
# macOS/Linux
curl -fsSL https://ollama.com/install.sh | sh

# Or download from https://ollama.com
```

### 2. Install Dependencies
```bash
# macOS
brew install jq tmux coreutils

# Ubuntu/Debian
sudo apt-get install jq tmux coreutils

# Arch
sudo pacman -S jq tmux coreutils
```

### 3. Pull a Model
```bash
# Recommended models for coding:
ollama pull codellama:latest        # 7B - Fast, good for simple tasks
ollama pull deepseek-coder:latest   # 6.7B - Excellent for coding
ollama pull qwen2.5-coder:latest    # 7B - Great code understanding

# For more complex tasks:
ollama pull codellama:13b           # 13B - Better reasoning
ollama pull deepseek-coder:33b      # 33B - Best quality (requires more RAM)

# General purpose models:
ollama pull llama3.1:latest         # 8B - Good all-rounder
ollama pull llama3.1:70b            # 70B - Highest quality (16GB+ RAM)
```

## Quick Start

```bash
# 1. Make scripts executable
chmod +x *.sh

# 2. Create a new project
./new.sh my-feature

# 3. Edit your PRD
nano ralph/projects/my-feature/prd.md
# or
code ralph/projects/my-feature/prd.md

# 4. Convert PRD to JSON tasks
./convert.sh my-feature

# 5. Start the loop with monitoring
./start.sh my-feature --monitor --model deepseek-coder:latest
```

## Commands

### Create New Project
```bash
./new.sh <project-name>
```
Creates a new project from templates.

### Convert PRD to JSON
```bash
# Use default model (llama3.1:latest)
./convert.sh my-feature

# Use specific model
./convert.sh my-feature deepseek-coder:33b

# Set default conversion model
CONVERT_MODEL=qwen2.5-coder:latest ./convert.sh my-feature
```

### Start Ralph Loop
```bash
# Basic (output in terminal)
./start.sh my-feature

# With tmux monitoring (recommended)
./start.sh my-feature --monitor

# Specify model
./start.sh my-feature --model codellama:13b

# Set call limit (default: 100/hour)
./start.sh my-feature --calls 50

# Set timeout (default: 20 minutes)
./start.sh my-feature --timeout 30

# Check status
./start.sh my-feature --status

# Reset circuit breaker
./start.sh my-feature --reset
```

### Monitor Progress
```bash
./monitor.sh my-feature
```
Live dashboard showing progress, status, and recent activity.

## Model Selection Guide

### For Simple Projects
- **codellama:latest** (7B) - Fast, low memory, good for straightforward tasks
- **deepseek-coder:latest** (6.7B) - Excellent code quality, efficient

### For Complex Projects
- **codellama:13b** - Better reasoning, handles complex logic
- **deepseek-coder:33b** - Best code quality, requires 16GB+ RAM
- **qwen2.5-coder:latest** - Strong at understanding existing code

### For PRD Conversion
- **llama3.1:latest** (8B) - Good at understanding requirements
- **llama3.1:70b** - Best comprehension for complex PRDs

### Memory Requirements
| Model Size | RAM Needed | Speed | Quality |
|------------|-----------|-------|---------|
| 7B | 8GB | Fast | Good |
| 13B | 16GB | Medium | Better |
| 33B | 32GB+ | Slow | Best |
| 70B | 48GB+ | Very Slow | Excellent |

## Workflow

```
┌─────────────────────────────────────────┐
│ 1. Write PRD (prd.md)                   │
│    Human requirements document          │
├─────────────────────────────────────────┤
│ 2. Convert to JSON (prd.json)           │
│    Ollama breaks down into tasks        │
├─────────────────────────────────────────┤
│ 3. Ralph Loop                           │
│    ┌───────────────────────────────┐   │
│    │ Pick next incomplete story    │   │
│    ↓                                │   │
│    │ Build prompt with context     │   │
│    ↓                                │   │
│    │ Run Ollama model              │   │
│    ↓                                │   │
│    │ Analyze response              │   │
│    ↓                                │   │
│    │ If complete: mark done, commit│   │
│    ↓                                │   │
│    │ Loop until all stories done   │   │
│    └───────────────────────────────┘   │
└─────────────────────────────────────────┘
```

## PRD JSON Format

```json
{
  "branchName": "ralph/feature-name",
  "userStories": [
    {
      "id": "1.1",
      "category": "functional",
      "story": "Short description",
      "steps": [
        "Step 1: What to do",
        "Step 2: How to verify"
      ],
      "acceptance": "Definition of done",
      "priority": 1,
      "passes": false,
      "notes": ""
    }
  ]
}
```

### Priority Guide
- **1-10**: MVP features (highest priority)
- **11-20**: Phase 2 features
- **21+**: Phase 3 / nice-to-have

## Status Markers

Models must end their responses with:

**Success:**
```
STATUS: COMPLETE
LEARNINGS: Document any patterns or gotchas for future iterations
```

**Incomplete:**
```
STATUS: INCOMPLETE
REASON: Why it couldn't be completed
NEXT_STEPS: What needs to happen next
```

## Safety Features

### Circuit Breaker
Automatically stops the loop after 5 consecutive failures to prevent infinite loops.

```bash
# Check why it stopped
./start.sh my-feature --status

# Reset and continue
./start.sh my-feature --reset
```

### Rate Limiting
Default: 100 calls per hour (configurable). Unlike cloud APIs, this is just a safety limit.

### Timeouts
Default: 20 minutes per task. Prevents hanging on complex tasks.

## Project Structure

```
ralph-ollama/
├── start.sh          # Main loop
├── new.sh            # Create projects
├── convert.sh        # PRD converter
├── monitor.sh        # Status dashboard
├── lib/
│   ├── utils.sh
│   ├── circuit_breaker.sh
│   └── response_analyzer.sh
├── templates/
│   ├── PROMPT.md
│   ├── prd-template.md
│   └── prd-schema.json
└── projects/
    └── <your-projects>/
        ├── prd.md
        ├── prd.json
        ├── progress.txt
        ├── status.json
        └── logs/
```

## Troubleshooting

### Model Not Found
```bash
# List installed models
ollama list

# Pull missing model
ollama pull model-name
```

### Out of Memory
- Use a smaller model (7B instead of 33B)
- Close other applications
- Increase swap space

### Circuit Breaker Opened
```bash
# Check what went wrong
./start.sh my-feature --status
tail -20 ralph/projects/my-feature/logs/loop_*.log

# Fix the issue, then reset
./start.sh my-feature --reset
```

### Slow Performance
- Use a smaller model
- Enable GPU acceleration (if available)
- Reduce context size in prompts
- Increase timeout: `--timeout 30`

### Model Not Following Instructions
- Try a different model (deepseek-coder is usually good)
- Simplify the task in your PRD
- Check PROMPT.md template for clarity
- Use a larger model for complex tasks

## Tips for Best Results

1. **Start Small**: Begin with simple, well-defined tasks
2. **Good PRDs**: Be specific and clear in your requirements
3. **Right Model**: Match model size to task complexity
4. **Monitor Early**: Use `--monitor` to catch issues quickly
5. **Iterate**: Refine your PRD based on what works
6. **Learnings**: Review progress.txt to understand patterns

## Comparing to Claude Code / Cursor Agent

| Feature | Ralph-Ollama | Claude Code | Cursor Agent |
|---------|--------------|-------------|--------------|
| **Cost** | Free | Paid API | Cursor Pro |
| **Privacy** | 100% local | Cloud | Cloud |
| **Rate Limits** | None | 100/hour | None |
| **Model Choice** | Any Ollama | Claude only | Claude only |
| **Offline** | Yes | No | No |
| **Quality** | Model-dependent | Excellent | Excellent |
| **Speed** | Hardware-dependent | Fast | Fast |

## Advanced Usage

### Multiple Projects
```bash
./start.sh project-a --model codellama:13b &
./start.sh project-b --model deepseek-coder:latest &
```

### Custom Models
```bash
# Use a custom quantized model
ollama pull mymodel:Q4_K_M
./start.sh my-feature --model mymodel:Q4_K_M
```

### CI/CD Integration
```bash
# Non-interactive mode (no tmux)
./start.sh my-feature --model codellama:latest 2>&1 | tee build.log
```

## Model Recommendations by Task

### Web Development
- **Frontend**: deepseek-coder:latest, codellama:13b
- **Backend**: qwen2.5-coder:latest, deepseek-coder:33b
- **Full Stack**: codellama:13b, llama3.1:latest

### Data Science / ML
- **Data Analysis**: codellama:13b
- **Model Training**: deepseek-coder:33b
- **Visualization**: codellama:latest

### DevOps / Infrastructure
- **Scripts**: codellama:latest
- **Kubernetes**: qwen2.5-coder:latest
- **Terraform**: deepseek-coder:latest

## Contributing

Found a bug or want to add features? PRs welcome!

## License

MIT - Use freely, modify as needed

## Credits

Based on the Ralph Wiggum technique by Geoffrey Huntley. Adapted for Ollama by the community.

## Resources

- [Ollama Documentation](https://ollama.com)
- [Original Ralph Technique](https://github.com/snwfdhmp/awesome-ralph)
- [DeepSeek Coder](https://ollama.com/library/deepseek-coder)
- [Code Llama](https://ollama.com/library/codellama)
