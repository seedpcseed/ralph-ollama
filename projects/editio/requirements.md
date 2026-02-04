# Technical Specifications Extracted from the PRD

## Architecture

The architecture of Editio is designed to be modular and extensible. The core library `editio-core` orchestrates everything, while each feature has its own crate (e.g., `editio-parser` for markdown parsing). This separation allows for clear responsibilities and makes it easier to maintain and extend the project.

## Data Models

The core data model is an AST representing the document structure:

```rust
// Core AST node types 
pub enum Node {
    // ...
}
```

Other key types needed include `LayoutMetadata`, `Attributes`, and `CitationStyle`.

## APIs

The main CLI command-line interface is used as the access point for users. The library API (for programmatic use) allows integration with other systems or tools.

## UI/UX Constraints

Editio aims to provide a simple and intuitive command-line interface, similar to `git` or `npm`. This makes it easy for users to get started without needing extensive documentation. The focus is on the core features of academic writing: markdown syntax, figure wrapping, math typesetting, bibliography management, etc.

## Performance and Security Requirements

Editio prioritizes performance over all other aspects. It aims to be 5-10x faster than LaTeX for typical/large documents. The project is designed with security in mind, ensuring that user data remains on the user's machine and no network calls are made unless explicitly specified by the user.

## Tech Stack

Editio is built using Rust due to its performance, memory safety, and concurrency support. Other key libraries include `pulldown-cmark` for markdown parsing, `printpdf` for PDF generation, and `serde-yaml` for YAML parsing. The project also uses GitHub Actions for CI/CD and Git as the version control system.

## Other Technical Details

The two-pass layout engine with CSS-style float algorithm is a critical differentiator of Editio. It ensures that text flows around figures, including with lists, providing a reliable user experience. The native Rust math renderer replaces pdflatex for PDF generation, ensuring fast and efficient rendering.

The plugin system allows users to extend the functionality of Editio without modifying the core codebase. This is achieved through WASM plugins, which are loaded into a sandboxed environment. The plugin permissions system ensures that plugins can only access files, write output, and perform basic operations by default.

Editio also includes comprehensive documentation and examples to help users get started with the project. It aims to be a tool for both academic writers and developers, providing clear documentation and examples to ensure ease of use.
