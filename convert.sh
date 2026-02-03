#!/bin/bash
#
# Convert PRD.md to prd.json using Ollama
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECTS_DIR="$SCRIPT_DIR/projects"
TEMPLATES_DIR="$SCRIPT_DIR/templates"

# Default model for conversion (use a capable model)
CONVERT_MODEL="${CONVERT_MODEL:-llama3.1:latest}"

if [ $# -eq 0 ]; then
    echo "Usage: $0 <project-name> [model]"
    echo ""
    echo "Example: $0 my-feature"
    echo "         $0 my-feature deepseek-coder:33b"
    echo ""
    echo "Default model: $CONVERT_MODEL"
    echo "Override with: CONVERT_MODEL=model-name $0 <project>"
    exit 1
fi

PROJECT_NAME="$1"
MODEL="${2:-$CONVERT_MODEL}"
PROJECT_DIR="$PROJECTS_DIR/$PROJECT_NAME"

if [ ! -d "$PROJECT_DIR" ]; then
    echo "Error: Project '$PROJECT_NAME' not found"
    echo "Run: ./new.sh $PROJECT_NAME"
    exit 1
fi

PRD_MD="$PROJECT_DIR/prd.md"
PRD_JSON="$PROJECT_DIR/prd.json"
SCHEMA="$TEMPLATES_DIR/prd-schema.json"

if [ ! -f "$PRD_MD" ]; then
    echo "Error: $PRD_MD not found"
    exit 1
fi

if [ ! -f "$SCHEMA" ]; then
    echo "Error: Schema template not found: $SCHEMA"
    exit 1
fi

echo "Converting PRD to JSON format..."
echo "Project: $PROJECT_NAME"
echo "Model: $MODEL"
echo ""

# Check if model exists
if ! ollama list | grep -q "^${MODEL%%:*}"; then
    echo "Model $MODEL not found locally. Pulling..."
    ollama pull "$MODEL"
fi

# Create conversion prompt
TEMP_PROMPT=$(mktemp)
cat > "$TEMP_PROMPT" << 'EOF'
You are a technical project analyst. Convert the following Product Requirements Document (PRD) into a structured JSON format.

The JSON should follow this schema:
```json
{
  "branchName": "ralph/feature-name",
  "userStories": [
    {
      "id": "1.1",
      "category": "technical|functional|ui",
      "story": "One-sentence description",
      "steps": ["Step 1", "Step 2"],
      "acceptance": "Detailed acceptance criteria. Use RUN \"command\" for verifiable criteria.",
      "verify": "optional runnable command (e.g. pytest, cargo test, go test ./..., app --help)",
      "priority": 1,
      "passes": false,
      "notes": ""
    }
  ]
}
```

IMPORTANT RULES:
1. Break down the PRD into discrete, implementable user stories
2. Each story should be completable in one session
3. Priority: 1-10 = MVP (do first), 11-20 = Phase 2, 21+ = Phase 3
4. Lower priority number = higher importance
5. All stories start with passes: false
6. Category must be one of: technical, functional, ui
7. Steps should be actionable and specific
8. Include a branchName following the pattern: ralph/<feature-name>
9. REQUIRED: Include a story for "Make the app installable/runable" - Python: pyproject.toml/setup.py; Rust: cargo build; Go: go build; Node: npm install. Priority near end of MVP.
10. REQUIRED: Include an "Integration" story that wires all components together, ensures the main CLI/entry point uses all features. Priority: last MVP story.
11. Add "verify" field for runnable checks (language-agnostic):
    - Python: "pytest"; Rust: "cargo test"; Go: "go test ./..."; Node: "npm test"
    - Only use the app CLI command (e.g. "myapp --help") in verify for stories AFTER the "Make installable" story
    - Do NOT pipe app output to test runners (e.g. "app parse file | pytest" is invalid)
    - Use project-relative paths (e.g. test-fixtures/sample.log, not ../tests/fixtures/)

PRD TO CONVERT:
================================================================================
EOF

cat "$PRD_MD" >> "$TEMP_PROMPT"

cat >> "$TEMP_PROMPT" << 'EOF'
================================================================================

Output ONLY valid JSON following the schema above. No explanations, no markdown formatting, just pure JSON.
EOF

echo "Analyzing PRD with $MODEL..."
RESPONSE=$(ollama run "$MODEL" "$(cat "$TEMP_PROMPT")")

# Extract JSON from response (in case model adds explanation)
# First try: extract JSON between ```json and ``` code blocks (preserves full multi-line JSON)
JSON=$(echo "$RESPONSE" | sed -n '/```json/,/```/p' | sed '1d;$d')

if [ -z "$JSON" ]; then
    # Fallback: extract from first { to matching closing } (multi-line)
    JSON=$(echo "$RESPONSE" | sed -n '/^{/,/^}/p')
fi

if [ -z "$JSON" ]; then
    echo "Error: Could not extract JSON from model response"
    echo "Response was:"
    echo "$RESPONSE"
    rm "$TEMP_PROMPT"
    exit 1
fi

# Validate JSON (with repair attempt for truncated model output)
if ! echo "$JSON" | jq . > /dev/null 2>&1; then
    # Try repair: models often truncate before closing. Try } first (truncated after ]), then ]} (truncated after last story)
    if echo "${JSON}}" | jq . > /dev/null 2>&1; then
        JSON="${JSON}}"
    elif echo "${JSON}]}" | jq . > /dev/null 2>&1; then
        JSON="${JSON}]}"
    fi
fi

if ! echo "$JSON" | jq . > /dev/null 2>&1; then
    echo "Error: Generated JSON is invalid"
    echo "Response:"
    echo "$JSON"
    rm "$TEMP_PROMPT"
    exit 1
fi

# Save JSON
echo "$JSON" | jq . > "$PRD_JSON"

rm "$TEMP_PROMPT"

# Show summary
STORY_COUNT=$(jq '[.userStories[]] | length' "$PRD_JSON")
BRANCH_NAME=$(jq -r '.branchName' "$PRD_JSON")

echo ""
echo "✓ PRD converted successfully"
echo ""
echo "Branch: $BRANCH_NAME"
echo "Stories: $STORY_COUNT"
echo ""
echo "Preview:"
jq -r '.userStories[] | "  [\(.id)] \(.story) (priority: \(.priority))"' "$PRD_JSON" | head -n 10

if [ $STORY_COUNT -gt 10 ]; then
    echo "  ... and $((STORY_COUNT - 10)) more"
fi

echo ""
echo "Next: ./start.sh $PROJECT_NAME --monitor"
echo ""
