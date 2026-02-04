# Technical requirements 

## Architecture
The core data model is an AST representing the document structure:

```rust
// Core AST node types 
pub enum Node {
    Document(Vec<Node>),
    Paragraph(Vec<Inline>),
    Heading { level: u8, content: Vec<Inline> },
    Image { src: String, caption: Option<String>, attrs: Attributes },
    Table { headers: Vec<Vec<Inline>>, rows: Vec<Vec<Vec<Inline>>> },
    Math { content: String, display: bool, label: Option<String> },
    Citation { key: String, style: CitationStyle },
    CrossReference { label: String, text: Option<String> },
    // ... other node types
}
```

## Data Model
The core data model is an AST representing the document structure. It includes nodes for different elements of a document such as paragraphs, headings, images, tables, and math equations. Each node has its own set of attributes that define how it should be rendered in the final output.

## User Interface
Editio's user interface is a command-line application called `editio`. It provides several subcommands for different tasks such as compiling documents, checking syntax, and managing templates and plugins. The CLI commands are designed to be intuitive and easy to use.

## API Routes
The core functionality of Editio is exposed through a library API that can be used programmatically in other applications. This allows for integration with existing workflows and the creation of custom tools or extensions.

## Edge Cases & Error Handling
Editio has robust error handling mechanisms to ensure that it can handle edge cases gracefully. It provides clear error messages when something goes wrong, and it also includes a variety of checks to prevent common errors from happening in the first place. For example, Editio will check for missing pdflatex before trying to render math equations, or it will warn users if they are using unresolved cross-references.

## Security & Privacy
Editio takes security and privacy very seriously. All processing happens locally, no network calls are made (except optional plugin installation from Git repos), and no data collection or telemetry is done by default. However, Editio does not have a multi-user system, so it's important to use it in a secure environment where you trust the user.

## Implementation Phases
Editio is developed over several phases, each focusing on different aspects of its functionality. The first phase focuses on creating a Minimum Viable Product (MVP) that includes basic markdown parsing, two-pass layout engine, PDF generation, and academic extensions like cross-references, theorem environments, algorithm listings, and code listings with captions.

## Open Questions
There are several open questions about the project's future direction. These include whether to prioritize a native Rust math renderer or continue using pdflatex for MVP, whether to design the plugin system earlier even if implementation is later, and whether to support multiple syntax styles from MVP or start with YAML only.

## References
Editio's development process relies heavily on several key libraries and tools. These include `pulldown-cmark` for markdown parsing, `printpdf` for PDF generation, `maud` or `askama` for HTML generation, `docx-rs` for Word generation, `serde-yaml` for YAML parsing, and `bibtex-parser` for BibTeX parsing.

## Appendix
The appendix includes an example of a markdown document that Editio can compile, as well as additional technical details about the project's implementation.