//! Build AST from pulldown-cmark Event stream.

use crate::{Attributes, Inline, Node};
use crate::cross_ref_parser::find_cross_ref_targets;
use pulldown_cmark::{Event, Options, Parser, Tag};

/// Parser options: enable GFM tables (and related extensions) so tables are parsed.
fn markdown_options() -> Options {
    let mut opts = Options::empty();
    opts.insert(Options::ENABLE_TABLES);
    opts.insert(Options::ENABLE_STRIKETHROUGH);
    opts.insert(Options::ENABLE_TASKLISTS);
    opts
}

/// Build a document Node from markdown string (parsed to events then to AST).
pub fn build_from_markdown(md: &str) -> Node {
    let events: Vec<_> = Parser::new_ext(md, markdown_options()).collect();
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
            let mut attrs = Attributes::default();
            let mut advance = 2;
            for off in [2, 3] {
                if let Some(Event::Text(t)) = events.get(start + off) {
                    let t = t.trim_start();
                    if t.starts_with("{#") {
                        if let Some(end) = t.find('}') {
                            let id = t[2..end].trim();
                            if !id.is_empty() {
                                attrs.label = Some(id.to_string());
                                advance = off + 1;
                            }
                        }
                        break;
                    }
                }
            }
            Some((
                Node::Image {
                    src: src.to_string(),
                    alt: Some(alt.to_string()),
                    attrs,
                },
                advance,
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
        Event::Start(Tag::BlockQuote) => {
            let mut depth = 1u32;
            let mut end = start + 1;
            while end < events.len() {
                match events.get(end) {
                    Some(Event::Start(Tag::BlockQuote)) => depth += 1,
                    Some(Event::End(Tag::BlockQuote)) => {
                        depth -= 1;
                        if depth == 0 {
                            break;
                        }
                    }
                    _ => {}
                }
                end += 1;
            }
            let inner = &events[start + 1..end];
            let doc = build_from_events(inner);
            let content = match doc {
                Node::Document { children, .. } => children,
                _ => vec![],
            };
            Some((Node::BlockQuote { content }, end - start + 1))
        }
        Event::Start(Tag::List(opt)) => {
            let ordered = opt.is_some();
            let mut items = Vec::new();
            let mut i = start + 1;
            while i < events.len() {
                if let Some(Event::End(Tag::List(_))) = events.get(i) {
                    break;
                }
                if let Some(Event::Start(Tag::Item)) = events.get(i) {
                    let (inlines, len) = parse_inlines_until(events, i + 1, Tag::Item);
                    items.push(inlines);
                    i += len + 1;
                } else {
                    i += 1;
                }
            }
            let advance = i - start + 1;
            Some((Node::List { ordered, items }, advance))
        }
        Event::Start(Tag::Table(_)) => {
            let mut i = start + 1;
            let mut header = Vec::new();
            let mut rows = Vec::new();
            if let Some(Event::Start(Tag::TableHead)) = events.get(i) {
                i += 1;
                if let Some(Event::Start(Tag::TableRow)) = events.get(i) {
                    i += 1;
                    let (header_row, row_len) = parse_table_row(events, i);
                    header = header_row;
                    i += row_len + 1;
                }
                i += 1;
            }
            while i < events.len() {
                if let Some(Event::End(Tag::Table(_))) = events.get(i) {
                    break;
                }
                if let Some(Event::Start(Tag::TableRow)) = events.get(i) {
                    i += 1;
                    let (row_cells, row_len) = parse_table_row(events, i);
                    rows.push(row_cells);
                    i += row_len + 1;
                } else {
                    i += 1;
                }
            }
            let advance = i - start + 1;
            Some((
                Node::Table {
                    header,
                    rows,
                    attrs: Attributes::default(),
                },
                advance,
            ))
        }
        _ => None,
    }
}

fn parse_table_row(events: &[Event<'_>], start: usize) -> (Vec<Vec<Inline>>, usize) {
    let mut row = Vec::new();
    let mut i = start;
    while i < events.len() {
        if let Some(Event::End(Tag::TableRow)) = events.get(i) {
            return (row, i - start);
        }
        if let Some(Event::Start(Tag::TableCell)) = events.get(i) {
            let (inlines, len) = parse_inlines_until(events, i + 1, Tag::TableCell);
            row.push(inlines);
            i += len + 1;
        } else {
            i += 1;
        }
    }
    (row, i - start)
}

fn split_text_with_cross_refs(text: &str) -> Vec<Inline> {
    let mut inlines = Vec::new();
    let targets = find_cross_ref_targets(text);
    if targets.is_empty() {
        if !text.is_empty() {
            inlines.push(Inline::Text(text.to_string()));
        }
        return inlines;
    }
    let mut last = 0;
    let bytes = text.as_bytes();
    let mut i = 0;
    while i < bytes.len() {
        if bytes[i] == b'[' && i + 1 < bytes.len() && bytes[i + 1] == b'@' {
            let start = i + 2;
            let mut end = start;
            while end < bytes.len() && (bytes[end].is_ascii_alphanumeric() || bytes[end] == b':' || bytes[end] == b'-' || bytes[end] == b'_') {
                end += 1;
            }
            if end > start && end < bytes.len() && bytes[end] == b']' {
                if last < i {
                    inlines.push(Inline::Text(text[last..i].to_string()));
                }
                let target = text[start..end].to_string();
                if target.contains(':') {
                    inlines.push(Inline::CrossReference(target));
                } else {
                    inlines.push(Inline::Citation(target));
                }
                last = end + 1;
                i = end + 1;
                continue;
            }
        }
        i += 1;
    }
    if last < text.len() {
        inlines.push(Inline::Text(text[last..].to_string()));
    }
    inlines
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
        if let Some(Event::Start(tag)) = events.get(i) {
            match tag {
                Tag::Strong => {
                    let (inner, len) = parse_inlines_until(events, i + 1, Tag::Strong);
                    inlines.push(Inline::Strong(inner));
                    i += 1 + len;
                    continue;
                }
                Tag::Emphasis => {
                    let (inner, len) = parse_inlines_until(events, i + 1, Tag::Emphasis);
                    inlines.push(Inline::Emph(inner));
                    i += 1 + len;
                    continue;
                }
                Tag::Link(_, url, _) => {
                    let (inner, len) = parse_inlines_until(events, i + 1, Tag::Link(pulldown_cmark::LinkType::Inline, std::borrow::Cow::Borrowed("").into(), std::borrow::Cow::Borrowed("").into()));
                    let text: String = inner.iter().map(|x| inlines_to_plain_string(x).into_owned()).collect();
                    inlines.push(Inline::Link { text, url: url.to_string() });
                    i += 1 + len;
                    continue;
                }
                _ => {}
            }
        }
        if let Some(inl) = event_to_inline(events.get(i)) {
            inlines.push(inl);
        }
        if let Some(Event::Text(t)) = events.get(i) {
            inlines.extend(split_text_with_cross_refs(t));
        }
        i += 1;
    }
    (inlines, i - start)
}

fn inlines_to_plain_string(inline: &Inline) -> std::borrow::Cow<'_, str> {
    match inline {
        Inline::Text(t) => std::borrow::Cow::Borrowed(t.as_str()),
        Inline::Code(t) => std::borrow::Cow::Borrowed(t.as_str()),
        Inline::Link { text, .. } => std::borrow::Cow::Borrowed(text.as_str()),
        Inline::Strong(inner) | Inline::Emph(inner) => {
            let s: String = inner.iter().map(|x| inlines_to_plain_string(x).into_owned()).collect();
            std::borrow::Cow::Owned(s)
        }
        Inline::Image { alt, .. } => std::borrow::Cow::Borrowed(alt.as_str()),
        Inline::CrossReference(t) => std::borrow::Cow::Borrowed(t.as_str()),
        Inline::Citation(k) => std::borrow::Cow::Owned(format!("[{}]", k)),
    }
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

    #[test]
    fn test_table_parsed() {
        let md = "# Table Basic\n\n| Col1 | Col2 | Col3 |\n|------|------|------|\n| A | B | C |";
        let doc = build_from_markdown(md);
        let Node::Document { children, .. } = &doc else { panic!("Document"); };
        let has_table = children.iter().any(|n| matches!(n, Node::Table { .. }));
        assert!(has_table, "expected Table node in {:?}", children);
    }
}
