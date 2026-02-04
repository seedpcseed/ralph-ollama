# Technical Requirements - Editio

Generated from PRD v1.0

## Architecture

### Workspace Structure
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
│   ├── editio-bib/          # Bibliography (BibTeX, BibLaTeX, RIS, EndNote)
│   └── editio-math/         # Math rendering (pdflatex → Native Rust)
├── tests/                   # Integration tests
├── examples/                # Example documents
└── docs/                    # Documentation
```

## Data Models

### AST Node Types
```rust
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

### Layout Metadata
```rust
pub struct LayoutMetadata {
    pub page_size: PageSize,
    pub margins: Margins,
    pub font_size: f64,
    pub wrap_zones: Vec<WrapZone>,
    pub page_breaks: Vec<usize>,
}
```

### Attributes
```rust
pub struct Attributes {
    pub float: Option<FloatPosition>,
    pub width: Option<Dimension>,
    pub height: Option<Dimension>,
    pub label: Option<String>,
    pub caption: Option<String>,
}
```

### Document Metadata
```rust
pub struct DocumentMetadata {
    pub title: Option<String>,
    pub author: Option<String>,
    pub date: Option<String>,
    pub page_size: Option<PageSize>,
    pub margins: Option<Margins>,
    pub font_size: Option<f64>,
}
```

## Core Functions

### Parser Functions
- `parse_markdown(input: &str) -> Result<Document, ParseError>`
- `build_ast(events: Vec<Event>) -> Result<Node, ASTError>`
- `parse_front_matter(input: &str) -> Result<DocumentMetadata, ParseError>`

### Layout Functions
- `calculate_layout(ast: &Node, metadata: &DocumentMetadata) -> Result<LayoutMetadata, LayoutError>`
- `calculate_wrap_zones(floats: &[Float], content: &[Content]) -> Vec<WrapZone>`
- `measure_pass(ast: &Node) -> LayoutMeasurements`
- `place_pass(measurements: &LayoutMeasurements) -> LayoutMetadata`

### Renderer Functions
- `render_pdf(ast: &Node, layout: &LayoutMetadata) -> Result<Vec<u8>, RenderError>`
- `render_html(ast: &Node) -> Result<String, RenderError>`
- `render_latex(ast: &Node) -> Result<String, RenderError>`

## External Dependencies

### Rust Crates
- `pulldown-cmark` (v0.9) - CommonMark parser
- `printpdf` (v0.7) - PDF generation
- `serde-yaml` (v0.9) - YAML parsing
- `clap` (v4.5) - CLI argument parsing

### External Tools
- `pdflatex` - Math rendering subprocess (MVP)
- `KaTeX` - HTML math rendering (Phase 2)

## Performance Targets

- Typical 20-page paper: <1 second (target: ~50-100ms)
- Large 100-page document: <1 second (target: ~200-600ms)
- Very large 1000+ pages: Comparable to LaTeX (acceptable)
- 5-10x faster than LaTeX for typical/large documents

## Key Technical Features

### Two-Pass Layout Engine
1. **Pass 1: Measure** - Calculate dimensions of all elements
2. **Pass 2: Place** - Position all elements using measurements
3. CSS-style float algorithm with automatic text wrapping
4. List wrapping around figures (key differentiator)

### Markdown Parsing
- CommonMark compliance
- GitHub Flavored Markdown extensions
- YAML-style attributes: `![caption](img.png){float=right width=50% label=fig:1}`
- Block directives: `:::{theorem}{label=thm:1}...:::`

### Cross-Reference System
- Unified syntax: `[@label]` or `[See Figure @fig:label]`
- Automatic numbering for figures, tables, equations
- Compile-time resolution

### Bibliography System
- BibTeX parser
- Citation syntax: `[@author2024]`
- Citation styles: Author-year and Numeric formats
- Basic APA, MLA, Chicago, IEEE support

### Math Typesetting
- LaTeX syntax: `$E=mc^2$` (inline), `$$\int_0^1$$` (display)
- Math labels: `$$\int_0^1$${label=eq:1}`
- PDF rendering via pdflatex subprocess (MVP)
- Native Rust renderer (Phase 3)

## CLI Interface

### Commands
- `editio compile <file> -o <output>` - Compile markdown to PDF
- `editio check <file>` - Validate syntax

### Configuration
- `editio.toml` or `.editio.yaml` for project settings
- YAML front matter in markdown files for document metadata

## Error Handling

- Clear error messages with line numbers
- Missing dependency warnings (e.g., pdflatex)
- Unresolved reference errors
- Invalid syntax errors with context
- File not found errors with suggestions
