use pulldown_cmark::{Parser, Event};
use std::collections::HashMap;
use self::ast::Node;

pub fn parse(markdown: &str) -> Vec<Node>  {
    let parser = Parser::new(markdown);
    let mut nodes = vec![];
    
    for event in parser  {
        match event  {
            Event::Start(_) => {},
            Event::End(_) => {},
            Event::Html(_) => {},
            Event::Text(text) => {
                nodes.push(Node::Paragraph(String::from_utf8(text.fragment).unwrap()));
              },
            // Add this block to handle table events
            Event::TableHeader => {
                let mut headers = vec![];
                for event in parser  {
                    match event  {
                        Event::Start(_) | Event::End(_) | Event::Html(_) => {},
                        Event::Text(text) => {
                            headers.push(String::from_utf8(text.fragment).unwrap());
                          },
                        _ => break,
                     }
                 }
                nodes.push(Node::Table(vec![headers]));
             },
            // Add this block to handle image events
            Event::Image(alt, url) => {
                let alt = String::from_utf8(alt).unwrap();
                let url = String::from_utf8(url.fragment).unwrap();
                nodes.push(Node::Image(url, Some(HashMap::new()))); // TODO: Parse attributes from YAML syntax
             },
         }
     }
    
    nodes
}
