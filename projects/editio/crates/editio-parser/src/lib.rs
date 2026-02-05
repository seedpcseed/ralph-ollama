//! Editio markdown and document parser.

pub mod directive_parser;
pub mod front_matter;
pub mod image_parser;
pub mod math_parser;
pub mod parser;
pub mod table_parser;

pub use directive_parser::{DirectiveKind, ParsedDirective, parse_directive_opening};
pub use front_matter::{parse_yaml_front_matter, split_front_matter, FrontMatter, MarginSpec};
pub use image_parser::{parse_image_attributes, ImageAttributes};
pub use math_parser::{find_display_math, find_inline_math, MathSpan};
pub use parser::{parse_events, parse_to_events};
pub use table_parser::{parse_table_attributes, TableAttributes};
