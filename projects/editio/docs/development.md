# Editio – Local development

## Prerequisites

- Rust 1.70+ (install via [rustup](https://rustup.rs))
- For PDF output: `pdflatex` (optional, for math rendering)

## Setup

```bash
git clone <repo-url>
cd editio
cargo build
```

## Commands

- **Check (no build):** `cargo check --workspace`
- **Build:** `cargo build`
- **Run binary:** `cargo run -p editio -- --help`
- **Tests:** `cargo test --workspace`
- **Format:** `cargo fmt`
- **Lint:** `cargo clippy --workspace`

## Project layout

- `crates/editio` – CLI binary
- `crates/editio-core` – Core types
- `crates/editio-ast` – AST
- `crates/editio-parser` – Markdown/document parser
- `crates/editio-layout` – Layout engine
- `crates/editio-pdf` – PDF renderer
- Other crates: html, word, latex, bib, math, template, plugin, plugin-manager

## Adding a new crate

1. Create `crates/<name>/Cargo.toml` and `crates/<name>/src/lib.rs`.
2. Add the crate to `[workspace].members` in the root `Cargo.toml`.
