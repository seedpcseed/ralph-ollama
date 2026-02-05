# Vision validation for test-plan.json

All steps in `test-plan.json` are **incomplete** until image (or CLI) validation passes.

## Workflow (per test)

1. **Compile** – Build PDF from the test’s fixture(s):
   ```bash
   cargo build --release
   ./target/release/editio compile -i tests/fixtures/<fixture>.md -o render/<test-id>.pdf
   ```
2. **Export to PNG** – So vision can evaluate the page:
   ```bash
   ./scripts/export-pdf-to-png.sh
   ```
   (Requires `pdftoppm` from poppler-utils or ImageMagick `convert`.)
3. **Vision check** – Open or pass `render/<test-id>.png` to vision and compare to the test’s `validation.expectedRendering` and `validation.passCriteria` in `test-plan.json`.
4. **Pass/fail** – If rendering matches the criteria, mark that test’s `status` as `"complete"`. If not, leave `status` as `"incomplete"` and run: **troubleshoot → recode → recompile → export PNG → vision check** until it passes.

## Running all image validations

From project root:

```bash
# 1) Build and compile every fixture to PDF (use test-plan.json testResources)
cargo build --release
for id in T001 T002 T003 ...; do
  # Resolve first resource per test and compile to render/${id}.pdf
done

# 2) Export all PDFs to PNG
./scripts/export-pdf-to-png.sh

# 3) For each test, compare render/${id}.png to expectedRendering in test-plan.json
```

Tests with `validation.type` **"cli"** (e.g. T016, T026) are validated by exit code and stderr only; no PNG is required.

## Test plan schema (per test)

- **status**: `"incomplete"` | `"complete"` – Only set to complete after validation passes.
- **validation.type**: `"image"` | `"cli"` | `"file"` | `"cli_or_image"`.
- **validation.steps**: List of steps to run.
- **validation.expectedRendering**: What should appear in the PNG (or CLI output).
- **validation.passCriteria**: Short condition for passing the vision/CLI check.
