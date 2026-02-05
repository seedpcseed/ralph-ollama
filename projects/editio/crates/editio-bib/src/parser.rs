//! Parse BibTeX .bib files.

use std::collections::HashMap;

#[derive(Debug, Clone)]
pub struct BibEntry {
    pub key: String,
    pub entry_type: String,
    pub fields: HashMap<String, String>,
}

pub fn parse_bibtex(content: &str) -> Vec<BibEntry> {
    let mut entries = Vec::new();
    let mut i = 0;
    let bytes = content.as_bytes();
    while i < bytes.len() {
        while i < bytes.len() && bytes[i] != b'@' {
            i += 1;
        }
        if i >= bytes.len() {
            break;
        }
        i += 1;
        let start = i;
        while i < bytes.len() && (bytes[i].is_ascii_alphabetic() || bytes[i] == b'_') {
            i += 1;
        }
        let entry_type = content[start..i].trim().to_lowercase();
        while i < bytes.len() && bytes[i] != b'{' {
            i += 1;
        }
        if i >= bytes.len() {
            break;
        }
        i += 1; // skip '{'
        let key_start = i;
        while i < bytes.len() && bytes[i] != b',' && bytes[i] != b'}' {
            i += 1;
        }
        let key = content[key_start..i].trim().to_string();
        let mut fields = HashMap::new();
        if i < bytes.len() && bytes[i] == b',' {
            i += 1;
        }
        while i < bytes.len() && bytes[i] != b'}' {
            while i < bytes.len() && bytes[i].is_ascii_whitespace() {
                i += 1;
            }
            let fstart = i;
            while i < bytes.len() && bytes[i] != b'=' {
                i += 1;
            }
            let k = content[fstart..i].trim().to_lowercase();
            if i < bytes.len() {
                i += 1;
            }
            while i < bytes.len() && (bytes[i].is_ascii_whitespace() || bytes[i] == b'"' || bytes[i] == b'{') {
                i += 1;
            }
            let vstart = i;
            while i < bytes.len() && bytes[i] != b'"' && bytes[i] != b'}' && bytes[i] != b',' {
                i += 1;
            }
            let v = content[vstart..i].trim().trim_matches(',').to_string();
            if !k.is_empty() {
                fields.insert(k, v);
            }
            while i < bytes.len() && bytes[i] != b',' && bytes[i] != b'}' {
                i += 1;
            }
            if i < bytes.len() && bytes[i] == b',' {
                i += 1;
            }
        }
        if i < bytes.len() && bytes[i] == b'}' {
            i += 1;
        }
        if !key.is_empty() {
            entries.push(BibEntry { key, entry_type, fields });
        }
    }
    entries
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_bibtex_parse() {
        let bib = r#"@article{smith2020, title = {A paper}, author = {Smith}}"#;
        let entries = parse_bibtex(bib);
        assert!(!entries.is_empty());
        assert_eq!(entries[0].key, "smith2020");
    }
}
