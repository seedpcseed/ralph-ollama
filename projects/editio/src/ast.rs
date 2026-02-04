pub enum Node  {
    // ... existing variants ...
    Strikethrough(String),   // Add this line to handle strikethrough text
    TaskList(Vec<Node>),     // Add this line to handle task lists
}
