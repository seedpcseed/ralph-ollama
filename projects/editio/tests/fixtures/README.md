# Editio test fixtures

Markdown and resource files referenced by `test-plan.json`. Use from project root, e.g.:

```bash
./target/release/editio compile -i tests/fixtures/minimal.md -o out/minimal.pdf
```

- **minimal.md**, **paragraphs.md**, **headings.md** — basic rendering
- **inline-markdown.md**, **lists-blockquote.md**, **gfm.md** — markdown syntax
- **table-*.md** — tables (basic, caption/label, alignment)
- **figure-*.md** — figures (basic, float, wrap, list-wrap)
- **front-matter-*.md** — YAML document structure (basic, page, invalid)
- **crossref-*.md** — cross-references (figure, table, section)
- **math-*.md** — math (basic, label)
- **theorem-proof.md**, **algorithm.md**, **code-block.md** — blocks
- **citation-basic.md** + **sample.bib** — bibliography
- **headers-footers.md**, **empty-doc.md**, **missing-image.md**, **invalid-syntax.md** — edge/CLI

Image paths (e.g. `figures/sample.png`) are placeholders; add real assets under `figures/` for image tests.
