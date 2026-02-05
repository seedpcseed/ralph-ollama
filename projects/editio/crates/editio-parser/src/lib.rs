//! Editio markdown and document parser.

pub mod front_matter;
pub mod parser;

pub use front_matter::{parse_yaml_front_matter, split_front_matter, FrontMatter, MarginSpec};
pub use parser::{parse_events, parse_to_events};
