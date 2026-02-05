//! Editio abstract syntax tree.

pub mod builder;
pub mod citation_parser;
pub mod cross_ref_parser;
pub mod label_registry;

pub use builder::{build_from_events, build_from_markdown};
pub use citation_parser::{citation_node, find_citation_keys};
pub use cross_ref_parser::{cross_ref_node, find_cross_ref_targets};
pub use label_registry::{LabelMeta, LabelRegistry, LabelType};

use std::collections::HashMap;

/// Block-level AST node.
#[derive(Debug, Clone)]
pub enum Node {
    Document {
        children: Vec<Node>,
        metadata: Option<DocumentMetadata>,
    },
    Paragraph {
        content: Vec<Inline>,
    },
    Heading {
        level: u32,
        content: Vec<Inline>,
    },
    Image {
        src: String,
        alt: Option<String>,
        attrs: Attributes,
    },
    Table {
        header: Vec<Vec<Inline>>,
        rows: Vec<Vec<Vec<Inline>>>,
        attrs: Attributes,
    },
    Math {
        content: String,
        display: bool,
        label: Option<String>,
    },
    Citation {
        key: String,
    },
    CrossReference {
        target: String,
    },
    Theorem {
        label: Option<String>,
        caption: Option<String>,
        content: Vec<Node>,
    },
    Algorithm {
        label: Option<String>,
        caption: Option<String>,
        content: Vec<Node>,
    },
    CodeBlock {
        language: Option<String>,
        label: Option<String>,
        caption: Option<String>,
        content: String,
    },
}

/// Document-level metadata (from front matter).
#[derive(Debug, Clone, Default)]
pub struct DocumentMetadata {
    pub title: Option<String>,
    pub author: Option<String>,
    pub date: Option<String>,
    pub page_size: Option<String>,
    pub margins: Option<LayoutMetadata>,
    pub font_size: Option<f64>,
}

/// Inline content.
#[derive(Debug, Clone)]
pub enum Inline {
    Text(String),
    Code(String),
    Link { text: String, url: String },
    Image { alt: String, src: String },
    Strong(Vec<Inline>),
    Emph(Vec<Inline>),
}

/// Generic attributes (e.g. float, width, height, label).
#[derive(Debug, Clone, Default)]
pub struct Attributes {
    pub float: Option<String>,
    pub width: Option<String>,
    pub height: Option<String>,
    pub label: Option<String>,
    pub extra: HashMap<String, String>,
}

/// Layout metadata (margins, etc.).
#[derive(Debug, Clone)]
pub struct LayoutMetadata {
    pub top: Option<f64>,
    pub bottom: Option<f64>,
    pub left: Option<f64>,
    pub right: Option<f64>,
}
