# Conversion Strategy for Ralph 2.0

## Problem

Local models (e.g., `deepseek-coder:33b`) struggle to generate 50-150+ stories in a single response. They tend to:
- Generate 1-2 example stories
- Use placeholders like "// ... more stories here ..."
- Hit context/token limits
- Not follow instructions to generate all stories

## Recommended Approach

### For PRD Conversion (convert-v2.sh)

**Use Claude API** (`--model claude`):
- ✅ One-time cost (only runs once per project)
- ✅ Better quality - generates all 50-150+ stories
- ✅ Follows instructions correctly
- ✅ Complete story breakdowns

**Cost**: ~$2-5 per conversion (one-time)

### For Implementation Loop (start-v2.sh)

**Use Local Models** (`--model local`):
- ✅ Free (no API costs)
- ✅ Runs many times (once per story)
- ✅ v2.0 verification loop ensures quality
- ✅ Cost-effective for iterative work

**Cost**: $0 (after hardware investment)

## Workflow

```bash
# Step 1: Convert PRD using Claude API (one-time, high quality)
./convert-v2.sh editio --model claude

# Step 2: Implement using local models (many iterations, free)
./start-v2.sh editio --model local
```

## Why This Works

1. **Conversion is critical** - Poor story breakdown = poor implementation
2. **Conversion is one-time** - Only need to pay once per project
3. **Implementation is iterative** - Many loops, local models save money
4. **Verification loop** - Ensures local model output is correct

## Alternative: Iterative Story Generation

If you must use local models for conversion, we could implement:
- Generate stories per feature (11 passes)
- Each pass generates 5-15 stories for one feature
- Combine results into final prd.json

This would work but is more complex and slower.

## Current Status

- ✅ JSON extraction works (can recover from model output)
- ⚠️ Local models generate too few stories (1 instead of 50-150+)
- ✅ Claude API works well (when available)
- ✅ Fallback extraction handles partial generation

## Recommendation

**Use Claude API for conversion, local models for implementation.**

This gives you:
- High-quality story breakdown (Claude)
- Cost-effective implementation (local)
- Best of both worlds
