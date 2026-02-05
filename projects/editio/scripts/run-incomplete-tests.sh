#!/usr/bin/env bash
# Compile all tests with status "incomplete" in test-plan.json to render/<id>.pdf,
# then export PDFs to PNG. Use this for the sample loop: compile → export → vision-check → fix → repeat.
# Requires: jq, editio binary (cargo build --release), export-pdf-to-png.sh deps (pdftoppm or convert).

set -e
cd "$(dirname "$0")/.."

if ! command -v jq &>/dev/null; then
  echo "jq required. Install with: sudo apt install jq"
  exit 1
fi

echo "Building editio..."
cargo build --release

mkdir -p render

# Get incomplete tests (id + first testResource path)
incomplete=$(jq -r '.tests[] | select(.status == "incomplete") | "\(.id) \(.testResources[0])"' test-plan.json 2>/dev/null || true)
if [ -z "$incomplete" ]; then
  echo "No incomplete tests in test-plan.json."
  exit 0
fi

echo "Compiling incomplete fixtures to render/<id>.pdf..."
while read -r id resource; do
  [ -z "$id" ] && continue
  if [ -f "$resource" ]; then
    ./target/release/editio compile -i "$resource" -o "render/${id}.pdf" && echo "  ${id} <- ${resource}"
  else
    echo "  ${id} SKIP (missing ${resource})"
  fi
done <<< "$incomplete"

echo "Exporting PDFs to PNG..."
./scripts/export-pdf-to-png.sh

echo "Done. Vision-check render/<id>.png for each incomplete test; mark complete in test-plan.json when pass."
