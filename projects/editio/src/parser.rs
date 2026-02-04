use pulldown_cmark::{Parser, Event};
// ... other imports ...

pub fn parse(markdown: &str) -> Vec<Node> {
    let parser = Parser::new(markdown);
    // ... existing code ...
    
    for event in parser {
        match event {
            // ... existing matches ...
            
            Event::CodeBlock(text) => { // Add this block to handle code block events
                nodes.push(Node::CodeBlock(text));
            },
            
            // ... other event types ...
        }
    }
    
    // ... existing code ...
}
