#!/usr/bin/env bash
# Export PDFs in render/ to PNG for vision validation.
# Requires: pdftoppm (poppler-utils) or ImageMagick convert.
# Usage: from project root, ./scripts/export-pdf-to-png.sh [test-id]
#   With no args, converts all render/*.pdf to render/*.png

set -e
RENDER_DIR="${1:-render}"
cd "$(dirname "$0")/.."
mkdir -p "$RENDER_DIR"

if command -v pdftoppm &>/dev/null; then
  for f in "$RENDER_DIR"/*.pdf; do
    [ -f "$f" ] || continue
    base="${f%.pdf}"
    pdftoppm -png -r 150 -f 1 -l 1 "$f" "$base" 2>/dev/null && mv "${base}-1.png" "${base}.png" 2>/dev/null || true
  done
  echo "Exported PNGs (pdftoppm) in $RENDER_DIR/"
elif command -v convert &>/dev/null; then
  for f in "$RENDER_DIR"/*.pdf; do
    [ -f "$f" ] || continue
    base="${f%.pdf}"
    convert -density 150 "${f}[0]" "${base}.png" 2>/dev/null || true
  done
  echo "Exported PNGs (ImageMagick) in $RENDER_DIR/"
else
  if python3 -c "import fitz" 2>/dev/null; then
    for f in "$RENDER_DIR"/*.pdf; do
      [ -f "$f" ] || continue
      base="${f%.pdf}"
      python3 -c "
import fitz, sys, os
path = sys.argv[1]
doc = fitz.open(path)
pix = doc[0].get_pixmap(dpi=150)
pix.save(path.replace('.pdf','.png'))
doc.close()
" "$f"
    done
    echo "Exported PNGs (pymupdf) in $RENDER_DIR/"
  else
    echo "Install poppler-utils (pdftoppm), ImageMagick (convert), or python pymupdf to export PDF to PNG."
    exit 1
  fi
fi
