# Architecture Evaluation: Current State vs. Proposed Refactor

## Executive Summary

**Current State**: Ralph-Ollama uses Aider + Ollama for autonomous development
**Outcome**: **FAILURE** - Generated code is incomplete, broken, and doesn't compile
**Recommendation**: **YES, refactor to Cursor Agent + MCP + Multi-Model Architecture**

---

## Current System Analysis

### What We Built
- **Aider Integration**: Uses Aider CLI for code editing
- **Ollama Support**: Local LLM models via Ollama
- **Bash Orchestration**: Scripts manage the loop
- **JSON Task Management**: prd.json tracks stories

### What Actually Happened (editio project)

#### Story Generation (convert.sh)
- ✅ Generated 15 stories (improved from 5)
- ❌ Still insufficient - PRD has 11 major P0 features, should have 50-150+ stories
- ❌ Only covered markdown parsing (1 of 11 features)
- ❌ Missing: CLI, layout engine, PDF output, bibliography, math, figures, tables, etc.

#### Implementation Quality (start.sh)
- ❌ **All 15 stories marked `passes: true`** but code is broken
- ❌ Only 27 lines of Rust code total
- ❌ Code doesn't compile: missing imports, incomplete functions
- ❌ No actual implementation - just stubs and placeholders
- ❌ Missing critical files: `main.rs`, CLI, layout engine, etc.

#### Root Causes

1. **Aider Limitations**:
   - Aider applies edits but doesn't verify correctness
   - No compilation/testing feedback loop
   - Stories marked complete based on "files modified" not "code works"
   - Poor context awareness - doesn't understand project structure

2. **Local Model Limitations**:
   - `deepseek-coder:33b` generates incomplete code
   - No iterative refinement when code fails
   - Can't see compilation errors or test failures
   - Limited reasoning about complex systems

3. **Architecture Flaws**:
   - No verification loop (stories marked complete without testing)
   - No feedback mechanism (compiler errors ignored)
   - No iterative refinement (one-shot attempts)
   - Weak context management (Aider's repo-map is limited)

---

## Proposed Architecture: Cursor Agent + MCP + Multi-Model

### Why This Is Better

#### 1. **Cursor Agent Advantages**
- ✅ **Native IDE Integration**: Full context of project structure
- ✅ **Better Code Understanding**: Sees all files, understands relationships
- ✅ **Iterative Refinement**: Can fix errors based on compiler/test output
- ✅ **Multi-file Awareness**: Understands cross-file dependencies
- ✅ **Built-in Verification**: Can run tests, check compilation

#### 2. **MCP (Model Context Protocol) Benefits**
- ✅ **Structured Tool Access**: Reliable file operations, git, terminal
- ✅ **Extensible**: Can add custom tools (compiler, test runner, etc.)
- ✅ **Standardized**: Works across different agents/models
- ✅ **Better Error Handling**: Tools return structured results

#### 3. **Multi-Model Strategy**
- ✅ **Claude API**: For complex reasoning, architecture decisions
- ✅ **Local Models**: For simple tasks, cost savings
- ✅ **Model Selection**: Choose based on task complexity
- ✅ **Fallback**: If local model fails, retry with Claude

#### 4. **Better Verification Loop**
- ✅ **Compile After Each Change**: Catch errors immediately
- ✅ **Run Tests**: Verify functionality, not just file existence
- ✅ **Iterative Refinement**: Fix errors, improve code
- ✅ **Real Completion Criteria**: Story complete when tests pass, not when file modified

---

## Proposed Architecture Design

### Core Components

```
┌─────────────────────────────────────────────────────────────┐
│                    Ralph 2.0 Architecture                   │
└─────────────────────────────────────────────────────────────┘

┌──────────────┐
│  convert.sh  │ → Uses Cursor Agent to convert PRD → prd.json
└──────────────┘   (Can use Claude API for better quality)

┌──────────────┐
│   start.sh   │ → Main orchestration loop
└──────────────┘
       │
       ├─→ Story Selection (from prd.json)
       │
       ├─→ Context Building
       │   ├─→ Read relevant files
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
       │   ├─→ Compile code (cargo build)
       │   ├─→ Run tests (cargo test)
       │   ├─→ Check specific verify command
       │   └─→ If fails → Iterate with error feedback
       │
       └─→ Story Completion
           ├─→ All checks pass? → Mark complete
           └─→ Update progress.txt with learnings
```

### Key Improvements

#### 1. **Smart Model Selection**
```bash
# In start.sh
if [[ "$story_priority" -le 3 ]] || [[ "$story_category" == "architecture" ]]; then
    MODEL="claude-sonnet-4-5"  # Use Claude for critical/complex tasks
else
    MODEL="ollama/deepseek-coder:33b"  # Use local for simple tasks
fi
```

#### 2. **Verification Loop**
```bash
# After each implementation attempt
while ! verify_story "$story"; do
    # Get compilation/test errors
    errors=$(cargo build 2>&1 | grep error)
    
    # Feed errors back to agent
    cursor_agent --fix-errors "$errors" --story "$story"
    
    # Retry verification
done
```

#### 3. **MCP Tool Integration**
- **File Operations**: Read, write, search files reliably
- **Git Operations**: Commit, branch, status
- **Terminal**: Run compilation, tests, verification commands
- **Custom Tools**: Project-specific verification

#### 4. **Better Context Management**
- Read entire project structure
- Understand file dependencies
- Track what's been implemented
- Learn from previous errors

---

## Migration Plan

### Phase 1: Proof of Concept (1-2 days)
1. Create `convert-v2.sh` using Cursor Agent
2. Test PRD → prd.json conversion
3. Compare quality with current convert.sh

### Phase 2: Core Loop Refactor (3-5 days)
1. Create `start-v2.sh` using Cursor Agent
2. Implement verification loop
3. Add model selection logic
4. Test with simple project

### Phase 3: MCP Integration (2-3 days)
1. Set up MCP server for file/git/terminal operations
2. Integrate MCP tools into start-v2.sh
3. Add custom verification tools

### Phase 4: Testing & Refinement (3-5 days)
1. Test with editio project
2. Compare outcomes
3. Refine prompts and verification logic
4. Document new architecture

### Phase 5: Migration (1-2 days)
1. Replace convert.sh → convert-v2.sh
2. Replace start.sh → start-v2.sh
3. Update documentation
4. Deprecate old Aider-based code

---

## Expected Improvements

### Story Generation (convert.sh)
- **Current**: 15 stories, missing 10/11 features
- **Expected**: 80-120 stories, covering all features
- **Why**: Cursor Agent has better PRD understanding

### Implementation Quality (start.sh)
- **Current**: 27 lines, broken code, doesn't compile
- **Expected**: Complete, working implementations
- **Why**: Verification loop catches errors, iterative refinement

### Completion Accuracy
- **Current**: Stories marked complete but code broken
- **Expected**: Stories complete only when tests pass
- **Why**: Real verification, not just "file modified"

### Cost Efficiency
- **Current**: All tasks use same model
- **Expected**: Simple tasks use local (free), complex use Claude
- **Why**: Smart model selection based on task complexity

---

## Risks & Mitigations

### Risk 1: Cursor Agent API Limitations
- **Mitigation**: Use MCP for operations Cursor doesn't support
- **Fallback**: Keep Aider as backup for specific operations

### Risk 2: Claude API Costs
- **Mitigation**: Aggressive model selection (local for 80%+ of tasks)
- **Monitoring**: Track API usage, set budgets

### Risk 3: Migration Complexity
- **Mitigation**: Parallel implementation, test thoroughly before switch
- **Rollback**: Keep old system until new one proven

---

## Recommendation

**YES, proceed with refactor to Cursor Agent + MCP + Multi-Model architecture.**

### Reasons:
1. **Current system is failing** - code quality is unacceptable
2. **Cursor Agent is superior** - better context, iterative refinement
3. **MCP provides reliability** - structured tool access
4. **Multi-model is cost-effective** - use best model for each task
5. **Verification loop is critical** - catch errors early

### Next Steps:
1. Create proof-of-concept convert-v2.sh
2. Test with editio PRD
3. If successful, proceed with full refactor
4. If not, iterate on approach

---

## Questions to Answer

1. **How to invoke Cursor Agent programmatically?**
   - Need to understand Cursor's API/CLI
   - May need to use Cursor's MCP server

2. **What MCP tools are available?**
   - File system operations
   - Git operations
   - Terminal/execution
   - Custom project tools

3. **How to integrate Ollama with Cursor?**
   - Cursor may support Ollama directly
   - Or use MCP server for Ollama

4. **Cost management?**
   - Track API usage
   - Set budgets/alerts
   - Optimize model selection

---

## Conclusion

The current Aider-based architecture is fundamentally flawed:
- No verification loop
- Poor code quality
- Stories marked complete incorrectly
- Missing features entirely

A refactor to Cursor Agent + MCP + Multi-Model would address all these issues:
- Better context awareness
- Iterative refinement
- Real verification
- Cost-effective model selection

**Recommendation: Proceed with refactor.**
