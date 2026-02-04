# Ralph 2.0 Refactor - Product Requirements Document

**Version:** 1.0  
**Date:** 2026-02-04  
**Status:** Draft  
**Author:** Ralph Development Team

---

## 1. Executive Summary

### Problem Statement

The current Ralph-Ollama system (v1.0) has fundamental architectural flaws that result in:
- **Poor code quality**: Generated code is incomplete, broken, and doesn't compile
- **False completion**: Stories marked complete (`passes: true`) but code doesn't work
- **Missing features**: Only 15 stories generated for PRD with 11 major P0 features
- **No verification loop**: No compilation/testing feedback, no iterative refinement
- **Weak context awareness**: Aider's repo-map limitations prevent understanding project structure

**Evidence**: The editio project demonstrates all these failures:
- 15 stories marked complete, but only 27 lines of broken Rust code
- Code doesn't compile (missing imports, incomplete functions)
- Missing 10 of 11 major features (CLI, layout engine, PDF output, bibliography, etc.)

### Solution

Refactor Ralph to use **Cursor Agent + MCP (Model Context Protocol) + Multi-Model Architecture**:
- **Cursor Agent**: Native IDE integration, better context awareness, iterative refinement
- **MCP Tools**: Structured, reliable file/git/terminal operations
- **Multi-Model**: Smart selection between Claude API (quality) and local Ollama (cost)
- **Verification Loop**: Compile, test, iterate until code actually works

### Success Criteria

- ✅ **Story Generation**: 80-120+ stories for complex PRD (vs. current 15)
- ✅ **Code Quality**: Generated code compiles and passes tests
- ✅ **Completion Accuracy**: Stories complete only when tests pass (not just "file modified")
- ✅ **Feature Coverage**: All P0 features from PRD are broken down into stories
- ✅ **Cost Efficiency**: 80%+ of tasks use local models (free), only complex use Claude API

---

## 2. Goals & Success Metrics

### Goals

1. **Replace Aider with Cursor Agent** for better code understanding and iterative refinement
2. **Integrate MCP** for reliable, structured tool operations
3. **Implement verification loop** that compiles, tests, and iterates until code works
4. **Smart model selection** based on task complexity (local vs. Claude API)
5. **Maintain backward compatibility** with existing prd.json format and project structure

### Success Metrics

- **Code Quality**: 95%+ of generated code compiles without errors
- **Test Coverage**: 80%+ of stories have passing verification tests
- **Feature Coverage**: 100% of P0 features broken down into stories
- **Cost Efficiency**: <20% of tasks use Claude API (80%+ use local models)
- **Completion Accuracy**: <5% false positives (stories marked complete but broken)

---

## 3. User Personas

1. **Developer**: Wants autonomous system that generates working code, not broken stubs
2. **Project Manager**: Needs accurate progress tracking (stories complete = code works)
3. **Cost-Conscious User**: Wants free local development with option for Claude quality
4. **System Architect**: Needs reliable, extensible architecture with proper verification

---

## 4. Feature Scope

### 4.1 MVP (Phase 1) - Core Refactor

**Priority: HIGHEST**

Core functionality for Ralph 2.0 with Cursor Agent and verification loop.

| Feature | Description | Priority |
|---------|-------------|----------|
| **Cursor Agent Integration** | Replace Aider with Cursor Agent for code editing | P0 |
| **MCP Tool Integration** | File operations, git operations, terminal execution via MCP | P0 |
| **Verification Loop** | Compile code, run tests, iterate on errors until passing | P0 |
| **Model Selection Logic** | Choose Claude API vs. local Ollama based on task complexity | P0 |
| **convert-v2.sh** | PRD → prd.json conversion using Cursor Agent | P0 |
| **start-v2.sh** | Main loop orchestration with verification | P0 |
| **Progress Tracking** | Update progress.txt with learnings and errors | P0 |
| **Backward Compatibility** | Support existing prd.json format and project structure | P0 |

### 4.2 Phase 2 - Enhancements

**Priority: HIGH**

| Feature | Description | Priority |
|---------|-------------|----------|
| **Custom MCP Tools** | Project-specific verification tools (cargo test, pytest, etc.) | P1 |
| **Error Analysis** | Categorize errors (syntax, import, logic) and provide guidance | P1 |
| **Iterative Refinement** | Multiple attempts with error feedback before giving up | P1 |
| **Model Fallback** | If local model fails, retry with Claude API | P1 |
| **Cost Tracking** | Monitor API usage, set budgets/alerts | P1 |
| **Performance Optimization** | Parallel story execution, caching, incremental compilation | P1 |

### 4.3 Phase 3 - Advanced Features

**Priority: MEDIUM**

| Feature | Description | Priority |
|---------|-------------|----------|
| **Hybrid Execution** | Run multiple stories in parallel with different models | P2 |
| **Learning System** | Track what works/fails, improve prompts over time | P2 |
| **Template System** | Reusable prompts and verification patterns per language | P2 |
| **Web Dashboard** | Visual progress tracking, story status, cost monitoring | P2 |
| **Plugin Architecture** | Extensible MCP tools, custom verification strategies | P2 |

---

## 5. Technical Architecture

### 5.1 Core Components

```
┌─────────────────────────────────────────────────────────────┐
│                    Ralph 2.0 Architecture                   │
└─────────────────────────────────────────────────────────────┘

┌──────────────┐
│ convert-v2.sh│ → Cursor Agent + PRD → prd.json
└──────────────┘   (Model: Claude API for quality)

┌──────────────┐
│  start-v2.sh │ → Main orchestration loop
└──────────────┘
       │
       ├─→ Story Selection (from prd.json)
       │
       ├─→ Context Building
       │   ├─→ Read relevant files (via MCP)
       │   ├─→ Read progress.txt
       │   └─→ Read PRD section
       │
       ├─→ Model Selection
       │   ├─→ Simple task? → Local model (Ollama)
       │   ├─→ Complex task? → Claude API
       │   └─→ Architecture decision? → Claude API
       │
       ├─→ Cursor Agent Execution
       │   ├─→ Uses MCP tools for file operations
       │   ├─→ Uses MCP tools for git operations
       │   └─→ Uses MCP tools for terminal/compilation
       │
       ├─→ Verification Loop
       │   ├─→ Compile code (cargo build / via MCP)
       │   ├─→ Run tests (cargo test / via MCP)
       │   ├─→ Check specific verify command
       │   └─→ If fails → Iterate with error feedback
       │
       └─→ Story Completion
           ├─→ All checks pass? → Mark complete
           └─→ Update progress.txt with learnings
```

### 5.2 MCP Tool Integration

**Required MCP Tools:**
- `mcp_filesystem_read` - Read files
- `mcp_filesystem_write` - Write files
- `mcp_filesystem_search` - Search files
- `mcp_git_status` - Git status
- `mcp_git_commit` - Git commit
- `mcp_terminal_execute` - Run commands (compile, test, verify)

**Custom MCP Tools:**
- `ralph_verify_story` - Run story-specific verification
- `ralph_compile_project` - Compile project (language-aware)
- `ralph_run_tests` - Run tests (language-aware)

### 5.3 Model Selection Logic

```bash
# Pseudocode for model selection
if story.priority <= 3 || story.category == "architecture":
    model = "claude-sonnet-4-5"  # Critical/complex → Claude
elif story.steps.length > 5:
    model = "claude-sonnet-4-5"  # Complex → Claude
else:
    model = "ollama/deepseek-coder:33b"  # Simple → Local
```

### 5.4 Verification Loop

```bash
# Pseudocode for verification loop
max_attempts = 5
attempt = 0

while attempt < max_attempts:
    # Run Cursor Agent to implement/fix
    cursor_agent --story "$story" --errors "$previous_errors"
    
    # Compile
    compile_result = mcp_terminal_execute("cargo build")
    if compile_result.exit_code != 0:
        previous_errors = compile_result.stderr
        attempt++
        continue
    
    # Run tests
    test_result = mcp_terminal_execute("cargo test")
    if test_result.exit_code != 0:
        previous_errors = test_result.stderr
        attempt++
        continue
    
    # Run story-specific verification
    verify_result = mcp_terminal_execute(story.verify)
    if verify_result.exit_code != 0:
        previous_errors = verify_result.stderr
        attempt++
        continue
    
    # All checks passed!
    mark_story_complete(story.id)
    break

if attempt >= max_attempts:
    log_error("Story failed after $max_attempts attempts")
    update_progress("Story $story.id failed: $previous_errors")
```

---

## 6. Implementation Plan

### Phase 1: Proof of Concept (Days 1-2)

**Goal**: Validate Cursor Agent + MCP approach

1. **Research & Setup**
   - [ ] Research Cursor Agent invocation methods
   - [ ] Set up MCP server/tools
   - [ ] Test Cursor Agent with simple task

2. **convert-v2.sh Prototype**
   - [ ] Create basic convert-v2.sh using Cursor Agent
   - [ ] Test PRD → prd.json conversion
   - [ ] Compare quality with current convert.sh

3. **Validation**
   - [ ] Test with editio PRD
   - [ ] Verify story count (should be 80-120+)
   - [ ] Verify story granularity

**Deliverable**: Working convert-v2.sh that generates better stories

### Phase 2: Core Loop Refactor (Days 3-7)

**Goal**: Implement start-v2.sh with verification loop

1. **start-v2.sh Implementation**
   - [ ] Create basic loop structure
   - [ ] Implement story selection
   - [ ] Implement context building
   - [ ] Implement model selection logic

2. **Cursor Agent Integration**
   - [ ] Integrate Cursor Agent for code editing
   - [ ] Use MCP tools for file operations
   - [ ] Use MCP tools for git operations

3. **Verification Loop**
   - [ ] Implement compilation check
   - [ ] Implement test execution
   - [ ] Implement story-specific verification
   - [ ] Implement error feedback loop

**Deliverable**: Working start-v2.sh with verification

### Phase 3: MCP Integration (Days 8-10)

**Goal**: Full MCP tool integration

1. **MCP Server Setup**
   - [ ] Set up MCP server for file operations
   - [ ] Set up MCP server for git operations
   - [ ] Set up MCP server for terminal execution

2. **Custom Tools**
   - [ ] Implement ralph_verify_story tool
   - [ ] Implement ralph_compile_project tool
   - [ ] Implement ralph_run_tests tool

3. **Integration Testing**
   - [ ] Test all MCP tools
   - [ ] Verify error handling
   - [ ] Test with editio project

**Deliverable**: Full MCP integration working

### Phase 4: Testing & Refinement (Days 11-15)

**Goal**: Test and refine the system

1. **Testing**
   - [ ] Test with editio project (full cycle)
   - [ ] Test with other projects
   - [ ] Compare outcomes with v1.0

2. **Refinement**
   - [ ] Improve prompts based on results
   - [ ] Optimize model selection
   - [ ] Improve error handling
   - [ ] Add cost tracking

3. **Documentation**
   - [ ] Update README.md
   - [ ] Update CLAUDE.md
   - [ ] Create migration guide

**Deliverable**: Tested, refined system ready for migration

### Phase 5: Migration (Days 16-17)

**Goal**: Replace old system with new

1. **Migration**
   - [ ] Replace convert.sh → convert-v2.sh
   - [ ] Replace start.sh → start-v2.sh
   - [ ] Update all references

2. **Cleanup**
   - [ ] Remove old Aider-based code
   - [ ] Archive old scripts
   - [ ] Update .gitignore

3. **Final Testing**
   - [ ] Test full workflow
   - [ ] Verify backward compatibility
   - [ ] Test migration path

**Deliverable**: Ralph 2.0 fully operational

---

## 7. Technical Requirements

### 7.1 Dependencies

- **Cursor IDE**: Required for Cursor Agent
- **MCP Server**: Required for tool operations
- **Ollama**: Required for local models
- **Claude API**: Required for complex tasks (optional, can use local only)
- **jq**: Required for JSON manipulation
- **Git**: Required for version control

### 7.2 File Structure

```
ralph-ollama/
├── convert-v2.sh          # New conversion script
├── start-v2.sh            # New main loop script
├── lib/
│   ├── cursor_agent.sh   # Cursor Agent integration
│   ├── mcp_tools.sh      # MCP tool wrappers
│   ├── verification.sh    # Verification loop logic
│   └── model_selection.sh # Model selection logic
├── mcp/
│   ├── server.py         # MCP server implementation
│   └── tools/            # Custom MCP tools
├── tests/
│   └── editio-prd.md     # Test PRD (kept from main)
└── projects/             # Existing project structure
```

### 7.3 Backward Compatibility

- **prd.json format**: Must support existing format
- **Project structure**: Must work with existing projects
- **Migration path**: Must provide migration script for existing projects

---

## 8. Risks & Mitigations

### Risk 1: Cursor Agent API Limitations
- **Impact**: High - Core functionality depends on Cursor Agent
- **Mitigation**: Research Cursor Agent capabilities thoroughly before starting
- **Fallback**: Use MCP for operations Cursor doesn't support, keep Aider as backup

### Risk 2: MCP Integration Complexity
- **Impact**: Medium - MCP is new technology
- **Mitigation**: Start with simple MCP tools, iterate
- **Fallback**: Use direct file/git operations if MCP fails

### Risk 3: Claude API Costs
- **Impact**: Medium - Could be expensive if model selection fails
- **Mitigation**: Aggressive model selection (80%+ local), cost tracking, budgets
- **Fallback**: Default to local models, only use Claude when explicitly needed

### Risk 4: Verification Loop Complexity
- **Impact**: Medium - Complex error handling and iteration
- **Mitigation**: Start simple, iterate based on testing
- **Fallback**: Basic verification (compile only) if full loop too complex

### Risk 5: Migration Disruption
- **Impact**: Low - Can run parallel systems
- **Mitigation**: Keep old system until new one proven, gradual migration
- **Fallback**: Rollback to v1.0 if needed

---

## 9. Success Metrics

### Quantitative Metrics

- **Story Count**: 80-120+ stories for complex PRD (vs. current 15)
- **Code Quality**: 95%+ of generated code compiles without errors
- **Test Coverage**: 80%+ of stories have passing verification tests
- **Feature Coverage**: 100% of P0 features broken down into stories
- **Cost Efficiency**: <20% of tasks use Claude API (80%+ use local models)
- **Completion Accuracy**: <5% false positives (stories marked complete but broken)

### Qualitative Metrics

- **Code Completeness**: Generated code is complete, not stubs
- **Error Handling**: System handles errors gracefully, provides feedback
- **User Experience**: System is easy to use, clear progress tracking
- **Documentation**: Clear documentation for users and developers

---

## 10. Open Questions

1. **Cursor Agent Invocation**: How to invoke Cursor Agent programmatically?
   - Need to research Cursor's API/CLI
   - May need to use Cursor's MCP server

2. **MCP Server Setup**: What MCP server to use?
   - Cursor's built-in MCP?
   - Custom MCP server?
   - Third-party MCP server?

3. **Model Selection**: How to determine task complexity?
   - Based on story priority?
   - Based on story category?
   - Based on number of steps?
   - Machine learning approach?

4. **Error Categorization**: How to categorize errors for better feedback?
   - Syntax errors
   - Import errors
   - Logic errors
   - Test failures

5. **Cost Tracking**: How to track and limit API costs?
   - Per-project budgets?
   - Per-story budgets?
   - Daily/weekly limits?

---

## 11. Approval & Sign-off

**Status**: Draft - Awaiting review and approval

**Next Steps**:
1. Review this PRD
2. Answer open questions
3. Approve or request changes
4. Begin Phase 1 implementation

---

## Appendix A: Comparison with Current System

| Aspect | Current (v1.0) | Proposed (v2.0) |
|--------|----------------|-----------------|
| **Code Editor** | Aider | Cursor Agent |
| **Context Awareness** | Limited (repo-map) | Full (IDE integration) |
| **Verification** | None (file modified = complete) | Full (compile + test + verify) |
| **Error Handling** | None | Iterative refinement |
| **Model Selection** | Single model | Smart selection (local vs. Claude) |
| **Tool Operations** | Aider commands | MCP tools |
| **Code Quality** | Poor (broken, incomplete) | Good (compiles, tests pass) |
| **Story Granularity** | Low (15 stories) | High (80-120+ stories) |
| **Completion Accuracy** | Low (false positives) | High (real verification) |

---

## Appendix B: Example Story Breakdown

### Current System (v1.0) - Too Broad
```json
{
  "id": "1.3",
  "story": "Implement parse_markdown() function",
  "verify": "cargo test parser"
}
```
**Problem**: Too broad, no actual implementation, marked complete but broken

### Proposed System (v2.0) - Granular
```json
{
  "id": "1.7",
  "story": "Implement parse_headings() for # headings",
  "steps": [
    "Create parse_headings() function in parser.rs",
    "Handle # through ###### syntax",
    "Extract heading text and level",
    "Return Vec<Node::Headline>"
  ],
  "verify": "cargo test test_parse_headings",
  "priority": 7
}
```
**Benefit**: Specific, verifiable, will actually be implemented correctly
