# Ralph Architecture Issues & Proposed Solutions

## Current Problems

### 1. **No Verification Loop**
- Stories marked complete when files are created, not when they work
- `lib/verification.sh` exists but is never called in `start.sh`
- No `cargo build`, `cargo test`, or other verification after implementation
- 18 TODO/unimplemented! markers found in editio project

### 2. **Stories Too High-Level**
- "Implement markdown parser" is one story → should be 5-10 granular stories
- "Design two-pass layout engine" → should be broken into smaller tasks
- Each story should be completable in 1-2 iterations, not require multiple passes

### 3. **Acceptance Criteria Not Verifiable**
- "The markdown parser can parse CommonMark" → can't be automatically verified
- Should include: `RUN "cargo test parser"` or `RUN "cargo build --lib"`
- Need executable verification commands, not just descriptions

### 4. **No Iterative Refinement**
- Once `passes: true`, story is never revisited
- If model creates skeleton with TODOs, it stays incomplete forever
- Need sub-loops: implement → verify → if fails, refine → verify again

### 5. **Completion Logic Flawed**
- Current: `if files_modified > 0 → mark complete`
- Should be: `if files_modified > 0 AND verification passes AND no TODOs → mark complete`

## Proposed Solutions

### Solution 1: Add Verification to Loop

**In `start.sh` after file creation:**
```bash
# After files are created/modified
if [[ "${files_modified:-0}" -gt 0 ]]; then
    # Run verification if defined
    if verify_story "$project_dir" "$story_json"; then
        mark_story_complete "$project_dir/prd.json" "$story_id"
    else
        log "WARN" "Story $story_id: verification failed, will retry"
        # Don't mark complete, will retry next loop
    fi
fi
```

**Verification should:**
- Check for TODOs/unimplemented! in created files
- Run `cargo build` for Rust projects
- Run `cargo test` if tests exist
- Run story-specific `verify` command if defined
- Parse `RUN "command"` from acceptance criteria

### Solution 2: More Granular Stories from convert.sh

**Enhance `convert.sh` prompt:**
- Break large features into smaller, verifiable tasks
- Each story should be completable in 1-2 iterations
- Stories should have clear, executable acceptance criteria

**Example breakdown:**
- ❌ "Implement markdown parser" (too broad)
- ✅ "Add pulldown-cmark dependency to Cargo.toml" (verifiable: `grep pulldown Cargo.toml`)
- ✅ "Create AST node enum with Headline, Paragraph, CodeBlock variants" (verifiable: `cargo build`)
- ✅ "Implement parse_markdown() function that returns AST" (verifiable: `cargo test parser`)

### Solution 3: Verifiable Acceptance Criteria

**Update story schema to require:**
```json
{
  "id": "1.2",
  "acceptance": "The markdown parser can parse CommonMark.",
  "verify": "cargo test --lib parser",
  "verify_pattern": "test.*parser.*ok"
}
```

**Or use RUN syntax in acceptance:**
```
"acceptance": "RUN 'cargo test parser' must pass. The parser handles headings, paragraphs, and code blocks."
```

### Solution 4: Iterative Refinement Sub-Loops

**Add refinement loop:**
```bash
# After initial implementation
local max_refinements=3
local refinement=0
while [[ $refinement -lt $max_refinements ]]; do
    if verify_story "$project_dir" "$story_json"; then
        if ! has_todos "$project_dir" "$story_id"; then
            mark_story_complete "$project_dir/prd.json" "$story_id"
            break
        fi
    fi
    # Refinement needed - run another Aider pass with feedback
    refinement=$((refinement + 1))
    run_refinement_pass "$project_dir" "$story_id" "$refinement"
done
```

### Solution 5: Fix Completion Logic

**New logic:**
```bash
if [[ "${files_modified:-0}" -gt 0 ]]; then
    # Check for TODOs/unimplemented!
    if has_todos "$project_dir" "$story_id"; then
        log "WARN" "Story $story_id has TODOs - not marking complete"
        # Continue to refinement loop
    elif verify_story "$project_dir" "$story_json"; then
        mark_story_complete "$project_dir/prd.json" "$story_id"
    else
        log "WARN" "Story $story_id: verification failed - will refine"
        # Continue to refinement loop
    fi
fi
```

## Implementation Priority

1. **High Priority:**
   - Add verification step to start.sh loop
   - Detect TODOs/unimplemented! and don't mark complete
   - Fix completion logic to require verification

2. **Medium Priority:**
   - Enhance convert.sh to create more granular stories
   - Add verifiable acceptance criteria (RUN commands)
   - Add iterative refinement sub-loops

3. **Low Priority:**
   - Better story breakdown prompts
   - Automatic test generation
   - Progress tracking for refinements

## Questions to Answer

1. Should verification be mandatory for all stories, or optional?
2. How many refinement iterations before giving up?
3. Should convert.sh be enhanced, or should we add a "breakdown" phase?
4. How to handle stories that legitimately have TODOs (future work)?
