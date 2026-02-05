//! Image node attribute parsing (YAML-style: ![caption](src){float=right width=50%}).

/// Parsed image attributes from a string like `float=right width=50%`.
#[derive(Debug, Default, Clone)]
pub struct ImageAttributes {
    pub float: Option<String>,
    pub width: Option<String>,
    pub height: Option<String>,
    pub label: Option<String>,
}

/// Parse attribute string (e.g. from `{float=right width=50%}`) into ImageAttributes.
pub fn parse_image_attributes(s: &str) -> ImageAttributes {
    let s = s.trim().trim_start_matches('{').trim_end_matches('}');
    let mut attrs = ImageAttributes::default();
    for part in s.split_whitespace() {
        if let Some((k, v)) = part.split_once('=') {
            let v = v.trim_matches('"');
            match k {
                "float" => attrs.float = Some(v.to_string()),
                "width" => attrs.width = Some(v.to_string()),
                "height" => attrs.height = Some(v.to_string()),
                "label" => attrs.label = Some(v.to_string()),
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
    fn test_image_attributes() {
        let a = parse_image_attributes("{float=right width=50%}");
        assert_eq!(a.float.as_deref(), Some("right"));
        assert_eq!(a.width.as_deref(), Some("50%"));
        assert!(a.label.is_none());

        let b = parse_image_attributes(r#"{ label=fig:1 }"#);
        assert_eq!(b.label.as_deref(), Some("fig:1"));
    }
}
