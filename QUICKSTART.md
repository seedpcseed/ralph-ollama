# Ralph-Ollama Quickstart Guide

This guide walks you through your first Ralph-Ollama project in 10 minutes.

## Prerequisites Check

```bash
# Check if everything is installed
./install.sh
```

This will verify you have:
- Ollama
- jq
- tmux
- At least one coding model

## Step-by-Step Tutorial

### 1. Create a New Project (30 seconds)

```bash
./new.sh todo-api
```

You should see:
```
✓ Project created: ralph/projects/todo-api

Next steps:
  1. Edit your PRD: ralph/projects/todo-api/prd.md
  2. Convert to JSON: ./convert.sh todo-api
  3. Start the loop: ./start.sh todo-api --monitor
```

### 2. Edit Your PRD (3 minutes)

```bash
# Copy the example PRD
cp examples/todo-api-prd.md ralph/projects/todo-api/prd.md

# Or edit manually
nano ralph/projects/todo-api/prd.md
```

**What makes a good PRD:**
- Clear, specific goals
- Concrete features
- Explicit acceptance criteria
- Technical requirements stated upfront

### 3. Convert PRD to JSON (1 minute)

```bash
# Use default model (llama3.1:latest)
./convert.sh todo-api

# Or specify a model
./convert.sh todo-api deepseek-coder:latest
```

This will:
1. Read your PRD
2. Ask Ollama to break it into stories
3. Generate `prd.json` with prioritized tasks

**Check the output:**
```bash
cat ralph/projects/todo-api/prd.json | jq '.userStories[] | {id, story, priority}'
```

### 4. Start the Ralph Loop (5+ minutes)

```bash
# Start with monitoring dashboard
./start.sh todo-api --monitor --model deepseek-coder:latest
```

**What happens:**
- Opens tmux with 2 panes
- Left pane: Ralph loop running
- Right pane: Live status monitor

**Tmux controls:**
- `Ctrl+B` then `D` - Detach (keeps running)
- `Ctrl+B` then arrow keys - Switch panes
- `tmux attach -t ralph-todo-api` - Reattach

### 5. Watch It Work

In the monitor pane you'll see:
- Current status (RUNNING, COMPLETE, etc.)
- Progress bar
- Completed vs remaining stories
- Recent log output

**What Ralph is doing:**
1. Reads next incomplete story
2. Builds a prompt with context
3. Calls Ollama with the task
4. Analyzes the response
5. Marks story complete if successful
6. Commits changes (if in git repo)
7. Moves to next story

### 6. Check Results

```bash
# Detach from tmux (Ctrl+B, D)

# Check status
./start.sh todo-api --status

# View logs
ls -lh ralph/projects/todo-api/logs/

# Read progress notes
cat ralph/projects/todo-api/progress.txt

# See completed stories
jq '.userStories[] | select(.passes == true)' ralph/projects/todo-api/prd.json
```

## Understanding the Output

### Progress File (`progress.txt`)
Records learnings for future iterations:
```
## Codebase Patterns
- Use Express.js for routing
- Store data in todos.json

## 2024-02-02 - Story 1.1
- Created basic Express server
- **Learnings:** Need body-parser middleware for JSON
```

### Status File (`status.json`)
Current loop state:
```json
{
  "status": "running",
  "loop_count": 5,
  "completed_stories": 3,
  "last_updated": "2024-02-02T10:30:00Z"
}
```

### Logs (`logs/`)
Detailed execution logs for each loop iteration.

## Common Scenarios

### Scenario 1: Loop Completes Successfully ✅
```
🎉 All stories complete!
```
Your code is in the current directory. Test it!

### Scenario 2: Circuit Breaker Opens 🔴
```
Circuit breaker OPEN. Loop stopped.
Run: ./start.sh todo-api --reset to continue
```

**What to do:**
1. Check why: `./start.sh todo-api --status`
2. Review logs: `tail -50 ralph/projects/todo-api/logs/loop_*.log`
3. Fix the issue (clarify PRD, fix environment, etc.)
4. Reset and continue: `./start.sh todo-api --reset`
5. Resume: `./start.sh todo-api --monitor`

### Scenario 3: Model Gets Stuck 🟡
Ralph keeps working on the same story without completing it.

**What to do:**
1. Stop: `Ctrl+C`
2. Try a different model:
   ```bash
   ./start.sh todo-api --model codellama:13b --monitor
   ```
3. Or simplify the story in `prd.json`:
   ```bash
   nano ralph/projects/todo-api/prd.json
   # Break the story into smaller steps
   ```

### Scenario 4: Want to Try a Different Model 🔄
```bash
# Stop current loop (Ctrl+C)

# Reset the story to incomplete if needed
jq '.userStories[0].passes = false' ralph/projects/todo-api/prd.json > tmp.json
mv tmp.json ralph/projects/todo-api/prd.json

# Try with different model
./start.sh todo-api --model qwen2.5-coder:latest --monitor
```

## Model Selection Tips

### For This Tutorial:
- **Fast & Good**: `deepseek-coder:latest` (6.7B)
- **Better Quality**: `codellama:13b`
- **Best Quality**: `deepseek-coder:33b` (if you have 32GB+ RAM)

### When to Use Which:
```bash
# Simple API/CRUD apps
--model codellama:latest

# Complex business logic
--model deepseek-coder:33b

# Large codebases
--model qwen2.5-coder:latest

# Full-stack apps
--model codellama:13b
```

## Next Steps

### Experiment with Settings
```bash
# Longer timeout for complex tasks
./start.sh todo-api --timeout 30 --model deepseek-coder:33b

# Faster iteration (more calls allowed)
./start.sh todo-api --calls 200

# Different model per story
# (manually change in each loop if needed)
```

### Try Different Projects
```bash
./new.sh web-scraper
# Write PRD for a web scraper
./convert.sh web-scraper
./start.sh web-scraper --model codellama:13b --monitor
```

### Improve Your PRDs
The better your PRD, the better Ralph performs:
- ✅ Specific acceptance criteria
- ✅ Clear technical requirements
- ✅ Broken into small, testable pieces
- ❌ Vague goals ("make it good")
- ❌ Huge monolithic stories
- ❌ Missing context about the tech stack

### Combine with Git
```bash
# Initialize git in your project directory
cd <your-work-directory>
git init
git add .
git commit -m "Initial commit"

# Ralph will create commits automatically as it completes stories
```

## Troubleshooting

### "Ollama not responding"
```bash
# Check if Ollama is running
ollama list

# Restart Ollama service (macOS)
brew services restart ollama

# Or just restart:
ollama serve
```

### "Model too slow"
- Use a smaller model (7B instead of 33B)
- Close other apps to free up RAM
- Check CPU usage: `top`

### "Stories not completing"
- Model might be underpowered for the task
- Try larger model or simplify PRD
- Check logs for patterns
- Add more specific steps in PRD

### "Out of memory"
```bash
# Check memory usage
free -h  # Linux
vm_stat  # macOS

# Use smaller model
./start.sh todo-api --model codellama:latest
```

## Advanced Tips

### 1. Resume After Interruption
```bash
# Ralph tracks state in prd.json
# Just restart and it continues where it left off
./start.sh todo-api --monitor
```

### 2. Run Multiple Projects
```bash
# Start both in background
./start.sh project-a --model codellama:latest &
./start.sh project-b --model deepseek-coder:latest &

# Monitor separately
tmux attach -t ralph-project-a
# Ctrl+B, D to detach
tmux attach -t ralph-project-b
```

### 3. Custom Prompt Templates
```bash
# Edit the template
nano ralph/projects/todo-api/PROMPT.md

# Add project-specific guidelines
# Ralph will use this for every iteration
```

### 4. Export Progress
```bash
# Generate a report
jq -r '.userStories[] | "\(.id): \(.story) - \(if .passes then "✓" else "○" end)"' \
  ralph/projects/todo-api/prd.json
```

## Success Checklist

By the end of this tutorial, you should have:
- ✅ Created a project
- ✅ Written/used a PRD
- ✅ Converted PRD to JSON
- ✅ Run Ralph loop successfully
- ✅ Seen at least one story complete
- ✅ Understood the monitoring dashboard
- ✅ Know how to troubleshoot issues

## What's Next?

1. **Read the full README.md** for all options
2. **Try different models** to find what works best
3. **Write your own PRDs** for real projects
4. **Experiment with prompts** in PROMPT.md
5. **Share your results** with the community

## Getting Help

If you're stuck:
1. Check logs: `ralph/projects/<project>/logs/`
2. Review status: `./start.sh <project> --status`
3. Read the README.md troubleshooting section
4. Try a different model
5. Simplify your PRD

Happy coding with Ralph-Ollama! 🚀
