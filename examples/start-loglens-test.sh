#!/bin/bash
#
# Quick Start Script for LogLens Test Project
# This sets up and runs the LogLens challenge for Ralph-Ollama
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

echo "=================================================="
echo "LogLens Challenge - Ralph-Ollama Test Project"
echo "=================================================="
echo ""

# Check dependencies
if ! command -v ollama &> /dev/null; then
    echo "❌ Ollama not installed"
    echo "Install: curl -fsSL https://ollama.com/install.sh | sh"
    exit 1
fi

if ! command -v jq &> /dev/null; then
    echo "❌ jq not installed"
    exit 1
fi

echo "✓ Dependencies found"
echo ""

# Check for a coding model
echo "Checking for Ollama models..."
if ! ollama list | grep -q "deepseek-coder\|codellama\|qwen"; then
    echo ""
    echo "No coding models found. Recommended models:"
    echo "  - deepseek-coder:latest (best quality)"
    echo "  - codellama:latest (fastest)"
    echo "  - codellama:13b (good balance)"
    echo ""
    read -p "Pull deepseek-coder:latest now? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        ollama pull deepseek-coder:latest
    else
        echo "Please pull a model first:"
        echo "  ollama pull deepseek-coder:latest"
        exit 1
    fi
fi

echo "✓ Coding model available"
echo ""

# Determine which model to use
MODEL=""
if ollama list | grep -q "deepseek-coder:latest"; then
    MODEL="deepseek-coder:latest"
elif ollama list | grep -q "codellama:13b"; then
    MODEL="codellama:13b"
elif ollama list | grep -q "codellama:latest"; then
    MODEL="codellama:latest"
else
    echo "No suitable model found"
    exit 1
fi

echo "Using model: $MODEL"
echo ""

# Create project
if [ -d "projects/loglens" ]; then
    echo "LogLens project already exists"
    read -p "Delete and recreate? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf projects/loglens
    else
        echo "Keeping existing project"
        cd projects/loglens
        echo ""
        echo "Project ready. To start:"
        echo "  cd projects/loglens"
        echo "  ../../start.sh loglens --monitor --model $MODEL"
        exit 0
    fi
fi

echo "Creating LogLens project..."
./new.sh loglens

# Copy PRD
echo "Copying PRD and test fixtures..."
cp examples/loglens-prd.md projects/loglens/prd.md
mkdir -p projects/loglens/test-fixtures
cp -r examples/test-fixtures/* projects/loglens/test-fixtures/

# Convert PRD
echo ""
echo "Converting PRD to JSON tasks..."
echo "(This may take 1-2 minutes)"
./convert.sh loglens "$MODEL"

echo ""
echo "✓ Project setup complete!"
echo ""

# Show summary
STORY_COUNT=$(jq '[.userStories[]] | length' projects/loglens/prd.json)
MVP_COUNT=$(jq '[.userStories[] | select(.priority <= 10)] | length' projects/loglens/prd.json)

echo "Project: LogLens Log Analysis Tool"
echo "Stories: $STORY_COUNT total ($MVP_COUNT MVP)"
echo "Model: $MODEL"
echo ""

echo "Story Preview:"
jq -r '.userStories[] | select(.priority <= 5) | "  [\(.id)] \(.story)"' projects/loglens/prd.json
echo ""

echo "Next Steps:"
echo "  1. Review PRD: cat projects/loglens/prd.json | jq"
echo "  2. Start Ralph: ./start.sh loglens --monitor --model $MODEL"
echo "  3. Watch progress in tmux dashboard"
echo ""
echo "Test Plan: examples/LOGLENS_TEST_PLAN.md"
echo ""

read -p "Start Ralph now? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo "Starting Ralph with monitoring..."
    echo "(Press Ctrl+B then D to detach from tmux)"
    sleep 2
    ./start.sh loglens --monitor --model "$MODEL"
else
    echo ""
    echo "Ready to start! Run:"
    echo "  ./start.sh loglens --monitor --model $MODEL"
fi
