//! Build AST from pulldown-cmark Event stream.

use crate::{Attributes, Inline, Node};
use pulldown_cmark::{Event, Tag};

/// Build a document Node from markdown string (parsed to events then to AST).
pub fn build_from_markdown(md: &str) -> Node {
    let events: Vec<_> = pulldown_cmark::Parser::new(md).collect();
    build_from_events(&events)
}

/// Build AST from a slice of Events.
pub fn build_from_events(events: &[Event<'_>]) -> Node {
    let mut children = Vec::new();
    let mut i = 0;
    while i < events.len() {
        if let Some((node, advance)) = parse_block(events, i) {
            children.push(node);
            i += advance;
        } else {
            i += 1;
        }
    }
    Node::Document {
        children,
        metadata: None,
    }
}

fn parse_block(events: &[Event<'_>], start: usize) -> Option<(Node, usize)> {
    let e = events.get(start)?;
    match e {
        Event::Start(Tag::Paragraph) => {
            let (inlines, len) = parse_inlines_until(events, start + 1, Tag::Paragraph);
            Some((
                Node::Paragraph { content: inlines },
                len + 1,
            ))
        }
        Event::Start(Tag::Heading(level, ..)) => {
            let (inlines, len) = parse_inlines_until_heading(events, start + 1);
            let n: u32 = match level {
                pulldown_cmark::HeadingLevel::H1 => 1,
                pulldown_cmark::HeadingLevel::H2 => 2,
                pulldown_cmark::HeadingLevel::H3 => 3,
                pulldown_cmark::HeadingLevel::H4 => 4,
                pulldown_cmark::HeadingLevel::H5 => 5,
                pulldown_cmark::HeadingLevel::H6 => 6,
            };
            Some((
                Node::Heading {
                    level: n,
                    content: inlines,
                },
                len + 1,
            ))
        }
        Event::Start(Tag::Image(_, src, alt)) => {
            Some((
                Node::Image {
                    src: src.to_string(),
                    alt: Some(alt.to_string()),
                    attrs: Attributes::default(),
                },
                2,
            ))
        }
        Event::Start(Tag::CodeBlock(_)) => {
            if let Some(Event::Text(t)) = events.get(start + 1) {
                Some((
                    Node::CodeBlock {
                        language: None,
                        label: None,
                        caption: None,
                        content: t.to_string(),
                    },
                    3,
                ))
            } else {
                Some((
                    Node::CodeBlock {
                        language: None,
                        label: None,
                        caption: None,
                        content: String::new(),
                    },
                    3,
                ))
            }
        }
        _ => None,
    }
}

fn parse_inlines_until(events: &[Event<'_>], start: usize, end_tag: Tag<'_>) -> (Vec<Inline>, usize) {
    let mut inlines = Vec::new();
    let mut i = start;
    while i < events.len() {
        if let Some(Event::End(t)) = events.get(i) {
            if std::mem::discriminant(t) == std::mem::discriminant(&end_tag) {
                return (inlines, i - start + 1);
            }
        }
        if let Some(inl) = event_to_inline(events.get(i)) {
            inlines.push(inl);
        }
        if let Some(Event::Text(t)) = events.get(i) {
            inlines.push(Inline::Text(t.to_string()));
        }
        i += 1;
    }
    (inlines, i - start)
}

fn parse_inlines_until_heading(events: &[Event<'_>], start: usize) -> (Vec<Inline>, usize) {
    let mut inlines = Vec::new();
    let mut i = start;
    while i < events.len() {
        if let Some(Event::End(Tag::Heading(..))) = events.get(i) {
            return (inlines, i - start + 1);
        }
        if let Some(Event::Text(t)) = events.get(i) {
            inlines.push(Inline::Text(t.to_string()));
        }
        i += 1;
    }
    (inlines, i - start)
}

fn event_to_inline(e: Option<&Event<'_>>) -> Option<Inline> {
    match e? {
        Event::Code(t) => Some(Inline::Code(t.to_string())),
        _ => None,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_ast_building() {
        let md = "# Hello\n\nA **paragraph**.";
        let doc = build_from_markdown(md);
        match &doc {
            Node::Document { children, .. } => {
                assert!(!children.is_empty());
            }
            _ => panic!("expected Document"),
        }
    }
}
