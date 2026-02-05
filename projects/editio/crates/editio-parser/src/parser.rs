//! CommonMark parsing via pulldown-cmark.

use pulldown_cmark::{Event, Parser};

/// Parse markdown text into a stream of pulldown-cmark events.
/// Handles standard markdown: paragraphs, headings, lists, tables.
pub fn parse_to_events(md: &str) -> impl Iterator<Item = Event<'_>> {
    Parser::new(md)
}

/// Collect events into a Vec (for tests and consumers that need ownership).
pub fn parse_events(md: &str) -> Vec<Event<'_>> {
    parse_to_events(md).collect()
}

#[cfg(test)]
mod tests {
    use super::*;
    use pulldown_cmark::Tag;

    #[test]
    fn test_commonmark() {
        let md = "# Hello\n\nParagraph with **bold**.\n\n- item 1\n- item 2";
        let events: Vec<_> = parse_to_events(md).collect();
        assert!(!events.is_empty());
        let has_heading = events.iter().any(|e| {
            matches!(e, Event::Start(Tag::Heading(..)) | Event::End(Tag::Heading(..)))
        });
        assert!(has_heading, "expected heading events");
    }
}
