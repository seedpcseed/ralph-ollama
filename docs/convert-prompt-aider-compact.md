# PRD → prd.json (v2.0) – compact prompt for small context

Use this when your model has a small context window (e.g. 16k tokens). Use `docs/convert-prompt-aider.md` when you have 32k+.

## Task
1. Read projects/editio/prd.md (in chat) to understand ALL requirements.
2. Edit projects/editio/prd.json: replace entire contents with one JSON object: "version":"2.0", "branchName":"ralph/editio", "createdAt", "updatedAt", "userStories":[ ... ].
3. Edit projects/editio/requirements.md: replace with technical specs from the PRD (architecture, data models, API, UI, security, tech stack).

## Story rules
- **Granular:** Each P0 feature → 5–15 stories (not 1–3). One concept per story; completable in 1–2 iterations.
- **Order:** Dependency order (infra → core → features).
- **Verify:** Every story has a verifiable command (cargo test, grep, build) in "acceptance" or "verify.command".

## Per-story fields (v2.0, all required)
id, category ("technical"|"functional"|"ui"), story, steps[], acceptance, priority (1–10), status "pending", progress 0, lastAttempt null, attemptCount 0, dependsOn[], blocks[], verify { command, lastRun null, lastResult "not_run", expectedResult "pass" }, files[], tests[], errors[], notes "", createdAt, updatedAt.

## Verification format
"verify": { "command": "cargo test parser", "lastRun": null, "lastResult": "not_run", "expectedResult": "pass" }
Or in acceptance: "RUN 'cargo test parser' must pass."

## Output
Generate the full prd.json with ALL stories (no "..."). Break each PRD feature into many small stories. 50–150+ stories for a complex PRD. Edit the files using Aider's whole-file format (path on one line, then ```, then full contents, then ```).

Generate the complete JSON and edit projects/editio/prd.json and projects/editio/requirements.md now.
