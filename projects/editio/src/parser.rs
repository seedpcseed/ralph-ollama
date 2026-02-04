use pulldown_cmark::{Parser, Event};
//  ... other imports ...

pub fn parse(markdown: &str) -> Vec<Node> {
    let parser = Parser::new(markdown);
    //  ... existing code ...
    
    for event in parser {
        match event {
            //  ... existing matches ...
            
            Event::Start(_start_data) => {   // Add this block to handle heading events
                if _start_data.level == 1 {
                    nodes.push(Node::Heading1(_start_data.label.as_str().unwrap_or("").to_string()));
                } else if _start_data.level == 2 {
                    nodes.push(Node::Heading2(_start_data.label.as_str().unwrap_or("").to_string()));
                } // Add more levels as needed
            },
            
            //  ... other event types ...
        }
    }
    
    //  ... existing code ...
}
