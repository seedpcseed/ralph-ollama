# PRD → prd.json (v2.0) – compact

Use when the model has a small context (e.g. 16k). For 32k+ use `docs/convert-prompt-aider.md`. **convert.sh uses this compact prompt by default.**

## Task
1. Read projects/editio/prd.md (in chat); understand ALL requirements.
2. Edit projects/editio/prd.json: replace entire file with one JSON: "version":"2.0", "branchName":"ralph/editio", "createdAt", "updatedAt", "userStories":[ ... ].
3. Edit projects/editio/requirements.md: replace with technical specs from PRD.

## Story rules
- Granular: each P0 feature → 5–15 stories (not 1–3). One concept per story; 1–2 iterations each.
- Order: dependency order (infra → core → features).
- Verify: every story has verifiable command in "acceptance" or "verify.command".

## Per-story fields (v2.0, all required)
id, category, story, steps, acceptance, priority, status "pending", progress 0, lastAttempt null, attemptCount 0, dependsOn, blocks, verify{command, lastRun, lastResult "not_run", expectedResult "pass"}, files, tests, errors, notes "", createdAt, updatedAt.

## Output
Full prd.json with ALL stories (no "..."). Break each PRD feature into many small stories; 50–150+ for a complex PRD. Use Aider whole-file format: path on one line, then ```, then full file contents, then ```. Edit projects/editio/prd.json and projects/editio/requirements.md now.
