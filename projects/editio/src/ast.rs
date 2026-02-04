pub enum Node {
    Headline(String),
    Paragraph(String),
    CodeBlock(String),
    Table(Vec<Vec<String>>),
    Image(String, Option<HashMap<String, String>>),
}
