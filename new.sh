#!/bin/bash
#
# Create new Ralph-Ollama project
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECTS_DIR="$SCRIPT_DIR/projects"
TEMPLATES_DIR="$SCRIPT_DIR/templates"

if [ $# -eq 0 ]; then
    echo "Usage: $0 <project-name>"
    echo "Example: $0 my-feature"
    exit 1
fi

PROJECT_NAME="$1"
PROJECT_DIR="$PROJECTS_DIR/$PROJECT_NAME"

if [ -d "$PROJECT_DIR" ]; then
    echo "Error: Project '$PROJECT_NAME' already exists"
    exit 1
fi

echo "Creating project: $PROJECT_NAME"

mkdir -p "$PROJECT_DIR"
mkdir -p "$PROJECT_DIR/logs"

# Copy templates
cp "$TEMPLATES_DIR/prd-template.md" "$PROJECT_DIR/prd.md"
cp "$TEMPLATES_DIR/PROMPT.md" "$PROJECT_DIR/PROMPT.md"
cp "$TEMPLATES_DIR/prd-schema.json" "$PROJECT_DIR/prd-example.json"
if [ -f "$TEMPLATES_DIR/verify.sh" ]; then
    cp "$TEMPLATES_DIR/verify.sh" "$PROJECT_DIR/verify.sh"
    chmod +x "$PROJECT_DIR/verify.sh"
fi

# Create empty progress file
cat > "$PROJECT_DIR/progress.txt" << 'EOF'
# Ralph Progress Tracker

This file records learnings and patterns discovered during implementation.

## Codebase Patterns
(Patterns will be added here as discovered)

## Key Files
(Important files will be noted here)

---

EOF

# Initialize status
echo '{"loop_count": 0, "completed_stories": 0, "status": "new"}' > "$PROJECT_DIR/status.json"

echo ""
echo "✓ Project created: $PROJECT_DIR"
echo ""
echo "Next steps:"
echo "  1. Edit your PRD: $PROJECT_DIR/prd.md"
echo "  2. Convert to JSON: ./convert.sh $PROJECT_NAME"
echo "  3. Start the loop: ./start.sh $PROJECT_NAME --monitor"
echo ""
