# Aider prompt tuning for Ralph

This doc describes how we build prompts for Aider in the implementation loop and how to improve them for better outcomes when testing.

## Conversion: prevent extra files in chat

When converting prd.md → prd.json, Aider can add **unnecessary files** to the chat (from the repo map or from adding any file it edits). That extra context can confuse the model and hurt conversion quality.

**Do this for conversion:**

1. **Pass only the three conversion files** – include `prd.json` as well as `prd.md` and `requirements.md` so the model has the target file in context from the start:
   ```bash
   aider ... --message-file docs/convert-prompt-aider-compact.md \
     projects/editio/prd.md projects/editio/prd.json projects/editio/requirements.md
   ```
2. **Use `--no-git`** – disables the repo map so Aider doesn’t send a summary of the whole repo to the model. Conversion only needs the PRD and the two output files:
   ```bash
   aider --no-git --yes --no-auto-commits --model ollama/glm-4.7-flash:latest --timeout 1200 \
     --no-stream --no-show-model-warnings --no-auto-lint \
     --message-file docs/convert-prompt-aider-compact.md \
     projects/editio/prd.md projects/editio/prd.json projects/editio/requirements.md
   ```

`./convert.sh` uses Aider with `--no-git` by default (when `AIDER_NO_GIT` is not set to `false`) so scripted conversion stays limited to those three files.

## Context limit (e.g. 16,384 tokens) with Ollama

Some Ollama models (e.g. `deepseek-coder:latest`) default to a 16k context. If Aider says "Your estimated chat context of X tokens exceeds the Y token limit", either:

- **Use the compact convert prompt:** `--message-file docs/convert-prompt-aider-compact.md` instead of `docs/convert-prompt-aider.md` (same task, fewer tokens).
- **Use a model with larger context:** e.g. `ollama/llama3.1:70b` or a model that supports 32k+.
- **Increase Ollama context:** When running the model, you can pass `num_ctx` in the API options. LiteLLM may support passing this through; otherwise run Ollama with a custom Modelfile that sets `PARAMETER num_ctx 32768` (or your model's max). Not all models support large context.

## Connection timeout (600s) when using Ollama

Aider talks to Ollama via **LiteLLM**, which has a **default request timeout of 600 seconds**. If the model takes longer (e.g. large context, slow hardware), you get:

```text
litellm.APIConnectionError: OllamaException - litellm.Timeout: Connection timed out after 600.0 seconds.
```

**Fix for manual Aider runs:**

1. **Environment**: Set a longer timeout before starting Aider (in the same shell):
   ```bash
   export LITELLM_REQUEST_TIMEOUT=1200   # 20 minutes; use 1800 for 30 min
   ```
   Or source Ralph’s config (which now sets this from `AGENT_TIMEOUT_MINUTES`):
   ```bash
   source config.sh
   ```

2. **Aider flag**: Pass a matching `--timeout` so Aider doesn’t give up before LiteLLM:
   ```bash
   aider --model ollama/glm-4.7-flash:latest --timeout 1200 ...
   ```

When you use `./start.sh`, it already sets `LITELLM_REQUEST_TIMEOUT` and `--timeout` from `AGENT_TIMEOUT_MINUTES` (default 20 minutes).

### Lint fixing and slow models

By default Aider lints files after edits and prompts **"Attempt to fix lint errors? (Y)es/(N)o"**. With a slow/local model that can mean a long extra request and sometimes repeated fix attempts.

**More efficient:** use **`--no-auto-lint`** so Aider skips automatic linting and the fix prompt. You can run `cargo check` or your own linter yourself when you want. Example:

```bash
aider --model ollama/glm-4.7-flash:latest --timeout 1200 --yes --no-stream --no-show-model-warnings --no-auto-lint \
  projects/editio/prd.json projects/editio/requirements.md projects/editio/PROMPT.md
```

`./start.sh` already passes `--no-auto-lint` when it invokes Aider; verification (e.g. `cargo build`) runs after the agent returns.

### "The LLM did not conform to the edit format"

Aider applies edits only when the model outputs in the **whole-file format**: one line with the file path, then a line with \`\`\`, then the full file contents, then \`\`\`. If the model describes changes in prose, uses \`\`\`rust code blocks, or omits the path line, Aider reports "The LLM did not conform to the edit format" and no edit is applied.

**Mitigations:**

- **Put the format in the prompt**: In `projects/<name>/PROMPT.md` (or your manual prompt), state the rule explicitly: path on its own line, then \`\`\`, then full contents, then \`\`\`. Say "Do not use \`\`\`rust—only this format applies edits."
- **Use whole format**: Run with `--edit-format whole` (Aider often picks this for Ollama). Diff format is stricter and harder for local models.
- **Less context**: Add fewer files to the chat (e.g. only the ones needed for the current story). Large context can make the model ignore system instructions.
- **Stronger model**: Local/small models often slip; if it keeps happening, try a larger Ollama model or an API model (Claude, GPT-4o) for that run.
- **Architect mode**: `aider --architect` uses one model to propose changes and another to apply edits, which can improve conformity (at the cost of two calls).

## Where prompts are built

| Purpose | Location | When used |
|--------|----------|-----------|
| **Main story prompt** | `start.sh` → `generate_prompt_v2()` | Each loop: implement one story |
| **Fix prompt** | `start.sh` (inline `cat > "$fix_prompt"`) | After verification fails: fix errors and retry |
| **Project context** | `projects/<name>/PROMPT.md` | Loaded by Aider as a file in chat (not in message) |

Aider is invoked with:
- `--message-file` = the generated prompt (story + steps + acceptance + **path rules** + instructions)
- Project files (e.g. `projects/<name>/prd.json`, `requirements.md`, `PROMPT.md`, and any existing `*.toml`, `*.rs`) so it can edit them

So the **message** is what we control per story; the **files** give context and edit targets.

## What we put in the main prompt (v2)

1. **Story / Steps / Acceptance / Verification** – from `prd.json`.
2. **Context** – learnings (progress.json), relevant files (file-mapping.json) if present.
3. **CRITICAL: File paths** – all files under `projects/<project_name>/`; never at repo root.
4. **Rust projects** – every crate needs `src/lib.rs` or `src/main.rs`; when adding a crate, create both `Cargo.toml` and `src/lib.rs` (or `src/main.rs`). Paths are relative to repo root (e.g. `projects/editio/crates/editio-core/src/lib.rs`).
5. **Instructions** – create missing files, implement story, ensure it compiles, run verification.

## What we put in the fix prompt

- Build/test errors.
- Same **CRITICAL: File paths** (all under `projects/<name>/`).
- **Rust: "no targets specified"** – hint to add `src/lib.rs` or `src/main.rs` for that crate.
- Instructions to fix errors and create any missing files.

## Tips for getting the right outcome

- **Paths**: Always say the path prefix explicitly: `projects/<project_name>/`. Aider’s cwd is repo root; if the prompt says “under the project”, models sometimes still create files at root. Explicit examples (e.g. `projects/editio/Cargo.toml`) help.
- **Rust crates**: Saying “every crate needs lib.rs or main.rs” and “when adding a crate, create Cargo.toml and src/lib.rs” reduces “no targets specified” from the first run.
- **One story**: The prompt is for one story; keep instructions focused so the model doesn’t wander.
- **Verification command**: Including the exact command (e.g. `cargo build --lib`) in the prompt helps the model run the same check we use.

## How to iterate when testing Aider

1. **Inspect the prompt**  
   After a run, check:
   - `projects/<name>/.ralph_current_prompt.md` (last main prompt),
   - or the fix prompt is in `.ralph_fix_prompt.md` only during a fix run (then removed).
2. **Adjust `generate_prompt_v2` in `start.sh`**  
   Add or rephrase path rules, Rust rules, or instructions; run another loop and see if behavior improves.
3. **Adjust the fix prompt block in `start.sh`**  
   Add error-specific hints (e.g. “no targets specified” → add lib.rs) so the first fix attempt succeeds more often.
4. **Use `projects/<name>/PROMPT.md`**  
   For project-wide rules (e.g. “always use paths under this project”), keep them in PROMPT.md so they’re in every Aider chat; keep story-specific wording in the generated message.

## Quick checklist for a new project type

- [ ] Path rule: “All files under `projects/<name>/`” (and examples).
- [ ] Language-specific rules (e.g. Rust: lib.rs/main.rs per crate; Python: avoid `__pycache__` in edits).
- [ ] Fix prompt: include common build errors and the exact fix (e.g. “no targets specified” → add lib.rs).
- [ ] Verification command in the main prompt so the model runs what we run.
