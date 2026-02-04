use pulldown_cmark::{Parser, Event};
// ... other imports ...

pub fn parse(markdown: &str) -> Vec<Node>  {
    let parser = Parser::new(markdown);
    // ... existing code ...
    
    for event in parser  {
        match event  {
            // ... existing matches ...
            
            Event::Strikethrough(_start, _end) => {   // Add this block to handle strikethrough events
                let mut text = String::new();
                loop  {
                    match parser.next()  {
                        Some(Event::Text(text)) => text.push_str(&text),
                        _ => break,
                    }
                }
                nodes.push(Node::Strikethrough(text));
            },
            
            Event::TaskList(_start, _end) => {   // Add this block to handle task list events
                let mut items = vec![];
                loop  {
                    match parser.next()  {
                        Some(Event::ItemEnd(_)) | None => break,
                        Some(event) => {
                            if let Event::Text(text) = event  {
                                items.push(Node::Paragraph(String::from_utf8(text.fragment).unwrap()));
                            }
                        },
                    }
                }
                nodes.push(Node::TaskList(items));
            },
        }
    }
    
    // ... existing code ...
}
