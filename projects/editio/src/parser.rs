use pulldown_cmark::{Parser, Event};
// ... other imports ...

pub fn parse(markdown: &str) -> Vec<Node>  {
    let parser = Parser::new(markdown);
    // ... existing code ...
    
    for event in parser  {
        match event  {
            // ... existing matches ...
            
            Event::Start(_start_data) => {   // Add this block to handle table events
                let mut rows = Vec::new();
                loop  {
                    match parser.next()  {
                        Some(Event::TableRow(row)) => {
                            let cells: Vec<String> = row.into_iter().map(|cell| cell.as_str().to_string()).collect();
                            rows.push(cells);
                        },
                        _ => break,
                    }
                }
                nodes.push(Node::Table(rows));
            },
            
            // ... other event types ...
        }
    }
    
    // ... existing code ...
}
