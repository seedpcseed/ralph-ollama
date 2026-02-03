#!/bin/bash
# setup.sh - One-time setup

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Ralph + Aider Setup"
echo "==================="
echo ""

# Check Python
if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 not found. Install Python 3.10-3.12."
    exit 1
fi

PYTHON_VERSION=$(python3 --version 2>&1 | awk '{print $2}' | cut -d. -f1,2)
PYTHON_MAJOR=$(echo "$PYTHON_VERSION" | cut -d. -f1)
PYTHON_MINOR=$(echo "$PYTHON_VERSION" | cut -d. -f2)

echo "✅ Python 3 found (version $PYTHON_VERSION)"

# Check Python version compatibility
if [ "$PYTHON_MAJOR" -eq 3 ] && [ "$PYTHON_MINOR" -ge 13 ]; then
    echo ""
    echo "⚠️  WARNING: Python 3.13 is not yet supported by aider-chat"
    echo "   Aider requires Python 3.10-3.12"
    echo ""
    echo "   We'll try to install using pipx or uv (which handle Python versions automatically)"
    echo "   If those aren't available, pip3 installation will likely fail."
    echo ""
fi

# Check if aider is already installed (via pipx, uv, or pip)
if command -v aider &> /dev/null; then
    AIDER_VERSION=$(aider --version 2>&1 | head -1 || echo "unknown")
    echo "✅ Aider already installed (version: $AIDER_VERSION)"
else
    # For Python 3.13, prefer pipx or uv
    if [ "$PYTHON_MAJOR" -eq 3 ] && [ "$PYTHON_MINOR" -ge 13 ]; then
        # Try to install pipx if not available
        if ! command -v pipx &> /dev/null; then
            echo ""
            echo "⚠️  pipx not found. pipx is recommended for Python 3.13."
            echo "   Attempting to install pipx..."
            if pip3 install --user pipx 2>&1 && python3 -m pipx ensurepath 2>&1; then
                export PATH="$HOME/.local/bin:$PATH"
                echo "✅ pipx installed"
            else
                echo "⚠️  pipx installation failed, will try other methods"
            fi
        fi
        
        if command -v pipx &> /dev/null; then
            echo ""
            echo "Installing Aider with pipx (recommended for Python 3.13)..."
            # Ensure pipx bin directory is in PATH
            export PATH="$HOME/.local/bin:$PATH"
            if pipx install aider-chat; then
                # Give pipx a moment to set up symlinks
                sleep 2
                # Check if aider is now available
                if command -v aider &> /dev/null; then
                    AIDER_VERSION=$(aider --version 2>&1 | head -1 || echo "unknown")
                    echo "✅ Aider installed via pipx (version: $AIDER_VERSION)"
                else
                    echo "✅ Aider installed via pipx"
                    echo "   Note: You may need to restart your terminal or run:"
                    echo "   export PATH=\"\$HOME/.local/bin:\$PATH\""
                fi
            else
                echo ""
                echo "❌ pipx installation failed"
                echo "   Trying pip3 as fallback..."
                # Fall through to pip3 attempt
            fi
        elif command -v uv &> /dev/null; then
            echo ""
            echo "Installing Aider with uv (recommended for Python 3.13)..."
            if uv pip install aider-chat; then
                sleep 1
                if command -v aider &> /dev/null; then
                    AIDER_VERSION=$(aider --version 2>&1 | head -1 || echo "unknown")
                    echo "✅ Aider installed via uv (version: $AIDER_VERSION)"
                else
                    echo "✅ Aider installed via uv"
                fi
            else
                echo ""
                echo "❌ uv installation failed"
                echo "   Trying pip3 as fallback..."
                # Fall through to pip3 attempt
            fi
        fi
    fi
    
    # Try pip3 if aider still not found (or if Python < 3.13)
    if ! command -v aider &> /dev/null; then
        # For Python 3.13, warn that pip3 likely won't work
        if [ "$PYTHON_MAJOR" -eq 3 ] && [ "$PYTHON_MINOR" -ge 13 ]; then
            echo ""
            echo "⚠️  Attempting pip3 installation (may fail with Python 3.13)..."
            echo "   If this fails, please install pipx and use: pipx install aider-chat"
            echo ""
        fi
        
        # Install Aider
        echo ""
        echo "Installing Aider (latest version)..."
        if pip3 install --upgrade aider-chat 2>&1; then
            # Check again after installation
            sleep 1
            if command -v aider &> /dev/null; then
                AIDER_VERSION=$(aider --version 2>&1 | head -1 || echo "unknown")
                echo "✅ Aider installed (version: $AIDER_VERSION)"
            elif command -v pipx &> /dev/null && pipx list | grep -q aider-chat; then
                echo "✅ Aider installed via pipx"
            else
                echo "⚠️  Aider installed but 'aider' command not found in PATH"
                echo "   Try: python3 -m aider.main"
                echo "   Or install with: pipx install aider-chat"
            fi
        else
            echo ""
            echo "❌ Aider installation via pip3 failed"
        
        # Check one more time if aider is available (maybe installed via pipx/uv)
        sleep 1
        if command -v aider &> /dev/null; then
            AIDER_VERSION=$(aider --version 2>&1 | head -1 || echo "unknown")
            echo "✅ However, Aider is already available (version: $AIDER_VERSION)"
            echo "   Continuing with setup..."
        else
            echo ""
            echo "   If you're using Python 3.13, try one of these alternatives:"
            echo ""
            
            # Use counter for dynamic numbering
            OPTION_NUM=1
            
            if command -v pipx &> /dev/null; then
                echo "   $OPTION_NUM. Install with pipx (recommended):"
                echo "      pipx install aider-chat"
                echo ""
                OPTION_NUM=$((OPTION_NUM + 1))
            else
                echo "   $OPTION_NUM. Install pipx, then install aider-chat:"
                echo "      pip install pipx"
                echo "      pipx install aider-chat"
                echo ""
                OPTION_NUM=$((OPTION_NUM + 1))
            fi
            
            if command -v uv &> /dev/null; then
                echo "   $OPTION_NUM. Install with uv:"
                echo "      uv pip install aider-chat"
                echo ""
                OPTION_NUM=$((OPTION_NUM + 1))
            fi
            
            echo "   $OPTION_NUM. Use Python 3.12:"
            echo "      Install pyenv: https://github.com/pyenv/pyenv"
            echo "      pyenv install 3.12"
            echo "      pyenv local 3.12"
            echo ""
            echo "   After installing aider, run this setup script again."
            exit 1
        fi
        fi
    fi
fi

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
