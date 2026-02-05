## prd.json prompt

>  In projects/editio, I ran 
> aider --no-git --yes --no-auto-commits --model ollama/glm-4.7-flash:latest --timeout 1200   --no-stream --no-show-model-warnings --no-auto-lint  prd.md

You are an expert in project architecture planning and converting prd to a json file that breaks down the overall project into smaller stories that can be iterated over to create high quality functional code. When the stories are combined the end product will be a complete product that is true to the intent of the prd.md. The number of stories should be between 10 and 25 and each should have a major action associated with them. Edit projects/editio/prd.json: replace its entire contents with a JSON object that has "version": "2.0", "branchName": "ralph/editio", "createdAt", "updatedAt", and "userStories": [ ... ] — an array of story objects in v2.0 format. Create stories in dependency order (infrastructure → core → features → polish). Include verification commands in acceptance criteria or verify field. Each story needs this: id, category, story, steps, acceptance, priority, status "pending", progress 0, lastAttempt null, attemptCount 0, dependsOn, blocks, verify{command, lastRun, lastResult "not_run", expectedResult "pass"}, files, tests, errors, notes "", createdAt, updatedAt. 

## refine prd.json stories prompt

> In projects/editio, I ran 
> aider --no-git --yes --no-auto-commits --model ollama/glm-4.7-flash:latest --timeout 1200   --no-stream --no-show-model-warnings --no-auto-lint  prd.md prd.json requirements.md 

You are an expert in project architecture planning. Your task is to review prd.json and ensure every user story can be completed in at most ~10 minutes.

**Rules:**
- Split a story if: it has more than 4–5 steps, more than 5–6 files, or multiple distinct deliverables in one story.
- Keep a story as-is if: it has one clear outcome, one verify command, and a small set of steps/files.
- When splitting: each new story must be a full story object with all required fields (id, category, story, steps, acceptance, priority, status, progress, lastAttempt, attemptCount, dependsOn, blocks, verify, files, tests, errors, notes, createdAt, updatedAt). Use sub-ids for the split (e.g. INF-001a, INF-001b). Stories that depended on the original must now depend on the last sub-story of the split.
- Do not add or remove any keys from the story schema. Do not change the top-level structure of prd.json (version, branchName, createdAt, updatedAt, userStories).
- You must edit prd.json directly (apply the edits yourself). Do not ask the user to edit the file.

Process one category at a time: first Infrastructure (INF-*), then Markdown Parser (PAR-*), then AST Builder (AST-*), then Layout (LAYOUT-*), then PDF (PDF-*), then BIB, CLI, and EXT. For each category, identify stories that are too large, split them into smaller stories, and update the userStories array and any dependsOn references. Output valid JSON only.

## requirements.md prompt

You are an expert in project architecture planning and converting prd to a requirements.md file that breaks down the overall project into smaller stories that can be iterated over to create high quality functional code. When the stories are combined the end product will be a complete product that is true to the intent of the prd.md. The number of stories should be between 10 and 25 and each should have a major action associated with them. Edit projects/editio/requirements.md: replace its entire contents with a requirements.md file that has all the necessary technical specs from prd.md

## run prompt
you are an autonomous agent working to create a complete product that is true to the intent of the prd.md. you will read prd.md, prd.json, and requirements.md. you will pick the highest priority story where status is not "complete". you will implement that ONE story completely under the project path projects/editio/. you will run verification (e.g. cargo check, pytest) when the task specifies it. you will at end of response include status block.

```
---RALPH_STATUS---
STATUS: IN_PROGRESS | COMPLETE | BLOCKED
TASKS_COMPLETED_THIS_LOOP: <n>
FILES_MODIFIED: <n>
TESTS_STATUS: PASSING | FAILING | NOT_RUN
WORK_TYPE: IMPLEMENTATION | TESTING | DOCUMENTATION
EXIT_SIGNAL: false | true
RECOMMENDATION: <one line>
---END_RALPH_STATUS---
```

You will set the EXIT_SIGNAL: true only when all the stories are done and the verifications have passed. Use BLOCKED when stuck on same error; RECOMMENDATION should say what's needed next.

Work on only one story at a time where the lower number is the highest priority. You must create and edit files. Do not ask the user to add or edit the files for you. this is your job. Do not put information into logs or alternative files. Put them into the files instructed. Implementation is greater than tests for new code. No placeholder implementations.

please work through the entire prd.json until it is complete.

## Testing and fixing
### Set up Testing
I want you to create a feature test-plan.json from basic rendering, markdown syntax support, table support, figure / word wrap support, YAML document structure support. The JSON should have ID, test type, test name,  status, test resources [like .md docs etc], errors, assessment [for iterative work needs/ideas]. please add additional test areas as you think are appropriate based on @projects/editio/prd.md 

### Execute testing (render–vision validation)
You will read and follow **projects/editio/test-plan.json** and run the full validation workflow for each test until every step’s status is **complete**. You are ensuring that the tests perform as expected based on **typesetting standards** and the requirements in **projects/editio/prd.md**. Do not ask the user to run builds, scripts, or checks for you.

**Validation requirements (all must pass for a step to be complete):**

1. **Build** – The package builds successfully: `cargo build --release` from **projects/editio**.
2. **Render** – The test’s fixture compiles to PDF without error:  
   `./target/release/editio compile -i <testResources[0]> -o render/<test-id>.pdf`  
   (Use the test’s `id` and first entry in `testResources` from test-plan.json.)
3. **Export to PNG** – Run the render–vision script so the PDF can be checked visually:  
   From **projects/editio**: `./scripts/export-pdf-to-png.sh`  
   This produces `render/<name>.png` for each PDF in `render/`.  
   If the script is missing or fails, install `poppler-utils` (pdftoppm) or ImageMagick (convert) or implement an equivalent export step.
4. **Vision check** – You **must** open and inspect the PNG (e.g. `render/<test-id>.png`) and evaluate it against the test’s **validation.expectedRendering** and **validation.passCriteria** in test-plan.json **and** against the bar below. Only then may you decide pass/fail.

**Completion bar (all must be true before marking a test complete):**

- **Layout and readability:** Text does **not** overlap, run together, or sit on top of other text. Lines are readable and spaced according to normal typesetting. (Example: T004 was incorrectly marked complete when inline segments overlapped—that is a **fail**.)
- **Formatting matches intent:** If the test expects bold, italic, code, or link styling, the PNG must show those as **visually distinct** (e.g. bold heavier than body text, italic slanted, code monospace or clearly distinct). Raw markdown (e.g. `**`, `*`, `` ` ``, `[...]`) must **not** appear as literal characters where they denote formatting.
- **Structure matches test type:** Tables appear as grids with rows/columns; code/theorem/algorithm blocks as formatted blocks, not as raw directive or LaTeX; math as typeset or clearly rendered, not as literal `$...$` or `$$...$$`.
- **PRD alignment:** The result is consistent with **prd.md** (e.g. CommonMark compatibility, professional typesetting, no “placeholder” or broken layout). When in doubt, treat ambiguous output as **fail** and fix before marking complete.

**Never mark a test complete if:**

- Text or blocks overlap, are illegible, or are clearly mispositioned.
- Bold/italic/code/link (or other required formatting) is not visually distinct when the test requires it.
- Raw markdown, directive syntax, or LaTeX delimiters appear in the rendered output where they should have been interpreted.
- The PNG was not actually inspected (e.g. assuming “compile + export” means pass).

**Per-test loop:**

- For each test in test-plan.json with `status` **incomplete**:
  1. Build (if needed), compile the fixture to PDF, run `./scripts/export-pdf-to-png.sh`, then **open and vision-check** the resulting PNG.
  2. Run through the **completion bar** and **never mark complete if** list above. If **any** item fails, do **not** set status to complete; instead troubleshoot, recode, then re-run build → compile → export-PNG → vision check. Repeat until the PNG satisfies all criteria.
  3. Only when the vision check **passes** (layout readable, formatting distinct, structure correct, PRD-aligned): set that test’s **status** to **complete** in test-plan.json.

**Tests with validation.type "cli"** (e.g. invalid YAML, check command): validate using exit code and stderr only; no PNG required. Mark complete when the CLI behavior matches the test’s validation criteria.

**Rules:**

- Work through every test in order until **all** steps have **status** **complete**.
- Do not stop early; do not ask the user to perform build, compile, export, or vision steps.
- Use **scripts/export-pdf-to-png.sh** (or equivalent) so validation is always based on a PNG of the rendered output, not only on compile success.
- **Evaluation before “complete”:** Before setting any test to **complete**, explicitly confirm in your reasoning that the PNG was inspected and that the completion bar and “never mark complete if” conditions are satisfied. If you cannot inspect the PNG (e.g. no image available), do not mark the test complete—fix the export step or tooling first. 