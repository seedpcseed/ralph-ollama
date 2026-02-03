# Technical Specifications

## Architecture
- **External APIs Required**: pdflatex for math rendering (MVP), KaTeX for HTML output, CSL library for citation styles (post-MVP)
- **Core Rust Functions**: Main compilation function, parser functions, layout functions, renderer functions
- **Background Jobs**: Not applicable – Editio is a CLI tool that runs synchronously. Future watch mode will use file system watchers.
- **File Structure**: Workspace with crates for each component (editio, editio-core, editio-ast, editio-parser, etc.)

## Data Model
- **AST (Abstract Syntax Tree) Structure**: Core data model is an AST representing the document structure
- **Rust Types and Enums**: Key types needed for layout metadata, attributes, citation styles, document metadata, bibliography data structure

## User Interface
- **Access Point**: CLI Tool (`editio` command), Installation via Cargo or pre-built binaries, Usage is command-line interface with subcommands
- **CLI Commands**: Compile markdown to PDF, Check syntax, Watch mode for development, Initialize new project, Template management, Plugin management
- **Configuration File (`editio.toml`)**: Document settings, output settings, plugin configuration

## API Routes
- **CLI Command Structure**: Editio is a CLI tool, not a web service. The "API" is the command-line interface
- **Library API (for programmatic use)**: If used as a library, functions for compilation and configuration options

## Edge Cases & Error Handling
- **Scenario**: Missing pdflatex for math rendering, Invalid markdown syntax, Missing bibliography file, Unresolved cross-reference, Circular includes in document chaining, Image file not found, Table with inconsistent column count, Math syntax error, Very large documents (1000+ pages), Figure wrapping edge cases (lists, nested elements), Duplicate labels, Unused labels, Invalid YAML front matter, Template not found, Plugin load failure
- **Handling**: Clear error message with line number and context, Error listing missing label and location, Warning for unused labels, Error with suggestion to list available templates, Fallback to inline placement if wrapping fails, Placeholder rendering if pdflatex unavailable, Basic page formatting in PDF output

## Security & Privacy
- **Authentication**: Not applicable – CLI tool runs locally with user's file system permissions
- **Authorization**: Not applicable – no multi-user system
- **Data privacy**: All processing happens locally, No network calls (except optional plugin installation from Git repos), No data collection or telemetry (configurable), Bibliography files and documents remain on user's machine
- **Plugin Security**: WASM plugins run in sandboxed environment, Dylib plugins require explicit user trust, Plugin permissions system (read files, write output, no network/system calls by default)
- **File System Access**: Only reads specified input files, Only writes to specified output location, No access to other files unless explicitly specified
