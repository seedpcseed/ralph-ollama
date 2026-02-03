#!/bin/bash
#
# Ralph-Ollama Installation Script
#

set -e

echo "=================================================="
echo "Ralph-Ollama Installation"
echo "=================================================="
echo ""

# Check for required commands
MISSING_DEPS=""

if ! command -v jq &> /dev/null; then
    MISSING_DEPS="$MISSING_DEPS jq"
fi

if ! command -v tmux &> /dev/null; then
    MISSING_DEPS="$MISSING_DEPS tmux"
fi

if [ -n "$MISSING_DEPS" ]; then
    echo "Missing dependencies:$MISSING_DEPS"
    echo ""
    echo "Install with:"
    echo "  macOS:       brew install$MISSING_DEPS"
    echo "  Ubuntu:      sudo apt-get install$MISSING_DEPS"
    echo "  Arch:        sudo pacman -S$MISSING_DEPS"
    echo ""
    exit 1
fi

# Check for Ollama
if ! command -v ollama &> /dev/null; then
    echo "Ollama not found!"
    echo ""
    echo "Install Ollama:"
    echo "  curl -fsSL https://ollama.com/install.sh | sh"
    echo ""
    echo "Or visit: https://ollama.com"
    exit 1
fi

echo "✓ All dependencies found"
echo ""

# Check for at least one model
if ! ollama list | grep -q codellama; then
    echo "No coding models found. Recommended: codellama"
    echo ""
    read -p "Pull codellama:latest now? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        ollama pull codellama:latest
    fi
fi

echo ""
echo "✓ Installation complete!"
echo ""
echo "Quick start:"
echo "  1. Create project:  ./new.sh my-feature"
echo "  2. Edit PRD:        nano ralph/projects/my-feature/prd.md"
echo "  3. Convert PRD:     ./convert.sh my-feature"
echo "  4. Start loop:      ./start.sh my-feature --monitor"
echo ""
echo "See README.md for full documentation"
echo ""
