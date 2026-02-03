#!/bin/bash
# setup.sh - One-time setup

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Ralph + Aider Setup"
echo "==================="
echo ""

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

# Check tmux
echo ""
if command -v tmux &> /dev/null; then
    echo "✅ tmux installed"
else
    echo "⚠️  tmux not found (optional, for --monitor mode)"
    echo "   Install with: brew install tmux"
fi

echo ""
echo "Setup complete! 🎉"
echo ""
echo "Quick start:"
echo "  1. Create project:    ./new.sh my-feature"
echo "  2. Edit PRD:          code projects/my-feature/prd.md"
echo "  3. Convert:           ./convert.sh my-feature"
echo "  4. Run (Claude):      ./start.sh my-feature"
echo "  5. Run (local):       RALPH_MODE=local ./start.sh my-feature"
