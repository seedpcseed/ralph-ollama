# Agent Strategy for Ralph 2.0

## Current Approach

### For API Models (Claude)
- **Tool**: Cursor Agent CLI (`agent` command)
- **Why**: Native IDE integration, better context, iterative refinement
- **Limitation**: Requires API access, has usage limits

### For Local Models (Ollama)
- **Tool**: Aider (`aider` command)
- **Why**: 
  - Claude CLI uses API by default (requires `ollama launch claude` interactive setup)
  - Aider directly supports `ollama/model-name` format
  - More reliable for automation
  - v2.0 verification loop addresses Aider's v1.0 issues
- **Note**: Claude CLI can be configured for local models, but requires manual setup

## Why Aider is Acceptable in v2.0

Even though Aider had problems in v1.0, **v2.0's architecture addresses those issues**:

### v1.0 Problems → v2.0 Solutions

| v1.0 Problem | v2.0 Solution |
|--------------|---------------|
| No verification loop | ✅ **Verification loop**: Compile + test + story-specific verify |
| No iterative refinement | ✅ **Up to 5 attempts**: Fix errors based on compiler/test output |
| Poor context awareness | ✅ **Better prompts**: More context, file mapping, progress tracking |
| Stories marked complete incorrectly | ✅ **Real verification**: Only mark complete when tests pass |

### The Key Difference

**v1.0**: Aider edits files → Story marked complete → No verification → Broken code  
**v2.0**: Aider edits files → **Verification loop runs** → If fails, retry with error feedback → Only mark complete when verification passes

## Why Not Cursor Agent for Local Models?

**Cursor Agent CLI doesn't support local Ollama models**:
- `agent --list-models` only shows Cursor API models (gpt-5, sonnet-4, etc.)
- No `--base-url` or `--endpoint` option for local Ollama
- Always uses Cursor API (hence the usage limit errors)

## Alternatives Considered

### Option 1: Ollama API Direct (lib/ollama_agent.sh)
- ✅ No dependency on Aider
- ❌ Requires parsing LLM output and applying edits manually
- ❌ More complex, error-prone
- ❌ Would need to reimplement file operations, git integration

### Option 2: Different Tool
- Could use `llm` or similar tools
- But they have similar limitations to Aider
- Aider is battle-tested and widely used

### Option 3: Cursor IDE Integration
- Cursor IDE can be configured for local models
- But this is for manual use, not automation
- CLI `agent` command doesn't support this

## Recommendation

**Keep current approach**:
- Cursor Agent for API models (when available)
- Aider for local models (with v2.0 verification loop)

The verification loop is the key - it ensures code quality regardless of which tool generates the initial code.

## Future Possibilities

If Cursor Agent CLI gains local model support:
- Add `--base-url` flag for Ollama endpoint
- Add `--model` flag that accepts `ollama/model-name`
- Then we can switch local models to Cursor Agent

Until then, Aider + verification loop is the best approach.
