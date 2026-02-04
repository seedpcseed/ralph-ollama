use pulldown_cmark::{Parser, Event};
//   ... other imports  ...

pub fn parse(markdown: &str) -> Vec<Node>  {
    let parser = Parser::new(markdown);
    //   ... existing code  ...
    
    for event in parser {
        match event {
            //   ... existing matches  ...
            
            Event::Text(text) => {    // Add this block to handle text events
                nodes.push(Node::Paragraph(text));
            },
            
            //   ... other event types  ...
        }
    }
    
    //   ... existing code  ...
}
