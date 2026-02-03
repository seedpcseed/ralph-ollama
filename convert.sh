#!/bin/bash
#
# Convert PRD.md to prd.json using Ollama
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECTS_DIR="$SCRIPT_DIR/projects"
TEMPLATES_DIR="$SCRIPT_DIR/templates"
source "$SCRIPT_DIR/lib/utils.sh"

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

if is_prd_template_unchanged "$PRD_MD" "$TEMPLATES_DIR/prd-template.md"; then
    echo "Error: PRD has not been customized from the template."
    echo "Edit $PRD_MD with your project requirements, then run convert again."
    echo ""
    echo "  Next: Edit $PROJECT_DIR/prd.md, then run $0 $PROJECT_NAME"
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

# Extract JSON from response (model may wrap in markdown and add trailing text)
extract_json_block() {
    local raw="$1"
    # Try ```json ... ``` then ``` ... ``` (allow optional leading/trailing whitespace on fence lines)
    local block
    block=$(echo "$raw" | sed -n '/^[[:space:]]*```json[[:space:]]*$/,/^[[:space:]]*```[[:space:]]*$/p' | sed '1d;$d')
    if [ -z "$block" ]; then
        block=$(echo "$raw" | sed -n '/^[[:space:]]*```[[:space:]]*$/,/^[[:space:]]*```[[:space:]]*$/p' | sed '1d;$d')
    fi
    if [ -n "$block" ]; then
        # Strip trailing ``` from last line (model may put }]}  ``` on same line)
        echo "$block" | sed '$s/[[:space:]]*```[[:space:]]*$//'
        return
    fi
    # Brace-matching fallback: from first { to matching }
    local start
    start=$(echo "$raw" | grep -n '^{' | head -1 | cut -d: -f1)
    if [ -n "$start" ]; then
        echo "$raw" | tail -n +"$start" | python3 -c "
import sys
s = sys.stdin.read()
depth = 0
i = 0
while i < len(s):
    if s[i] == '{': depth += 1
    elif s[i] == '}': depth -= 1
    if depth == 0:
        print(s[:i+1])
        break
    i += 1
"
    fi
}

JSON=$(extract_json_block "$RESPONSE")

# If block extraction left trailing text (e.g. ``` on new line + "Now, you can use..."), take only up to last valid }
if [ -n "$JSON" ] && ! echo "$JSON" | jq . > /dev/null 2>&1; then
    # Trim to first { through matching closing }; strip anything after
    JSON=$(echo "$RESPONSE" | python3 -c "
import sys
s = sys.stdin.read()
try:
    start = s.index('{')
except ValueError:
    sys.exit(1)
depth = 0
i = start
while i < len(s):
    if s[i] == '{': depth += 1
    elif s[i] == '}': depth -= 1
    if depth == 0:
        print(s[start:i+1])
        break
    i += 1
" 2>/dev/null)
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

# Validate JSON structure matches expected schema
if ! validate_prd_json "$PRD_JSON"; then
    echo "Error: Generated JSON doesn't match expected PRD schema"
    echo "Expected: { branchName: string, userStories: array }"
    echo "Got:"
    echo "$JSON" | jq 'keys' 2>/dev/null || echo "  (invalid structure)"
    echo ""
    echo "The model may have generated a different format (e.g. package.json, Cargo.toml)."
    echo "Try a different model or check the PRD.md format."
    rm "$TEMP_PROMPT"
    exit 1
fi

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
