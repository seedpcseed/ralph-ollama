# PRD to Tasks Conversion (v2.0 Format)

**Context:** If your model reports "exceeds the N token limit" (e.g. 16,384), use the shorter prompt: `docs/convert-prompt-aider-compact.md`. Or use a model with a larger context (e.g. 32k+) or increase Ollama's context (see docs/AIDER-PROMPTING.md).

You are a JSON generator. Your task is to generate the complete prd.json file content based on the PRD.

**IMPORTANT:** Generate the complete JSON content. You can provide it in any format - we will extract it. Just make sure the JSON is valid and complete.

## Your task
1. Read projects/editio/prd.md (it is in the chat) to understand ALL requirements.
2. Edit projects/editio/prd.json: replace its entire contents with a JSON object that has "version": "2.0", "branchName": "ralph/editio", "createdAt", "updatedAt", and "userStories": [ ... ] — an array of story objects in v2.0 format.

**CRITICAL: Story Generation Strategy**
- **Each P0 feature in the PRD should become 5-15 granular stories** (NOT 1-3 stories!)
- Each story should be completable in 1-2 iterations (not require multiple refinement passes)
- Create stories in dependency order (infrastructure → core → features → polish)
- Include verification commands in acceptance criteria or verify field
- **For a complex PRD with 10+ P0 features, expect 50-150+ stories total** (not 15-30!)

**Example breakdown for "Markdown Parsing" feature (this ONE feature needs 15+ stories):**
- Story 1.1: "Add pulldown-cmark dependency to Cargo.toml" (verify: grep -q pulldown-cmark Cargo.toml)
- Story 1.2: "Create AST Node enum with Headline variant" (verify: grep -q 'Headline' src/ast.rs && cargo build --lib)
- Story 1.3: "Add Paragraph variant to AST Node enum" (verify: grep -q 'Paragraph' src/ast.rs && cargo build --lib)
- Story 1.4: "Add CodeBlock variant to AST Node enum" (verify: grep -q 'CodeBlock' src/ast.rs && cargo build --lib)
- Story 1.5: "Add Table variant to AST Node enum" (verify: grep -q 'Table' src/ast.rs && cargo build --lib)
- Story 1.6: "Add Image variant with YAML attributes support" (verify: grep -q 'Image' src/ast.rs && cargo build --lib)
- Story 1.7: "Implement parse_headings() for # headings" (verify: cargo test test_parse_headings)
- Story 1.8: "Implement parse_paragraphs() for text blocks" (verify: cargo test test_parse_paragraphs)
- Story 1.9: "Implement parse_code_blocks() for ``` blocks" (verify: cargo test test_parse_code_blocks)
- Story 1.10: "Implement parse_tables() for markdown tables" (verify: cargo test test_parse_tables)
- Story 1.11: "Implement parse_images() with YAML attribute parsing" (verify: cargo test test_parse_images_with_attrs)
- Story 1.12: "Implement parse_links() for [text](url) syntax" (verify: cargo test test_parse_links)
- Story 1.13: "Implement parse_lists() for ordered and unordered lists" (verify: cargo test test_parse_lists)
- Story 1.14: "Add CommonMark compliance tests" (verify: cargo test commonmark_compliance)
- Story 1.15: "Add GFM extension tests (strikethrough, tables, task lists)" (verify: cargo test gfm_extensions)

3. Edit projects/editio/requirements.md: replace or expand with technical specifications taken from the PRD (architecture, data models, API, UI, performance, security).

## Story object shape (v2.0 format - for each item in userStories)
- id: e.g. "1.1", "1.2", "1.3" (sequential, can have sub-stories like "1.2.1")
- category: "technical" | "functional" | "ui"
- story: one sentence, action verb, specific and granular
- steps: array of 2-5 concrete, actionable steps
- acceptance: testable criteria with verification command (see below)
- priority: 1-10 (lower first, dependencies before dependents)

**v2.0 Enhanced Fields (REQUIRED):**
- status: "pending" (all stories start as pending)
- progress: 0 (all stories start at 0%)
- lastAttempt: null
- attemptCount: 0
- dependsOn: [] (array of story IDs that must be complete first - set based on dependencies)
- blocks: [] (array of story IDs blocked by this one)
- verify: { command: "...", lastRun: null, lastResult: "not_run", expectedResult: "pass" }
- files: [] (will be populated during implementation)
- tests: [] (will be populated during implementation)
- errors: [] (will be populated during implementation)
- notes: ""
- createdAt: (current timestamp in ISO format)
- updatedAt: (current timestamp in ISO format)

Categories: technical = DB/API/backend/schemas/infrastructure; functional = business logic/features; ui = frontend/pages/styling. Order by dependency (infra before features).

## CRITICAL: Story Granularity Rules

**Break down large features into small, verifiable stories.** Each story should be completable in 1-2 iterations (not require multiple passes).

**BAD (too broad - these are MULTIPLE stories each):**
- "Implement markdown parser" → This is 15-20 stories! Break it down!
- "Design two-pass layout engine" → This is 20+ stories! Break it down!
- "Create CLI interface" → This is 8-10 stories! Break it down!
- "Implement parse_markdown() function" → Still too broad! Break into parse_headings(), parse_paragraphs(), etc.
- "Add tests for CommonMark features" → Too broad! One test file per feature!

**GOOD (granular and verifiable - ONE concept per story):**
- "Add pulldown-cmark dependency to Cargo.toml" → Verifiable: grep -q pulldown-cmark Cargo.toml
- "Create AST Node enum with Headline variant" → Verifiable: grep -q 'Headline' src/ast.rs && cargo build --lib
- "Implement parse_headings() function for # syntax" → Verifiable: cargo test test_parse_headings
- "Add test for heading levels 1-6" → Verifiable: cargo test test_heading_levels
- "Create CLI Args struct with clap derive" → Verifiable: grep -q 'struct Args' src/cli.rs && cargo build --lib
- "Add 'compile' subcommand to CLI" → Verifiable: cargo build --bin editio && ./target/debug/editio compile --help

**Breakdown strategy:**
1. **Dependencies first**: Add library → Create types → Implement functions → Add tests
2. **One concept per story**: Don't combine multiple concepts - split them aggressively
   - "Implement parser" → Split into parse_headings(), parse_paragraphs(), parse_code_blocks(), etc.
   - "Add tests" → Split into one test file/function per feature
   - "Create CLI" → Split into Args struct, compile command, check command, error handling, etc.
3. **Each story should create/modify 1-2 files max**: If more, break it down
4. **Each story should implement ONE function/type/test**: Not multiple things
5. **Verifiable completion**: Each story must have a way to verify it's done (build, test, grep, etc.)
6. **Count your stories**: If you have fewer than 50 stories for a complex PRD, you're not granular enough!

## Acceptance Criteria Format

**Include verification commands in acceptance criteria.** Use one of these formats:

**Format 1: RUN command in acceptance**
```
"acceptance": "RUN 'cargo test parser' must pass. The parser handles headings, paragraphs, and code blocks."
```

**Format 2: Separate verify field**
```
"acceptance": "The parser handles headings, paragraphs, and code blocks.",
"verify": {
  "command": "cargo test parser",
  "expectedResult": "pass"
}
```

**Format 3: File existence check**
```
"acceptance": "Cargo.toml includes pulldown-cmark dependency.",
"verify": {
  "command": "grep -q pulldown-cmark Cargo.toml",
  "expectedResult": "pass"
}
```

**Verification examples by language:**
- **Rust**: cargo build, cargo test --lib parser, cargo check
- **Python**: pytest tests/test_parser.py, python -m mypy parser.py
- **Node**: npm test, node -e "require('./parser')"
- **Go**: go test ./parser, go build
- **File checks**: grep -q 'function_name' file.rs, test -f path/to/file

## Output Format

Provide the complete prd.json content as valid JSON. You can wrap it in markdown code blocks or provide it directly - we will extract it.

**Example structure:**
```json
{
  "version": "2.0",
  "branchName": "ralph/editio",
  "createdAt": "2026-02-04T08:00:00Z",
  "updatedAt": "2026-02-04T08:00:00Z",
  "userStories": [
    {
      "id": "1.1",
      "category": "technical",
      "story": "Add pulldown-cmark dependency to Cargo.toml",
      "steps": ["Open Cargo.toml", "Add pulldown-cmark = \"0.9\" to [dependencies]"],
      "acceptance": "Cargo.toml includes pulldown-cmark dependency.",
      "priority": 1,
      "status": "pending",
      "progress": 0,
      "lastAttempt": null,
      "attemptCount": 0,
      "dependsOn": [],
      "blocks": [],
      "verify": {
        "command": "grep -q pulldown-cmark Cargo.toml",
        "lastRun": null,
        "lastResult": "not_run",
        "expectedResult": "pass"
      },
      "files": [],
      "tests": [],
      "errors": [],
      "notes": "",
      "createdAt": "2026-02-04T08:00:00Z",
      "updatedAt": "2026-02-04T08:00:00Z"
    }
    // Generate 50-150+ more stories covering ALL features in the PRD
  ]
}
```

**CRITICAL REQUIREMENTS - YOU MUST GENERATE ALL STORIES:**

The PRD has 11 P0 features. You MUST generate stories for EACH feature:

1. **Markdown Parsing** (15+ stories): pulldown-cmark dependency, AST Node enum variants (Headline, Paragraph, CodeBlock, Table, Image, Link, List), parse functions for each, CommonMark tests, GFM tests
2. **Two-Pass Layout Engine** (20+ stories): Layout struct, first pass (measure), second pass (place), float algorithm, text wrapping, list wrapping, figure placement
3. **PDF Output** (10+ stories): printpdf dependency, PDF document creation, page setup, content rendering, font handling
4. **Cross-References** (8+ stories): Reference struct, label tracking, reference resolution, figure references, table references, equation references, section references
5. **Academic Extensions** (8+ stories): Theorem environment, Proof environment, Algorithm listing, Pseudocode listing, Code listing with captions
6. **Math Typesetting** (8+ stories): Inline math parsing, display math parsing, LaTeX syntax support, pdflatex subprocess, basic symbols, fractions, superscripts/subscripts
7. **Bibliography System** (8+ stories): BibTeX parser, citation parsing, citation styles (APA, MLA, Chicago, IEEE), author-year format, numeric format, bibliography generation
8. **Figure Support** (8+ stories): Image parsing with YAML attributes, figure numbering, captions, cross-referencing, text wrapping integration
9. **Table Support** (8+ stories): Table parsing, table numbering, captions, cross-referencing, column alignment
10. **Document Formatting** (10+ stories): YAML front matter parsing, page settings, margins, page size, font size, headers/footers, page numbering, section formatting
11. **CLI Interface** (8+ stories): clap dependency, Args struct, compile command, check command, file argument, output flag, error handling

**TOTAL: Generate 50-150+ stories covering ALL features above.**

**DO NOT:**
- Use "..." or "more stories here" - generate ALL stories
- Skip features - every P0 feature needs stories
- Give examples - provide the complete list

**Generate the complete JSON with ALL stories now.**
