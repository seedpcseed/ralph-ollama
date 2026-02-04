use pulldown_cmark::{Parser, Event};
use std::collections::HashMap;
use self::ast::Node;

pub fn parse(markdown: &str) -> Vec<Node> {
    let parser = Parser::new(markdown);
    let mut nodes = vec![];
    
    for event in parser {
        match event {
            Event::Start(_) => {},
            Event::End(_) => {},
            Event::Html(_) => {},
            Event::Text(text) => {
                nodes.push(Node::Paragraph(String::from_utf8(text.fragment).unwrap()));
            },
        }
    }
    
    nodes
}
