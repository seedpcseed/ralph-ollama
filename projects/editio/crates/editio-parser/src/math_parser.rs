//! Math placeholder parsing: inline $...$, display $$...$$, labels $$...$${label=eq:1}.

/// Inline or display math span.
#[derive(Debug, Clone, PartialEq)]
pub enum MathSpan {
    Inline { content: String },
    Display { content: String, label: Option<String> },
}

/// Find next inline math span (single $...$). Returns (content, end_index).
pub fn find_inline_math(s: &str) -> Option<(String, usize)> {
    let s = s.trim_start();
    if !s.starts_with('$') || s.len() < 2 {
        return None;
    }
    let rest = &s[1..];
    let dollar = rest.find('$')?;
    let content = rest[..dollar].to_string();
    Some((content, 1 + dollar + 1))
}

/// Find next display math span ($$...$$ or $$...$${label=eq:1}). Returns (content, label, end_index).
pub fn find_display_math(s: &str) -> Option<(String, Option<String>, usize)> {
    let s = s.trim_start();
    if !s.starts_with("$$") || s.len() < 4 {
        return None;
    }
    let rest = &s[2..];
    let close = rest.find("$$")?;
    let content = rest[..close].to_string();
    let mut end = 2 + close + 2;
    let mut label = None;
    let after = rest[close + 2..].trim_start();
    if after.starts_with('{') {
        if let Some(rbrace) = after.find('}') {
            let attrs = &after[1..rbrace];
            for part in attrs.split_whitespace() {
                if let Some((k, v)) = part.split_once('=') {
                    if k == "label" {
                        label = Some(v.trim_matches('"').to_string());
                        break;
                    }
                }
            }
            end += 1 + rbrace + 1;
        }
    }
    Some((content, label, end))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_math_parsing() {
        let (content, _) = find_inline_math("$x^2$ rest").unwrap();
        assert_eq!(content, "x^2");

        let (content, label, _) = find_display_math(r#"$$E = mc^2$${label=eq:1}"#).unwrap();
        assert_eq!(content, "E = mc^2");
        assert_eq!(label.as_deref(), Some("eq:1"));
    }
}
