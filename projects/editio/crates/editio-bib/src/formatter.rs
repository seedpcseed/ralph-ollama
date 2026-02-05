//! Format citations (Author-Year, Numeric).

use crate::parser::BibEntry;

pub fn format_author_year(entry: &BibEntry) -> String {
    let author = entry.fields.get("author").cloned().unwrap_or_else(|| "?".into());
    let year = entry.fields.get("year").cloned().unwrap_or_else(|| "?".into());
    format!("({}, {})", author, year)
}

pub fn format_numeric(_entry: &BibEntry, seq: u32) -> String {
    format!("[{}]", seq)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::parser::BibEntry;
    use std::collections::HashMap;

    #[test]
    fn test_format_author_year() {
        let mut fields = HashMap::new();
        fields.insert("author".into(), "Smith".into());
        fields.insert("year".into(), "2020".into());
        let e = BibEntry { key: "s".into(), entry_type: "article".into(), fields };
        assert!(format_author_year(&e).contains("Smith"));
    }

    #[test]
    fn test_format_numeric() {
        let e = BibEntry { key: "x".into(), entry_type: "article".into(), fields: HashMap::new() };
        assert_eq!(format_numeric(&e, 1), "[1]");
    }
}
