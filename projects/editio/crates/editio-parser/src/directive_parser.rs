//! Block directive parsing (:::{theorem}...:::, :::{algorithm}...:::, :::{code}...:::).

/// Directive kind.
#[derive(Debug, Clone, PartialEq)]
pub enum DirectiveKind {
    Theorem,
    Algorithm,
    Code,
}

/// Parsed block directive: label, caption, content, and for code: language.
#[derive(Debug, Clone)]
pub struct ParsedDirective {
    pub kind: DirectiveKind,
    pub label: Option<String>,
    pub caption: Option<String>,
    pub content: String,
    pub language: Option<String>,
}

/// Extract content of first {...} in s; returns (content, end_index).
fn first_brace_content(s: &str) -> Option<(&str, usize)> {
    let start = s.find('{')?;
    let mut depth = 0;
    let bytes = s.as_bytes();
    let mut i = start;
    while i < bytes.len() {
        match bytes[i] {
            b'{' => depth += 1,
            b'}' => {
                depth -= 1;
                if depth == 0 {
                    return Some((&s[start + 1..i], i + 1));
                }
            }
            _ => {}
        }
        i += 1;
    }
    None
}

/// Detect and parse opening directive line like `:::{theorem}{label=thm:1}`.
pub fn parse_directive_opening(line: &str) -> Option<(DirectiveKind, Option<String>, Option<String>)> {
    let line = line.trim();
    if !line.starts_with(":::") {
        return None;
    }
    let rest = line[":::".len()..].trim_start();
    let (kind_str, end1) = first_brace_content(rest)?;
    let kind = match kind_str.trim().to_lowercase().as_str() {
        "theorem" => DirectiveKind::Theorem,
        "algorithm" => DirectiveKind::Algorithm,
        "code" => DirectiveKind::Code,
        _ => return None,
    };
    let rest2 = rest[end1..].trim_start();
    let mut label = None;
    let mut caption = None;
    if let Some((attrs, _)) = first_brace_content(rest2) {
        for part in attrs.split_whitespace() {
            if let Some((k, v)) = part.split_once('=') {
                let v = v.trim_matches('"').to_string();
                match k {
                    "label" => label = Some(v),
                    "caption" => caption = Some(v),
                    _ => {}
                }
            }
        }
    }
    let caption = caption.or_else(|| label.clone());
    Some((kind, label, caption))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_theorem_directive() {
        let (kind, label, _) = parse_directive_opening(":::{theorem}{label=thm:1}").unwrap();
        assert_eq!(kind, DirectiveKind::Theorem);
        assert_eq!(label.as_deref(), Some("thm:1"));
    }

    #[test]
    fn test_algorithm_directive() {
        let (kind, label, _) = parse_directive_opening(":::{algorithm}{label=alg:1}").unwrap();
        assert_eq!(kind, DirectiveKind::Algorithm);
        assert_eq!(label.as_deref(), Some("alg:1"));
    }

    #[test]
    fn test_code_directive() {
        let (kind, _, _) = parse_directive_opening(":::{code}{language=rust}").unwrap();
        assert_eq!(kind, DirectiveKind::Code);
    }
}
