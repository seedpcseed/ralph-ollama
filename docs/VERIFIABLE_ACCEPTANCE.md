# Verifiable Acceptance Criteria

Ralph can run verification commands before marking a story complete. Use these formats to make acceptance criteria machine-verifiable.

## 1. RUN Format in Acceptance Text

In your PRD or prd.json, include executable criteria:

```
Acceptance: RUN "pytest" - all tests pass
Acceptance: RUN "loglens parse test-fixtures/sample.log" - exits 0, shows stats
Acceptance: RUN "python -m py_compile cli.py" - no syntax errors
```

The verification layer extracts `RUN "command"` and runs it from the project directory. If the command fails, the story is not marked complete.

## 2. verify Field in prd.json

Add an optional `verify` field to any story:

```json
{
  "id": "1.1",
  "story": "Set up project structure",
  "acceptance": "pytest passes, imports work",
  "verify": "pytest",
  "priority": 1,
  "passes": false
}
```

Supported verify values (language-agnostic):
- Python: `pytest`, `python3 -m pytest tests/`
- Rust: `cargo test`
- Go: `go test ./...`
- Node: `npm test`
- CLI: `appname --help` (after install)
- `bash verify.sh` - run project's verify script

## 3. Project-Level verify.sh

Create `projects/<name>/verify.sh` in your project. It runs when any story is verified (if no per-story verify is set). Example:

```bash
#!/bin/bash
# Run all verification checks
set -e
cd "$(dirname "$0")"
python -m pytest tests/ -q || exit 1
python cli.py --help > /dev/null || exit 1
```

## Priority

1. Story's `verify` field (if present)
2. `RUN "..."` parsed from acceptance text
3. Project's `verify.sh` (if present)
4. No verification (story marked complete on model's STATUS: COMPLETE)
