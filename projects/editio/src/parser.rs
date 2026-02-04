use pulldown_cmark::{Parser, Event};
//  ... other imports ...

pub fn parse(markdown: &str) -> Vec<Node> {
    let parser = Parser::new(markdown);
    //  ... existing code ...
    
    for event in parser {
        match event {
            //  ... existing matches ...
            
            Event::List(_start, _type) => {   // Add this block to handle list events
                let mut items = vec![];
                loop {
                    match parser.next() {
                        Some(Event::ItemEnd(_)) | None => break,
                        Some(event) => {
                            if let Event::Text(text) = event {
                                items.push(Node::Paragraph(String::from_utf8(text.fragment).unwrap()));
                             }
                         },
                    }
                }
                nodes.push(Node::List(items));
            },
        }
    }
    
    //  ... existing code ...
}
