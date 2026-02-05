# Editio - Technical Requirements

**Version:** 2.0  
**Date:** 2025-06-18  
**Status:** Complete  
**Author:** Editio Team

---

## 1. External APIs Required

| Component | Method | Use Case | Notes |
|-----------|--------|----------|-------|
| pdflatex | Subprocess | Math rendering in PDF (MVP) | Shell out to pdflatex for math, extract PDF fragments |
| KaTeX (HTML) | Library | Math rendering in HTML | Client-side math rendering for HTML output |
| CSL Library | Library | Citation style processing | Process .csl files for advanced citation formatting (post-MVP) |

---

## 2. Core Rust Functions

```rust
// Main compilation function
pub fn compile(input: &str, output_path: &Path, format: OutputFormat) -> Result<(), CompileError>

// Parser functions
pub fn parse_markdown(input: &str) -> Result<Document, ParseError>
pub fn build_ast(events: Vec<Event>) -> Result<Node, ASTError>

// Layout functions
pub fn calculate_layout(ast: &Node, metadata: &DocumentMetadata) -> Result<LayoutMetadata, LayoutError>
pub fn calculate_wrap_zones(floats: &[Float], content: &[Content]) -> Vec<WrapZone>

// Renderer functions
pub fn render_pdf(ast: &Node, layout: &LayoutMetadata) -> Result<Vec<u8>, RenderError>
pub fn render_html(ast: &Node) -> Result<String, RenderError>
pub fn render_latex(ast: &Node) -> Result<String, RenderError>
```

---

## 3. File Structure

```
editio/ (workspace)
├── crates/
│   ├── editio/              # Main CLI binary
│   ├── editio-core/         # Main library (orchestrates everything)
│   ├── editio-ast/          # Shared AST types (used by all renderers)
│   ├── editio-parser/       # Markdown parsing (pulldown-cmark + extensions)
│   ├── editio-layout/       # Layout engine (two-pass, CSS-style floats)
│   ├── editio-render/       # Rendering engine (traits/interfaces)
│   ├── editio-pdf/          # PDF output (printpdf + custom layout)
│   ├── editio-html/         # HTML output (KaTeX math)
│   ├── editio-word/         # Word/DOCX output
│   ├── editio-latex/        # LaTeX output
│   ├── editio-bib/          # Bibliography (BibTeX, BibLaTeX, RIS, EndNote)
│   ├── editio-math/         # Math rendering (pdflatex → Native Rust)
│   ├── editio-template/     # Template system (YAML-based, inheritance)
│   ├── editio-plugin/       # Plugin API crate (stable interface - design from start)
│   └── editio-plugin-manager/ # Plugin management (WASM/dylib loading)
├── tests/                   # Integration tests
├── examples/                # Example documents
├── templates/               # Built-in templates
└── docs/                    # Documentation
```

---

## 4. CLI Command Structure

Editio is a CLI tool, not a web service. The "API" is the command-line interface:

```rust
// CLI structure using clap
#[derive(Parser)]
#[command(name = "editio")]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    Compile {
        input: Vec<PathBuf>,
        #[arg(short, long)]
        output: Option<PathBuf>,
        #[arg(short, long)]
        template: Option<String>,
        #[arg(long)]
        format: Option<OutputFormat>,
    },
    Check {
        input: PathBuf,
    },
    Watch {
        input: PathBuf,
        #[arg(short, long)]
        output: Option<PathBuf>,
    },
    Init {
        #[arg(long)]
        template: Option<String>,
    },
    Template {
        #[command(subcommand)]
        command: TemplateCommands,
    },
    Plugin {
        #[command(subcommand)]
        command: PluginCommands,
    },
}
```

---

## 5. Library API (for programmatic use)

If used as a library:

```rust
use editio_core::{compile, CompileOptions};

let options = CompileOptions {
    input: "document.md",
    output: "output.pdf",
    format: OutputFormat::Pdf,
    template: None,
};

compile(&options)?;
```

---

## 6. Data Model

### 6.1 AST (Abstract Syntax Tree) Structure

The core data model is an AST representing the document structure:

```rust
// Core AST node types (editio-ast crate)
pub enum Node {
    Document(Vec<Node>),
    Paragraph(Vec<Inline>),
    Heading { level: u8, content: Vec<Inline> },
    Image { src: String, caption: Option<String>, attrs: Attributes },
    Table { headers: Vec<Vec<Inline>>, rows: Vec<Vec<Vec<Inline>>> },
    Math { content: String, display: bool, label: Option<String> },
    Citation { key: String, style: CitationStyle },
    CrossReference { label: String, text: Option<String> },
    Theorem { label: Option<String>, content: Vec<Node> },
    Algorithm { label: Option<String>, caption: Option<String>, content: Vec<Node> },
    CodeBlock { language: Option<String>, label: Option<String>, caption: Option<String>, content: String },
    // ... other node types
}
```

### 6.2 Rust Types and Enums

Key types needed:

```rust
// Layout metadata
pub struct LayoutMetadata {
    pub page_size: PageSize,
    pub margins: Margins,
    pub font_size: f64,
    pub wrap_zones: Vec<WrapZone>,
    pub page_breaks: Vec<usize>,
}

// Attributes for images, tables, etc.
pub struct Attributes {
    pub float: Option<FloatPosition>,
    pub width: Option<Dimension>,
    pub height: Option<Dimension>,
    pub label: Option<String>,
    pub caption: Option<String>,
}

// Citation styles
pub enum CitationStyle {
    AuthorYear,
    Numeric,
}

// Page settings from YAML front matter
pub struct DocumentMetadata {
    pub title: Option<String>,
    pub author: Option<String>,
    pub date: Option<String>,
    pub page_size: Option<PageSize>,
    pub margins: Option<Margins>,
    pub font_size: Option<f64>,
}
```

### 6.3 Bibliography Data Structure

| Field | Type | Description |
|--------|------|-------------|
| Entry Key | `String` | Unique identifier (e.g., "smith2024") |
| Entry Type | `EntryType` | article, book, inproceedings, etc. |
| Fields | `HashMap<String, String>` | title, author, year, journal, etc. |
| Citation Format | `CitationFormat` | Author-year or numeric style |

---

## 7. Key Libraries

- **Markdown Parser**: `pulldown-cmark` (CommonMark compliant, fast, extensible)
- **PDF Generation**: `printpdf` (high-level API, PDF creation focus)
- **HTML Generation**: `maud`, `askama`, or manual generation (evaluate options)
- **Word Generation**: `docx-rs` or similar (evaluate options)
- **YAML Parsing**: `serde-yaml`
- **BibTeX Parsing**: `bibtex-parser` or custom parser (evaluate options)
- **Math Rendering (PDF)**: Shell out to `pdflatex` (MVP) → Native Rust renderer (post-MVP)
- **Math Rendering (HTML)**: KaTeX (primary), MathJax (fallback)
- **Template Engine**: `handlebars` or `tera` (evaluate options)
- **CSL Processing**: CSL library for citation styles (evaluate Rust options)
- **WASM Runtime**: For plugin system (e.g., `wasmtime` or `wasmer`)

---

## 8. Critical Path Items

1. Two-pass layout engine with CSS-style float algorithm
2. Text wrapping around figures including with lists
3. PDF generation with custom layout
4. Cross-references system
5. Basic math rendering
6. Bibliography system
7. Figure/table support with numbering

---

## 9. High Risk Items

- Text wrapping algorithm - Complex, critical differentiator (allocate extra time)
- Two-pass layout performance - Ensure meets <1 second target (optimize early)
- Figure wrapping with lists - Known LaTeX/Typst issue, must work (test extensively)
- PDF math embedding - pdflatex integration complexity (research thoroughly)

---

## 10. Success Criteria

### Phase 1 (MVP) Success Criteria:
- Compiles 20-page academic paper in <1 second
- Text wrapping around figures works reliably (including with lists)
- Cross-references work correctly
- Basic math renders in PDF
- Bibliography generates correctly
- Can compile real academic papers from test corpus
- CLI compilation works end-to-end
- All core formatting features working

### Phase 2 (Feature Complete) Success Criteria:
- All output formats work (PDF, LaTeX, HTML, Word)
- Document chaining works with cross-file references
- Template system with inheritance works
- All P1 academic extensions implemented
- Plugin system functional (can load and execute WASM plugins)
- 5-10x faster than LaTeX for typical/large documents

### Phase 3 (Polish) Success Criteria:
- Native Rust math renderer replaces pdflatex
- Performance optimized (meets all targets consistently)
- Comprehensive template library available
- Plugin ecosystem with central registry
- VSCode plugin/Language Server working
- Complete documentation and examples
