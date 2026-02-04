use pulldown_cmark::{Parser, Event};
// ... other imports ...

pub fn parse(markdown: &str) -> Vec<Node>  {
    let parser = Parser::new(markdown);
    // ... existing code ...
    
    for event in parser  {
        match event  {
            // ... existing matches ...
            
            Event::Start(_start_data) => {   // Add this block to handle code block events
                let mut text = String::new();
                loop  {
                    match parser.next()  {
                        Some(Event::Text(text)) => text.push_str(&text),
                        _ => break,
                    }
                }
                nodes.push(Node::CodeBlock(text));
            },
            
            // ... other event types ...
        }
    }
    
    // ... existing code ...
}
