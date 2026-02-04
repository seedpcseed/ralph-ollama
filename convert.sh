#!/bin/bash

# Ralph Convert - Convert PRD.md to prd.json and requirements.md using Aider
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# For convert: run Aider from ralph-ollama so it sees this repo's .git and project files
REPO_ROOT="$SCRIPT_DIR"
source "$SCRIPT_DIR/lib/utils.sh"
source "$SCRIPT_DIR/config.sh"  # Load configuration

# Aider model variable (set by setup_aider)
AIDER_MODEL=""

# Spinner characters
SPINNER_CHARS='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
SPINNER_PID=""

# Fun action words that rotate every 10 seconds
SPINNER_WORDS=(
    "Bamboozling"
    "Sibidubing"
    "Percolating"
    "Badabiming"
    "Populating"
    "Conjuring"
    "Manifesting"
    "Synthesizing"
    "Transmuting"
    "Wrangling"
    "👉Fingering👌"
    "Summoning"
    "Orchestrating"
    "Brewing"
    "Concocting"
    "Materializing"
    "Shimshaming"
    "Razzledazzling"
    "Hocuspocusing"
    "Abracadabring"
    "Alakazaming"
    "Zippitydooing"
    "Whizbangifying"
    "Kerfuffling"
    "Discombobulating"
    "Flibbertigibbeting"
    "Gobbledygooking"
    "Hullaballooing"
    "Jiggerypokerying"
    "Lolligagging"
    "Malarkeying"
    "Nambyambying"
    "Pitterpattering"
    "Rambunctifying"
    "Skedaddling"
    "Wibblewobblin"
    "Zigzagging"
    "Bippityboppitying"
    "Splendiferous-ing"
    "Thingamabobbing"
    "Whatchamacalling"
    "Dinglehopping"
    "Snarfblating"
    "Woozlewazzling"
    "Snickerdoodling"
    "Flimflamming"
    "Hobnobbing"
    "Rigmaroling"
    "Wishy-washying"
    "Hodgepodging"
    "Humdinging"
)

# Start spinner in background with rotating fun words
# Usage: start_spinner "Phase description"
start_spinner() {
    local phase_desc="${1:-Processing...}"
    
    # Don't start if already running
    if [[ -n "$SPINNER_PID" ]] && kill -0 "$SPINNER_PID" 2>/dev/null; then
        return
    fi
    
    (
        local i=0
        local word_idx=$((RANDOM % ${#SPINNER_WORDS[@]}))
        local last_word_change=$SECONDS
        local word_count=${#SPINNER_WORDS[@]}
        
        while true; do
            # Change word every 3 seconds (pick random)
            if (( SECONDS - last_word_change >= 3 )); then
                word_idx=$((RANDOM % word_count))
                last_word_change=$SECONDS
            fi
            
            local char="${SPINNER_CHARS:i++%${#SPINNER_CHARS}:1}"
            local action="${SPINNER_WORDS[$word_idx]}"
            printf "\r${GREEN}%s${NC} %s %s" "$char" "$action" "$phase_desc"
            sleep 0.1
        done
    ) &
    SPINNER_PID=$!
    
    # Ensure spinner is killed on script exit
    trap 'stop_spinner' EXIT
}

# Stop the spinner
stop_spinner() {
    if [[ -n "$SPINNER_PID" ]]; then
        kill "$SPINNER_PID" 2>/dev/null || true
        wait "$SPINNER_PID" 2>/dev/null || true
        SPINNER_PID=""
        printf "\r\033[K"  # Clear the line
    fi
}

# Get relative path from current directory
get_relative_path() {
    local abs_path="$1"
    local cwd="$(pwd)"
    
    # If path starts with cwd, strip it
    if [[ "$abs_path" == "$cwd"/* ]]; then
        echo "${abs_path#$cwd/}"
    else
        echo "$abs_path"
    fi
}

# Setup Aider based on mode (same as start.sh)
setup_aider() {
    local mode=$1
    
    case $mode in
        claude)
            if [ -z "$ANTHROPIC_API_KEY" ]; then
                log "ERROR" "ANTHROPIC_API_KEY not set for Claude mode"
                log "INFO" "Set it with: export ANTHROPIC_API_KEY='your-key-here'"
                exit 1
            fi
            AIDER_MODEL="anthropic/claude-sonnet-4-5"
            log "INFO" "Using Claude Sonnet 4.5 via API"
            ;;
        local)
            local convert_model="${LOCAL_CONVERT_MODEL:-$LOCAL_MODEL}"
            AIDER_MODEL="ollama/$convert_model"
            log "INFO" "Using local model for convert: $convert_model"
            
            # Check if Ollama is running, start if not
            if ! curl -s http://localhost:11434/api/tags >/dev/null 2>&1; then
                if ! command -v ollama &> /dev/null; then
                    log "ERROR" "Ollama is not installed"
                    log "INFO" "Install from: https://ollama.ai"
                    exit 1
                fi
                
                log "INFO" "Ollama server is not running, starting it..."
                # Start Ollama in background
                ollama serve > /dev/null 2>&1 &
                local ollama_pid=$!
                
                # Wait for Ollama to start (max 10 seconds)
                local wait_count=0
                while [ $wait_count -lt 10 ]; do
                    if curl -s http://localhost:11434/api/tags >/dev/null 2>&1; then
                        log "SUCCESS" "Ollama server started (PID: $ollama_pid)"
                        break
                    fi
                    sleep 1
                    wait_count=$((wait_count + 1))
                done
                
                if [ $wait_count -eq 10 ]; then
                    log "ERROR" "Ollama server failed to start after 10 seconds"
                    log "INFO" "Try starting manually: ollama serve"
                    exit 1
                fi
            fi
            
            # Check if model is available
            if ! ollama list 2>/dev/null | grep -q "$convert_model"; then
                log "WARN" "Model '$convert_model' is not available locally"
                log "INFO" "Pulling model (this may take several minutes)..."
                if ollama pull "$convert_model" 2>&1 | tee /tmp/ollama_pull.log; then
                    log "SUCCESS" "Model '$convert_model' pulled successfully"
                    rm -f /tmp/ollama_pull.log
                else
                    log "ERROR" "Failed to pull model '$convert_model'"
                    if grep -q "connection reset\|max retries exceeded" /tmp/ollama_pull.log 2>/dev/null; then
                        log "ERROR" "Network/firewall blocking Cloudflare R2 storage"
                        log "INFO" ""
                        log "INFO" "Options:"
                        log "INFO" "  1. Use Claude API mode: ./convert.sh $PROJECT_NAME --model claude"
                        log "INFO" "  2. Pull model from a different network (home, VPN, etc.)"
                        log "INFO" "  3. Contact IT to whitelist Cloudflare R2 domains"
                        log "INFO" ""
                        rm -f /tmp/ollama_pull.log
                        exit 1
                    else
                        log "WARN" "Pull failed for unknown reason"
                        log "INFO" "Try manually: ollama pull $convert_model"
                        rm -f /tmp/ollama_pull.log
                    fi
                fi
            else
                log "INFO" "Model '$convert_model' is available"
            fi
            ;;
        hybrid)
            # For convert, hybrid mode uses Claude (conversion is critical)
            AIDER_MODEL="anthropic/claude-sonnet-4-5"
            log "INFO" "Using Claude for conversion (hybrid mode uses Claude for critical tasks)"
            ;;
        *)
            log "ERROR" "Unknown mode '$mode'. Use: claude, local, or hybrid"
            exit 1
            ;;
    esac
}

show_help() {
    cat << HELPEOF
Ralph Convert - Convert PRD.md to JSON tasks and requirements

Usage: $0 <project-name> [OPTIONS]

Arguments:
    project-name    Name of the Ralph project to convert

Options:
    --model MODE    Model mode: claude, local, or hybrid (default: $MODE)
    -h, --help      Show this help

Examples:
    $0 signals
    $0 pagination
    $0 signals --model local
    RALPH_MODE=hybrid $0 pagination

This will run a two-phase conversion process:

Phase 1 - Initial Conversion:
  - Read projects/<project-name>/prd.md
  - Generate prd.json (actionable user stories)
  - Generate requirements.md (technical specifications)

Phase 2 - Verification:
  - Re-read the original PRD and generated files
  - Verify comprehensive coverage of all requirements
  - Add any missing stories or technical details

Environment Variables:
    RALPH_MODE      Model mode: claude, local, or hybrid (default: claude)
    ANTHROPIC_API_KEY   Required for Claude mode

HELPEOF
}

# Create conversion prompt
create_conversion_prompt() {
    local project_name=$1
    local project_dir=$2

    # Use quoted heredoc to prevent command execution, then expand variables with sed
    cat << 'PROMPTEOF' | sed "s|\$project_name|$project_name|g"
# PRD to Tasks Conversion

You are running inside Aider. The files prd.md, prd.json and requirements.md are already in this chat—you have full access to them. You MUST use your edit capability to change the files. Do not say you cannot access files. Do not reply with only examples in code blocks; apply the changes by editing the files.

## Your task
1. Read projects/$project_name/prd.md (it is in the chat) to understand ALL requirements.
2. Edit projects/$project_name/prd.json: replace its entire contents with a JSON object that has "branchName": "ralph/$project_name" and "userStories": [ ... ] — an array of story objects.

**Story generation strategy:**
- Break down each major feature from the PRD into 3-10 granular stories
- Each story should be completable in 1-2 iterations (not require multiple refinement passes)
- Create stories in dependency order (infrastructure → core → features → polish)
- Include verification commands in acceptance criteria or verify field
- Aim for 15-30 stories total (not 5-10 high-level ones)

**Example breakdown for "Implement markdown parser":**
- Story 1.1: "Add pulldown-cmark dependency to Cargo.toml" (verify: grep -q pulldown Cargo.toml)
- Story 1.2: "Create AST node enum with variants" (verify: cargo build --lib)
- Story 1.3: "Implement parse_markdown() function" (verify: cargo test parser)
- Story 1.4: "Add tests for CommonMark features" (verify: cargo test parser_commonmark)
- Story 1.5: "Add tests for GFM extensions" (verify: cargo test parser_gfm)

3. Edit projects/$project_name/requirements.md: replace or expand with technical specifications taken from the PRD (architecture, data models, API, UI, performance, security).

## Story object shape (for each item in userStories)
- id: e.g. "1.1", "1.2", "1.3" (sequential, can have sub-stories like "1.2.1")
- category: "technical" | "functional" | "ui"
- story: one sentence, action verb, specific and granular
- steps: array of 2-5 concrete, actionable steps
- acceptance: testable criteria with verification command (see below)
- priority: 1-10 (lower first, dependencies before dependents)
- passes: false
- notes: ""
- verify: (optional) command to verify completion, e.g. "cargo test parser" or "grep -q function_name file.rs"

Categories: technical = DB/API/backend/schemas/infrastructure; functional = business logic/features; ui = frontend/pages/styling. Order by dependency (infra before features).

## CRITICAL: Story Granularity Rules

**Break down large features into small, verifiable stories.** Each story should be completable in 1-2 iterations (not require multiple passes).

**BAD (too broad):**
- "Implement markdown parser" → This is 5-10 stories!
- "Design two-pass layout engine" → Too vague, needs breakdown
- "Create CLI interface" → Multiple components

**GOOD (granular and verifiable):**
- "Add pulldown-cmark dependency to Cargo.toml" → Verifiable: grep -q pulldown Cargo.toml
- "Create AST node enum with Headline, Paragraph, CodeBlock variants" → Verifiable: cargo build --lib
- "Implement parse_markdown() function returning Vec<Node>" → Verifiable: cargo test parser
- "Create CLI Args struct with clap" → Verifiable: cargo build --bin editio

**Breakdown strategy:**
1. **Dependencies first**: Add library → Create types → Implement functions → Add tests
2. **One concept per story**: Don't combine "add dependency AND implement parser" - split them
3. **Each story should create 1-3 files max**: If more, break it down
4. **Verifiable completion**: Each story must have a way to verify it's done (build, test, grep, etc.)

## Acceptance Criteria Format

**Include verification commands in acceptance criteria.** Use one of these formats:

**Format 1: RUN command in acceptance**
```
"acceptance": "RUN 'cargo test parser' must pass. The parser handles headings, paragraphs, and code blocks."
```

**Format 2: Separate verify field**
```
"acceptance": "The parser handles headings, paragraphs, and code blocks.",
"verify": "cargo test parser"
```

**Format 3: File existence check**
```
"acceptance": "Cargo.toml includes pulldown-cmark dependency.",
"verify": "grep -q pulldown-cmark Cargo.toml"
```

**Verification examples by language:**
- **Rust**: cargo build, cargo test --lib parser, cargo check
- **Python**: pytest tests/test_parser.py, python -m mypy parser.py
- **Node**: npm test, node -e "require('./parser')"
- **Go**: go test ./parser, go build
- **File checks**: grep -q 'function_name' file.rs, test -f path/to/file

**If a story legitimately needs TODOs for future work, mark it with lower priority and note it in acceptance:**
```
"acceptance": "Basic structure created. TODO items acceptable for future enhancement.",
"priority": 8
```

## Edit format (required)
You are using Aider's "whole" edit format. To edit a file you MUST use this exact format:
- One line with ONLY the file path (no blank line after it).
- The very next line must be exactly \`\`\` (triple backticks, no word after them).
- Then the complete file contents.
- Then a line with exactly \`\`\`.

CRITICAL: There must be NO blank line between the path and the \`\`\`. The path must be the line immediately above the opening \`\`\`.

Example (no blank line between path and backticks):
projects/$project_name/prd.json
\`\`\`
{"branchName":"ralph/$project_name","userStories":[{"id":"1.1",...}]}
\`\`\`

Use paths: projects/$project_name/prd.json and projects/$project_name/requirements.md. For requirements.md use the same format (path, then \`\`\` on next line, then full file content). Do not use \`\`\`json or \`\`\`diff.

Apply both file edits, then a one-line summary.
PROMPTEOF
}

# Create verification prompt
create_verification_prompt() {
    local project_dir=$1
    cat << PROMPTEOF
# PRD to JSON Verification

You are verifying that a generated prd.json comprehensively covers all requirements from the original PRD.

## Files to work with:
- READ: $project_dir/prd.md (the original PRD - source of truth)
- READ & EDIT: $project_dir/prd.json (the generated user stories)
- READ & EDIT: $project_dir/requirements.md (the generated technical specs)

## Instructions:

### 1. Carefully read the original PRD.md and understand ALL requirements, features, and details.

### 2. Read the generated prd.json and requirements.md.

### 3. Compare and verify:
- Does prd.json cover ALL features mentioned in the PRD?
- Are stories granular enough? (Each should be 1-2 iterations, not require multiple passes)
- Do stories have verifiable acceptance criteria? (RUN commands, verify fields, or file checks)
- Are there any edge cases, error handling, or UX details in the PRD that are missing from the stories?
- Does requirements.md capture all technical specifications from the PRD?

### 4. If anything is missing or incomplete:
- ADD new user stories to cover missing features (break down large ones into smaller, verifiable tasks)
- SPLIT stories that are too broad (if a story has 5+ steps or multiple components, break it down)
- UPDATE existing stories if their scope is incomplete or lacks verification
- ADD verify fields or RUN commands to stories that don't have them
- UPDATE requirements.md if technical details are missing
- Ensure all additions follow the same format and guidelines (granular, verifiable, 1-2 iterations each).
PROMPTEOF
}

# Returns 0 if requirements.md is still placeholder (empty or only the default header)
is_requirements_placeholder() {
    local req_file=$1
    [[ ! -f "$req_file" ]] && return 0
    local lines
    lines=$(wc -l < "$req_file" 2>/dev/null || echo "0")
    [[ "${lines:-0}" -gt 3 ]] && return 1
    grep -q "^# Technical requirements (generated from PRD)" "$req_file" 2>/dev/null && \
        ! grep -v "^#" "$req_file" 2>/dev/null | grep -q . && return 0
    return 1
}

# Prompt for filling only requirements.md from the PRD (used when Phase 1 didn't populate it)
create_requirements_fill_prompt() {
    local project_name=$1
    # Use quoted heredoc to prevent command execution, then expand variables with sed
    cat << 'PROMPTEOF' | sed "s|\$project_name|$project_name|g"
You are running inside Aider. The files prd.md and requirements.md are in this chat. You MUST edit requirements.md.

TASK: Replace the contents of projects/$project_name/requirements.md with technical specifications extracted from the PRD. Include: architecture, data models, APIs, UI/UX constraints, performance and security requirements, tech stack, and any other technical details from the PRD. Write in clear markdown sections.

Use Aider's whole-file edit format: on one line the path projects/$project_name/requirements.md, then a line with \`\`\`, then the full file content, then \`\`\`. Do not use \`\`\`json or \`\`\`diff. Apply the edit now.
PROMPTEOF
}

main() {
    local project_name="$1"

    # Validate arguments
    if [[ -z "$project_name" ]]; then
        log "ERROR" "Project name is required"
        show_help
        exit 1
    fi

    local project_dir="$SCRIPT_DIR/projects/$project_name"
    local prd_file="$project_dir/prd.md"
    local json_file="$project_dir/prd.json"
    local req_file="$project_dir/requirements.md"

    # Check if project exists
    if [[ ! -d "$project_dir" ]]; then
        log "ERROR" "Project '$project_name' does not exist"
        log "INFO" "Create it first with: ./new.sh $project_name"
        exit 1
    fi

    # Check if PRD exists
    if [[ ! -f "$prd_file" ]]; then
        log "ERROR" "PRD file not found: $prd_file"
        exit 1
    fi

    # Check if prd.json already has stories
    if [[ -f "$json_file" ]]; then
        local existing_count
        existing_count=$(jq '.userStories | length' "$json_file" 2>/dev/null || echo "0")
        if [[ "$existing_count" -gt 0 ]]; then
            log "WARN" "prd.json already has $existing_count stories"
            echo -n "Overwrite? [y/N] "
            read -r response
            if [[ ! "$response" =~ ^[Yy]$ ]]; then
                log "INFO" "Cancelled"
                exit 0
            fi
        fi
    fi

    # Ensure prd.json and requirements.md exist with valid content so Aider can edit them
    # (empty or invalid files can cause Aider to skip applying edits)
    if [[ ! -s "$json_file" ]] || ! jq -e '.userStories | type == "array"' "$json_file" 2>/dev/null; then
        printf '{"branchName":"ralph/%s","userStories":[]}\n' "$project_name" > "$json_file"
    fi
    if [[ ! -s "$req_file" ]]; then
        echo "# Technical requirements (generated from PRD)" > "$req_file"
    fi

    log "INFO" "Converting PRD to tasks for project: $project_name"
    log "INFO" "Aider will edit prd.json and requirements.md directly..."
    log "INFO" "Using model: $AIDER_MODEL"

    # Clean up Git state: remove deleted files from tracking to avoid Aider warnings
    # This prevents "Repo-map can't include" warnings for files deleted from filesystem but still in Git
    # Aider reads from HEAD, so we need to commit deletions for Aider to see the updated state
    cd "$REPO_ROOT"
    local deleted_files
    deleted_files=$(git ls-files --deleted "projects/$project_name/" 2>/dev/null || true)
    local staged_deletions
    staged_deletions=$(git diff --cached --name-only --diff-filter=D "projects/$project_name/" 2>/dev/null || true)
    
    # Handle files deleted from working tree but not yet staged
    if [[ -n "$deleted_files" ]]; then
        log "INFO" "Staging deletions for files removed from filesystem..."
        echo "$deleted_files" | while IFS= read -r file; do
            if [[ -n "$file" ]]; then
                git rm "$file" >/dev/null 2>&1 || true
            fi
        done
    fi
    
    # Commit staged deletions so Aider sees updated state (Aider reads from HEAD)
    if [[ -n "$staged_deletions" ]] || [[ -n "$deleted_files" ]]; then
        log "INFO" "Committing file deletions to clean up Git state for Aider..."
        git commit -m "chore($project_name): remove deleted files from Git tracking" >/dev/null 2>&1 || true
    fi

    # Create log directory
    local timestamp=$(date '+%Y-%m-%d_%H-%M-%S')
    mkdir -p "$project_dir/logs"

    # ═══════════════════════════════════════════════════════════════════════════
    # PHASE 1: Initial Conversion
    # ═══════════════════════════════════════════════════════════════════════════
    echo ""
    log "INFO" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log "INFO" "PHASE 1: Converting PRD to tasks"
    log "INFO" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # Create temp file with conversion prompt
    local temp_prompt=$(mktemp)
    create_conversion_prompt "$project_name" "$project_dir" > "$temp_prompt"

    local convert_log="$project_dir/logs/convert_${timestamp}.log"
    log "INFO" "Log file: $(get_relative_path "$convert_log")"

    # Run Aider with spinner
    start_spinner "(Phase 1: Initial conversion)..."
    local convert_success=true
    
    # Run Aider from ralph-ollama (repo with .git and projects/)
    cd "$REPO_ROOT"
    local prd_rel="projects/$project_name/prd.md"
    local json_rel="projects/$project_name/prd.json"
    local req_rel="projects/$project_name/requirements.md"

    # Build Aider command - paths relative to ralph-ollama
    local aider_cmd=(
        aider
        "$prd_rel"
        "$json_rel"
        "$req_rel"
        --model "$AIDER_MODEL"
        --yes
        --no-stream
        --no-show-model-warnings
        --message-file "$temp_prompt"
    )
    
    if [ "$AIDER_AUTO_COMMITS" = true ]; then
        aider_cmd+=(--auto-commits)
    fi
    # Do NOT add --commit: Aider runs --commit before --message-file and then exits, so the model would never run.

    if [ "$AIDER_NO_PRETTY" = true ]; then
        aider_cmd+=(--no-pretty)
    fi
    
    # Execute Aider
    if ! "${aider_cmd[@]}" > "$convert_log" 2>&1; then
        convert_success=false
    fi
    stop_spinner

    rm -f "$temp_prompt"

    if [[ "$convert_success" != "true" ]]; then
        log "ERROR" "Aider conversion failed"
        log "INFO" "Check log: $(get_relative_path "$convert_log")"
        exit 1
    fi

    # Verify files were created
    local story_count=0
    if [[ -f "$json_file" ]]; then
        story_count=$(jq '.userStories | length' "$json_file" 2>/dev/null || echo "0")
    fi

    # Fallback: if model output prd.json in the log but Aider didn't apply it, extract and write
    if [[ "$story_count" -eq 0 ]] && [[ -f "$convert_log" ]]; then
        local json_extract
        # Try 1: JSON in code block (path then ``` then JSON)
        json_extract=$(awk -v path="projects/$project_name/prd.json" '
            $0 ~ "^" path " *$" { want=1; next }
            want && $0 ~ "^```" && !capturing { capturing=1; buf=""; next }
            want && capturing && $0 ~ "^```" { print buf; exit }
            capturing { buf = (buf == "" ? $0 : buf "\n" $0) }
        ' "$convert_log")
        if [[ -n "$json_extract" ]]; then
            json_extract=$(echo "$json_extract" | perl -0777 -pe 's/\n\s*([a-zA-Z])/ \1/g' 2>/dev/null || echo "$json_extract")
            local count
            count=$(echo "$json_extract" | jq -r '.userStories | length' 2>/dev/null || echo "0")
            if [[ "$count" != "" && "$count" != "null" && "${count:-0}" -gt 0 ]]; then
                if echo "$json_extract" | jq -c . > "$json_file" 2>/dev/null; then
                    story_count=$count
                    log "INFO" "Recovered prd.json from log (JSON block, $count stories)"
                fi
            fi
        fi
        # Try 2: structured list format (- id: "1.1", - category: ..., - story: ..., etc.)
        if [[ "$story_count" -eq 0 ]] && [[ -f "$convert_log" ]]; then
            local parsed
            parsed=$(PROJECT_NAME="$project_name" perl -0777 -n -e '
                use JSON::PP qw(encode_json);
                use JSON::PP (); my $false = JSON::PP::false; my $true = JSON::PP::true;
                my $proj = $ENV{PROJECT_NAME} || "project";
                my @stories;
                while (m/- id:\s*"([^"]+)"\s*\n(.*?)(?=- id:\s*"|\z)/gs) {
                    my ($id, $block) = ($1, $2);
                    my %s = (id => $id, category => "technical", story => "", steps => [], acceptance => "", priority => 999, passes => $false, notes => "", verify => "");
                    $block =~ s/\n\s*\n/\n/g;
                    $s{category} = $1 if $block =~ /- category:\s*"([^"]*)"/;
                    $s{story} = $1 if $block =~ /- story:\s*"([^"]*)"/s;
                    $s{story} =~ s/\s+/ /g;
                    $s{acceptance} = $1 if $block =~ /- acceptance:\s*"([^"]*)"/s;
                    $s{acceptance} =~ s/\s+/ /g;
                    if ($block =~ /- steps:\s*\[(.*?)\]/s) {
                        my $steps = $1;
                        $steps =~ s/\s+/ /g;
                        $s{steps} = [ map { s/^"|"$//g; $_ } split /",\s*"/, $steps ];
                    }
                    $s{priority} = int($1) if $block =~ /- priority:\s*(\d+)/;
                    $s{passes} = ($block =~ /- passes:\s*true/i) ? $true : $false;
                    $s{notes} = $1 if $block =~ /- notes:\s*"([^"]*)"/;
                    $s{verify} = $1 if $block =~ /- verify:\s*"([^"]*)"/;
                    # Also extract RUN commands from acceptance if verify is empty (handle both single and double quotes)
                    if (!$s{verify}) {
                        if ($s{acceptance} =~ /RUN\s+["]([^"\n]+)["]/) {
                            $s{verify} = $1;
                        } elsif ($s{acceptance} =~ /RUN\s+\x27([^\x27\n]+)\x27/) {
                            $s{verify} = $1;
                        }
                    }
                    push @stories, \%s;
                }
                if (@stories) {
                    my $out = { branchName => "ralph/" . $proj, userStories => \@stories };
                    print encode_json($out);
                }
            ' "$convert_log" 2>/dev/null)
            if [[ -n "$parsed" ]]; then
                local count
                count=$(echo "$parsed" | jq -r '.userStories | length' 2>/dev/null || echo "0")
                if [[ "${count:-0}" -gt 0 ]]; then
                    if echo "$parsed" | jq -c . > "$json_file" 2>/dev/null; then
                        story_count=$count
                        log "INFO" "Recovered prd.json from log (structured list, $count stories)"
                    fi
                fi
            fi
        fi
    fi

    if [[ "$story_count" -eq 0 ]]; then
        log "ERROR" "prd.json has no stories - conversion failed"
        log "INFO" "Check the log file: $(get_relative_path "$convert_log")"
        exit 1
    fi

    # Normalize prd.json: pretty-print and consistent field order (id, category, story, steps, acceptance, priority, passes, notes, verify)
    if jq -e '.userStories | length > 0' "$json_file" >/dev/null 2>&1; then
        jq '{
            branchName,
            userStories: [.userStories[] | {id, category, story, steps, acceptance, priority, passes, notes} + (if .verify and .verify != "" then {verify} else {} end)]
        }' "$json_file" > "${json_file}.tmp" 2>/dev/null && mv "${json_file}.tmp" "$json_file"
    fi

    log "SUCCESS" "Phase 1 complete: Generated $story_count stories"
    echo ""

    # ═══════════════════════════════════════════════════════════════════════════
    # PHASE 1.5: Populate requirements.md if Phase 1 left it as placeholder
    # ═══════════════════════════════════════════════════════════════════════════
    if is_requirements_placeholder "$req_file"; then
        log "INFO" "requirements.md still placeholder — running dedicated fill pass..."
        local req_prompt=$(mktemp)
        create_requirements_fill_prompt "$project_name" > "$req_prompt"
        local req_log="$project_dir/logs/requirements_${timestamp}.log"
        start_spinner "(Populating requirements.md)..."
        cd "$REPO_ROOT"
        local prd_rel="projects/$project_name/prd.md"
        local req_rel="projects/$project_name/requirements.md"
        if aider "$prd_rel" "$req_rel" --model "$AIDER_MODEL" --yes --no-stream --no-show-model-warnings --message-file "$req_prompt" > "$req_log" 2>&1; then
            log "SUCCESS" "requirements.md populated"
        else
            log "WARN" "requirements fill pass failed — check $(get_relative_path "$req_log")"
        fi
        stop_spinner
        rm -f "$req_prompt"
        # Fallback: if Aider showed a diff but didn't apply it, extract from log and write
        if is_requirements_placeholder "$req_file" && [[ -f "$req_log" ]]; then
            local extracted
            extracted=$(awk '/^[[:space:]]*@@.*@@[[:space:]]*$/{ in_diff=1; next }
                in_diff && /^[[:space:]]*\+/ { sub(/^[[:space:]]*\+[[:space:]]?/, ""); print }
                in_diff && /^[[:space:]]* [^+-]/ { sub(/^[[:space:]]+ ?/, ""); print }' "$req_log" | sed 's/[[:space:]]*$//')
            if [[ -n "$extracted" ]] && [[ $(echo "$extracted" | wc -l) -gt 2 ]]; then
                echo "$extracted" > "$req_file"
                log "INFO" "Recovered requirements.md from log ($(echo "$extracted" | wc -l) lines)"
            fi
        fi
        echo ""
    fi

    # ═══════════════════════════════════════════════════════════════════════════
    # PHASE 2: Verification Loop
    # ═══════════════════════════════════════════════════════════════════════════
    log "INFO" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log "INFO" "PHASE 2: Verifying completeness against PRD"
    log "INFO" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # Save a copy of current stories for comparison
    local stories_before=$(mktemp)
    cp "$json_file" "$stories_before"

    local verify_prompt=$(mktemp)
    create_verification_prompt "$project_dir" > "$verify_prompt"

    local verify_log="$project_dir/logs/verify_${timestamp}.log"
    log "INFO" "Log file: $(get_relative_path "$verify_log")"

    # Run verification with Aider
    start_spinner "(Phase 2: Verification & gap analysis)..."
    local verify_success=true
    
    cd "$REPO_ROOT"
    local prd_rel="projects/$project_name/prd.md"
    local json_rel="projects/$project_name/prd.json"
    local req_rel="projects/$project_name/requirements.md"

    # Build Aider command for verification
    local aider_cmd=(
        aider
        "$prd_rel"
        "$json_rel"
        "$req_rel"
        --model "$AIDER_MODEL"
        --yes
        --no-stream
        --no-show-model-warnings
        --message-file "$verify_prompt"
    )
    
    if [ "$AIDER_AUTO_COMMITS" = true ]; then
        aider_cmd+=(--auto-commits)
    fi
    # Do NOT add --commit: same as Phase 1, would exit before processing message-file.

    if [ "$AIDER_NO_PRETTY" = true ]; then
        aider_cmd+=(--no-pretty)
    fi
    
    # Execute Aider
    if ! "${aider_cmd[@]}" > "$verify_log" 2>&1; then
        verify_success=false
    fi
    stop_spinner

    rm -f "$verify_prompt"

    if [[ "$verify_success" != "true" ]]; then
        log "WARN" "Verification phase failed - but initial conversion succeeded"
        log "INFO" "Check log: $(get_relative_path "$verify_log")"
    else
        # Compare before/after to count added and edited stories
        local added_count=0
        local edited_count=0
        local final_story_count=0
        
        if [[ -f "$json_file" ]]; then
            final_story_count=$(jq '.userStories | length' "$json_file" 2>/dev/null || echo "0")
            
            # Get IDs from before and after
            local ids_before=$(jq -r '.userStories[].id' "$stories_before" 2>/dev/null | sort)
            local ids_after=$(jq -r '.userStories[].id' "$json_file" 2>/dev/null | sort)
            
            # Count new IDs (added stories)
            while IFS= read -r id; do
                if [[ -n "$id" ]] && ! echo "$ids_before" | grep -qx "$id"; then
                    added_count=$((added_count + 1))
                fi
            done <<< "$ids_after"
            
            # Count edited stories (same ID but different content)
            while IFS= read -r id; do
                if [[ -n "$id" ]] && echo "$ids_after" | grep -qx "$id"; then
                    # Compare the story content (excluding 'passes' and 'notes' which might change)
                    local before_content=$(jq -c --arg id "$id" '.userStories[] | select(.id == $id) | del(.passes, .notes)' "$stories_before" 2>/dev/null)
                    local after_content=$(jq -c --arg id "$id" '.userStories[] | select(.id == $id) | del(.passes, .notes)' "$json_file" 2>/dev/null)
                    if [[ "$before_content" != "$after_content" ]]; then
                        edited_count=$((edited_count + 1))
                    fi
                fi
            done <<< "$ids_before"
        fi
        
        # Build result message
        local changes=""
        if [[ $added_count -gt 0 ]]; then
            changes="Added $added_count"
        fi
        if [[ $edited_count -gt 0 ]]; then
            if [[ -n "$changes" ]]; then
                changes="$changes, Edited $edited_count"
            else
                changes="Edited $edited_count"
            fi
        fi
        
        if [[ -n "$changes" ]]; then
            log "SUCCESS" "Phase 2 complete: $changes (total: $final_story_count)"
        else
            log "SUCCESS" "Phase 2 complete: Verified all $final_story_count stories (no changes needed)"
        fi
    fi
    
    # Cleanup
    rm -f "$stories_before"

    echo ""

    # ═══════════════════════════════════════════════════════════════════════════
    # SUMMARY
    # ═══════════════════════════════════════════════════════════════════════════
    local final_count=$(jq '.userStories | length' "$json_file" 2>/dev/null || echo "0")
    
    echo "═══════════════════════════════════════════════════════"
    echo "  CONVERSION COMPLETE"
    echo "═══════════════════════════════════════════════════════"
    echo ""
    echo "Branch: $(jq -r '.branchName // "not set"' "$json_file")"
    echo "Total stories: $final_count"
    echo ""
    echo "Stories by category:"
    jq -r '.userStories | group_by(.category) | .[] | "  \(.[0].category): \(length) stories"' "$json_file" 2>/dev/null || echo "  (unable to group)"
    echo ""
    echo "First 5 stories (by priority):"
    jq -r '.userStories | sort_by(.priority) | .[:5][] | "  [\(.id)] P\(.priority) (\(.category)) \(.story)"' "$json_file"
    echo ""
    echo "═══════════════════════════════════════════════════════"
    echo ""
    echo "Logs:"
    echo "  - Conversion: $(get_relative_path "$convert_log")"
    echo "  - Verification: $(get_relative_path "$verify_log")"
    echo ""
    echo "Next steps:"
    echo "  1. Review: cat $json_file | jq ."
    echo "  2. Start:  ./start.sh $project_name"
    echo ""
}

# Parse command line arguments
MODE="${RALPH_MODE:-claude}"
PROJECT_NAME=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        --model)
            MODE="$2"
            shift 2
            ;;
        *)
            if [[ -z "$PROJECT_NAME" ]]; then
                PROJECT_NAME="$1"
            fi
            shift
            ;;
    esac
done

# Setup Aider based on mode
setup_aider "$MODE"

# Check dependencies
check_dependencies || exit 1

# Validate project name
if [[ -z "$PROJECT_NAME" ]]; then
    log "ERROR" "Project name is required"
    show_help
    exit 1
fi

# Run main function
main "$PROJECT_NAME"
