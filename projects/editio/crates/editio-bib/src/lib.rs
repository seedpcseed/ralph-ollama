//! Editio bibliography.

pub mod formatter;
pub mod parser;
pub mod resolver;

pub use formatter::{format_author_year, format_numeric};
pub use parser::{parse_bibtex, BibEntry};
pub use resolver::resolve_citations;
