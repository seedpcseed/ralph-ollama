# Phase 1 Research: Cursor Agent + MCP Integration

**Date:** 2026-02-04  
**Status:** In Progress

---

## Research Goals

1. **Cursor Agent Invocation**: How to invoke Cursor Agent programmatically?
2. **MCP Tools**: What MCP tools are available and how to use them?
3. **Integration Approach**: Best way to integrate Cursor Agent into Ralph scripts?

---

## Research Findings

### 1. Cursor Agent Invocation

#### Current Understanding
- Cursor Agent is built into Cursor IDE
- May not have direct CLI for programmatic invocation
- May need to use Cursor's MCP server instead

#### Options to Explore

**Option A: Cursor MCP Server**
- Cursor provides MCP server with tools
- Can invoke via MCP protocol
- Need to understand available tools

**Option B: Cursor CLI (if exists)**
- Check if `cursor` command exists
- May have agent invocation capabilities

**Option C: Direct API (if available)**
- Cursor may expose API for agent operations
- Need to research documentation

**Option D: Hybrid Approach**
- Use Cursor Agent for complex tasks (via IDE integration)
- Use MCP tools for file/git/terminal operations
- Use local models for simple tasks

#### Current Status
- [ ] Check if cursor CLI exists
- [ ] Research Cursor MCP server capabilities
- [ ] Test MCP tool invocation
- [ ] Document findings

---

### 2. MCP Tools Available

#### From MCP File System

Based on available MCP servers:

**cursor-ide-browser**:
- Browser navigation and interaction tools
- Not directly relevant for code generation

**cursor-browser-extension**:
- Similar browser tools
- Not directly relevant

#### Standard MCP Tools (Expected)

**File Operations**:
- `mcp_filesystem_read` - Read files
- `mcp_filesystem_write` - Write files
- `mcp_filesystem_search` - Search files

**Git Operations**:
- `mcp_git_status` - Git status
- `mcp_git_commit` - Git commit
- `mcp_git_diff` - Git diff

**Terminal Operations**:
- `mcp_terminal_execute` - Execute commands
- `mcp_terminal_stream` - Stream command output

#### Custom MCP Tools Needed

**Ralph-Specific**:
- `ralph_verify_story` - Run story verification
- `ralph_compile_project` - Compile project (language-aware)
- `ralph_run_tests` - Run tests (language-aware)
- `ralph_update_progress` - Update progress.json
- `ralph_update_file_mapping` - Update file-mapping.json

#### Current Status
- [ ] List available MCP tools
- [ ] Test file operations via MCP
- [ ] Test git operations via MCP
- [ ] Test terminal operations via MCP
- [ ] Design custom MCP tools

---

### 3. Integration Approach

#### Proposed Architecture

```
┌─────────────────────────────────────────┐
│         Ralph Scripts (Bash)            │
└─────────────────────────────────────────┘
              │
              ├─→ MCP Client
              │   ├─→ File Operations
              │   ├─→ Git Operations
              │   └─→ Terminal Operations
              │
              └─→ Cursor Agent (via MCP?)
                  ├─→ Code Generation
                  ├─→ Code Editing
                  └─→ Code Analysis
```

#### Key Questions

1. **How to invoke Cursor Agent?**
   - Via MCP server?
   - Via CLI command?
   - Via API?

2. **How to pass context to Cursor Agent?**
   - Story details
   - File context
   - Error messages

3. **How to get results from Cursor Agent?**
   - File changes
   - Commit information
   - Error messages

#### Current Status
- [ ] Design integration architecture
- [ ] Create proof-of-concept script
- [ ] Test with simple task
- [ ] Document integration pattern

---

## Implementation Plan

### Step 1: Research Cursor Agent Invocation

1. Check for cursor CLI
2. Research Cursor MCP server
3. Test MCP tool invocation
4. Document findings

### Step 2: Test MCP Tools

1. Test file read/write operations
2. Test git operations
3. Test terminal execution
4. Document usage patterns

### Step 3: Create Proof of Concept

1. Create simple script that:
   - Reads a file via MCP
   - Invokes Cursor Agent (or alternative)
   - Writes result via MCP
   - Commits via MCP

2. Test with simple task:
   - "Add a comment to file X"
   - "Fix syntax error in file Y"

### Step 4: Design Integration Layer

1. Create `lib/cursor_agent.sh`:
   - Functions for invoking Cursor Agent
   - Functions for passing context
   - Functions for getting results

2. Create `lib/mcp_tools.sh`:
   - Wrapper functions for MCP tools
   - Error handling
   - Result parsing

---

## Alternative Approaches

### If Cursor Agent Not Directly Invocable

**Option 1: Use Cursor's Built-in Agent**
- Open files in Cursor
- Use Cursor's chat interface
- Parse results from file changes

**Option 2: Use Aider as Fallback**
- Keep Aider for code editing
- Use MCP for file/git/terminal
- Use Cursor Agent for complex reasoning

**Option 3: Hybrid Model Selection**
- Simple tasks → Local model (Ollama) via MCP
- Complex tasks → Claude API via MCP
- Use Cursor Agent when available

---

## Next Steps

1. **Research Cursor Agent invocation** (Priority 1)
2. **Test MCP tools** (Priority 2)
3. **Create proof of concept** (Priority 3)
4. **Design integration layer** (Priority 4)

---

## Notes

- Cursor Agent may be IDE-integrated only
- May need to use MCP tools + local/Claude models instead
- Can still achieve goals with MCP + model selection
- Cursor Agent integration is "nice to have" not "must have"

---

## Findings Log

### 2026-02-04 - Initial Research

#### Cursor CLI Discovery
- ✅ **Cursor CLI exists**: `/home/patcseed/.local/bin/cursor` (version 2.4.27)
- ✅ **Basic commands available**: `--diff`, `--merge`, `--add`, `--goto`
- ❌ **No direct agent command**: `cursor --help` shows no `agent` subcommand
- ⚠️ **Need to check**: Separate `agent` command may exist

#### Web Research Findings
- ✅ **Cursor has Agent CLI**: According to docs, there's an `agent` command
- ✅ **Headless mode available**: `agent -p --force` for automation
- ✅ **Installation**: `curl https://cursor.com/install -fsS | bash`
- ✅ **Use cases**: Code analysis, refactoring, automated workflows

#### MCP Tools Available
- ✅ **Browser tools**: `cursor-ide-browser` server with 30+ browser tools
- ⚠️ **File/Git tools**: Need to check if standard MCP file/git tools exist
- ⚠️ **Terminal tools**: Need to check if terminal execution tools exist

#### Next Steps
1. Check if `agent` command exists separately
2. Test `agent -p --force` if available
3. Research standard MCP file/git/terminal tools
4. Create proof-of-concept script
5. Test with simple task
