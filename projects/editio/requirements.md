# Technical Specifications

## Architecture
The architecture of the project is based on a modular design, with separate crates for each feature. The main components are:
- **Markdown Parser** (`pulldown-cmark`): This handles parsing markdown into an Abstract Syntax Tree (AST).
- **Two-Pass Layout Engine**: This takes the AST and lays out the document, handling text wrapping around figures.
- **CLI Interface**: This provides a command-line interface for compiling documents.
- **Cross-References System**: This handles linking between different parts of the document.
- **Math Rendering** (`pdflatex`): This renders mathematical equations into PDF format.
- **Bibliography Generation**: This generates a bibliography section based on citations in the text.
- **Figure/Table Support**: This handles figures and tables, including their numbering and captions.

## Data Models
The data models are represented by Rust structs and enums. The main ones are:
- **AST Node**: Represents a node in the Abstract Syntax Tree. It can be one of several types (headline, paragraph, code block, etc.).
- **CLI Args**: Represents command-line arguments passed to the program.
- **Cross-Reference**: Represents a cross-reference from one part of the document to another.
- **Bibliography Entry**: Represents an entry in the bibliography section.
- **Figure/Table**: Represents a figure or table, including its number and caption.

## API
The API is RESTful and uses JSON for data interchange. The main endpoints are:
- `POST /compile`: Compiles a document from markdown to the specified output format (PDF, HTML, Word).
- `GET /status/{id}`: Returns the status of a compilation job.
- `GET /result/{id}`: Returns the result of a successful compilation job.

## UI
The user interface is command-line based and provides feedback through text output. It includes:
- **Progress Bar**: Shows the progress of a compilation job.
- **Error Messages**: Displays error messages when something goes wrong.
- **Help Text**: Provides help text for each command.

## Performance
The performance targets are to compile 20-page academic papers in less than 1 second, and handle figures with text wrapping around them.

## Security
Security is handled through Rust's ownership and borrowing rules. All data is validated before use to prevent code injection or other attacks.
