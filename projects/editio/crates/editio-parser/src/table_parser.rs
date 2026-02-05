//! Table attribute parsing (YAML-style: |...|\n{label=tbl:1}).

/// Parsed table attributes.
#[derive(Debug, Default, Clone)]
pub struct TableAttributes {
    pub label: Option<String>,
    pub alignment: Option<Vec<String>>,
}

/// Parse table attribute string (e.g. `{label=tbl:1}` or `{label=tbl:1 align=left,center,right}`).
pub fn parse_table_attributes(s: &str) -> TableAttributes {
    let s = s.trim().trim_start_matches('{').trim_end_matches('}');
    let mut attrs = TableAttributes::default();
    for part in s.split_whitespace() {
        if let Some((k, v)) = part.split_once('=') {
            let v = v.trim_matches('"');
            match k {
                "label" => attrs.label = Some(v.to_string()),
                "align" | "alignment" => {
                    attrs.alignment = Some(v.split(',').map(|s| s.trim().to_string()).collect());
                }
                _ => {}
            }
        }
    }
    attrs
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_table_attributes() {
        let a = parse_table_attributes("{label=tbl:1}");
        assert_eq!(a.label.as_deref(), Some("tbl:1"));

        let b = parse_table_attributes(r#"{ label=tbl:2 align=left,center,right }"#);
        assert_eq!(b.label.as_deref(), Some("tbl:2"));
        assert_eq!(b.alignment.as_ref().map(|v| v.len()), Some(3));
        assert_eq!(b.alignment.as_ref().and_then(|v| v.first()).map(String::as_str), Some("left"));
    }
}
