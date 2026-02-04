pub enum Node {
    Headline(String),
    Paragraph(String),
    CodeBlock(String),
    Table(Vec<Vec<String>>), // Add this line to handle tables
    Image(String, Option<HashMap<String, String>>),
}
