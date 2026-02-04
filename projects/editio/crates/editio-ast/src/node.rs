use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
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
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum Inline {
    Text(String),
    Emphasis(Vec<Inline>),
    Strong(Vec<Inline>),
    Code(String),
    Link { text: Vec<Inline>, url: String },
    Image { alt: String, url: String },
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Attributes {
    pub float: Option<FloatPosition>,
    pub width: Option<Dimension>,
    pub height: Option<Dimension>,
    pub label: Option<String>,
    pub caption: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum FloatPosition {
    Left,
    Right,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Dimension {
    pub value: f64,
    pub unit: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum CitationStyle {
    AuthorYear,
    Numeric,
}
```