//! Detect citation syntax [@key] and create Citation AST nodes.

use crate::Node;

/// Find citation keys in text (e.g. [@smith2020] or [@key]).
pub fn find_citation_keys(text: &str) -> Vec<String> {
    let mut keys = Vec::new();
    let mut i = 0;
    let bytes = text.as_bytes();
    while i + 3 < bytes.len() {
        if bytes[i] == b'[' && bytes[i + 1] == b'@' {
            let start = i + 2;
            let mut end = start;
            while end < bytes.len() && (bytes[end].is_ascii_alphanumeric() || bytes[end] == b'-' || bytes[end] == b'_') {
                end += 1;
            }
            if end > start && end < bytes.len() && bytes[end] == b']' {
                keys.push(text[start..end].to_string());
                i = end + 1;
                continue;
            }
        }
        i += 1;
    }
    keys
}

/// Convert citation key to Citation node.
pub fn citation_node(key: String) -> Node {
    Node::Citation { key }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_citation_parsing() {
        let keys = find_citation_keys("See [@smith2020] and [@doe99].");
        assert_eq!(keys, &["smith2020", "doe99"]);
    }
}
