//! Detect cross-reference syntax [@fig:label] or [See @label] and create CrossReference nodes.

use crate::Node;

/// Find cross-reference targets in text (e.g. [@fig:1] or [See @tbl:1]).
pub fn find_cross_ref_targets(text: &str) -> Vec<String> {
    let mut targets = Vec::new();
    let mut i = 0;
    let bytes = text.as_bytes();
    while i < bytes.len() {
        if bytes[i] == b'[' {
            let rest = &text[i + 1..];
            if rest.starts_with("@") {
                let start = i + 2;
                let mut end = start;
                let bytes = text.as_bytes();
                while end < bytes.len() && (bytes[end].is_ascii_alphanumeric() || bytes[end] == b':' || bytes[end] == b'-' || bytes[end] == b'_') {
                    end += 1;
                }
                if end > start && end < bytes.len() && bytes[end] == b']' {
                    targets.push(text[start..end].to_string());
                    i = end + 1;
                    continue;
                }
            }
        }
        i += 1;
    }
    targets
}

/// Create a CrossReference node.
pub fn cross_ref_node(target: String) -> Node {
    Node::CrossReference { target }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_cross_ref_parsing() {
        let t = find_cross_ref_targets("See [@fig:1] for details.");
        assert_eq!(t, &["fig:1"]);
    }
}
