# Why Ralph Didn't Produce a Complete LogLens App

## Executive Summary

The failure is **shared between the PRD/convert pipeline and the Ralph loop**. Neither the PRD conversion nor the loop is designed to produce a verifiable, integrated, runnable product. They produce fragments that are marked "complete" without verification.

---

## 1. Ralph Loop Gaps

### 1.1 No Verification Step

**What happens:** When the model outputs `STATUS: COMPLETE`, we mark the story done. We never run the code.

**Impact:** Stories are marked complete on the model's *claim*, not on evidence. The model can say "parse command works" without us ever running `loglens parse test-fixtures/apache-sample.log`.

**Fix:** Add a verification step that runs executable acceptance criteria (e.g., `pytest`, `loglens --help`) before marking complete.

### 1.2 No Codebase Context in the Prompt

**What happens:** Each story gets: story text, steps, acceptance criteria, previous learnings (progress.txt). It does NOT get:
- List of existing files in the project
- The PRD architecture (cli.py, parsers/, etc.)
- Contents of files it should extend (e.g., "here is the current cli.py")

**Impact:** The model is blind. Story 1.4 (CLI) doesn't know that `parser/apache_nginx.py` and `parsers/json_parser.py` exist. It may create a new cli.py that only uses one parser or invents a different structure.

**Fix:** Include in the prompt: `CURRENT PROJECT FILES:` (from `find` or `tree`) and optionally key file contents.

### 1.3 Stories Executed in Isolation

**What happens:** Story 1.2 creates a parser. Story 1.4 creates a CLI. They run in separate loops with no guarantee the CLI uses the parser.

**Impact:** Each story produces a piece, but nobody wires them together. The CLI might import from the wrong path or use a different interface.

**Fix:** Add an explicit "integration" story that wires components together. Or include "existing modules to use" in later stories' prompts.

### 1.4 No Package/Entry-Point Story

**What happens:** The convert step produces stories from the PRD. The PRD implies `loglens` as a command but never has an explicit story: "Create pyproject.toml with entry point so `loglens` works."

**Impact:** Even if cli.py exists, there's no installable package. No `pip install -e .` → no `loglens` command.

**Fix:** Add to PRD or convert: a story "Make the app installable (pyproject.toml, loglens entry point)."

---

## 2. PRD / Convert Pipeline Gaps

### 2.1 Conversion Loses or Merges Stories

**What happens:** The LogLens PRD has ~14 stories (1.1–1.4, 2.1–2.5, 3.1–3.4, etc.). The converted `prd.json` has 10 (1.1–1.10). Stories get merged or dropped during conversion.

**Impact:** Important stories (e.g., "install using pip", "integration") may never make it into prd.json.

**Fix:** Validate converted prd.json against PRD. Ensure conversion prompt explicitly requires an "installable package" story if the PRD implies it.

### 2.2 Acceptance Criteria Aren't Machine-Verifiable

**What happens:** Acceptance like "parse command correctly analyzes test log file" could be run as `loglens parse test-fixtures/apache-sample.log`. We never do that.

**Impact:** Even with verification in the loop, we'd need criteria that map to commands (e.g., "Run: loglens parse X; expect: exit 0, output contains 'Total requests'").

**Fix:** Define acceptance as runnable commands + expected outcomes. Add a verification script per story or per phase.

### 2.3 Architecture Not Enforced

**What happens:** PRD specifies `loglens/cli.py`, `parsers/apache.py`, etc. The convert doesn't require this structure. The loop doesn't pass it.

**Impact:** Different stories create `app/`, `parser/`, `parsers/`, `src/main/` — no single layout. Imports break.

**Fix:** Include `PROJECT STRUCTURE (from PRD):` in the prompt. Validate file paths against it in the applier.

---

## 3. Root Cause Summary

| Gap | Location | Severity |
|-----|----------|----------|
| Trust model's STATUS without verification | Loop | Critical |
| No codebase context in prompt | Loop | Critical |
| No integration story | PRD/Convert | High |
| No package/entry-point story | PRD/Convert | High |
| Conversion loses stories | Convert | Medium |
| Acceptance not machine-verifiable | PRD | Medium |
| Architecture not passed to model | Loop | Medium |

---

## 4. Recommended Fixes (Priority Order)

### P0: Add Verification Step to Loop

Before marking a story complete, run a verification command if defined:

```bash
# In prd.json, add optional "verify": "pytest" or "verify": "loglens --help"
# Loop runs it; only mark complete if exit 0
```

### P1: Add Codebase Context to Prompt

Append to each prompt:

```
CURRENT PROJECT FILES:
$(find "$PROJECT_DIR" -type f -name "*.py" | head -50)

PROJECT STRUCTURE (from PRD):
loglens/
├── cli.py
├── parsers/
│   ├── apache.py
│   └── json.py
...
```

### P2: Add Integration + Package Stories to Convert

Update the convert prompt to require:
- A story for "Create pyproject.toml with loglens entry point; pip install -e . works"
- A final story for "Ensure CLI integrates all parsers; loglens parse works for Apache and JSON"

### P3: Make Acceptance Verifiable

When writing PRDs, use format:

```
Acceptance: RUN "loglens parse test-fixtures/apache-sample.log" → exit 0, output contains "Total requests"
```

Add a `verify_acceptance.sh` that the loop can call.

---

## 5. Conclusion

Ralph-Ollama is built to iterate over stories and apply code. The gaps have been addressed with these fixes:

### Implemented Fixes (see git history)

- **P0 Verification**: `lib/verification.sh` - runs verify command before marking complete. Uses story `.verify`, `RUN "cmd"` in acceptance, or project `verify.sh`.
- **P1 Codebase Context**: `build_ollama_prompt` now includes `CURRENT PROJECT FILES` and `PROJECT STRUCTURE` from PRD.
- **P2 Convert**: Convert prompt requires integration + package stories; supports `verify` field.
- **P3 Verifiable Acceptance**: `docs/VERIFIABLE_ACCEPTANCE.md`, `templates/verify.sh`, RUN format in prd-template.

To use: Add `verify` to stories in prd.json, or use `RUN "command"` in acceptance. Create `verify.sh` in your project for custom checks.
