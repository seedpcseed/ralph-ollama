use pulldown_cmark::{Parser, Event};
// ... other imports ...

pub fn parse(markdown: &str) -> Vec<Node>   {
    let parser = Parser::new(markdown);
    // ... existing code ...
    
    for event in parser  {
        match event  {
            // ... existing matches ...
            
            Event::Start(_start_data) => {    // Add this block to handle image events with YAML attributes support
                let mut attrs = Vec::new();
                loop  {
                    match parser.next()  {
                        Some(Event::Attr((key, value))) => {
                            attrs.push((key.to_string(), value.unwrap_or("").to_string()));
                        },
                        _ => break,
                    }
                }
                nodes.push(Node::Image(_start_data.label.as_str().unwrap_or("").to_string(), attrs));
            },
            
            // ... other event types ...
        }
    }
    
    // ... existing code ...
}
