//! YAML front matter parsing.

use std::collections::HashMap;

const DELIM: &str = "---";

/// Document metadata extracted from YAML front matter.
#[derive(Debug, Default, Clone)]
pub struct FrontMatter {
    pub title: Option<String>,
    pub author: Option<String>,
    pub date: Option<String>,
    pub page_size: Option<String>,
    pub margins: Option<MarginSpec>,
    pub font_size: Option<f64>,
    pub running_header: Option<String>,
    pub footer: Option<String>,
    /// Raw map for extra keys
    pub extra: HashMap<String, serde_yaml::Value>,
}

#[derive(Debug, Clone)]
pub struct MarginSpec {
    pub top: Option<f64>,
    pub bottom: Option<f64>,
    pub left: Option<f64>,
    pub right: Option<f64>,
}

impl Default for MarginSpec {
    fn default() -> Self {
        MarginSpec {
            top: None,
            bottom: None,
            left: None,
            right: None,
        }
    }
}

/// Split content into optional YAML front matter and body.
/// Returns (front_matter_yaml, body) if front matter is present, else (None, full_content).
pub fn split_front_matter(content: &str) -> (Option<&str>, &str) {
    let content = content.trim_start();
    if !content.starts_with(DELIM) {
        return (None, content);
    }
    let rest = content[DELIM.len()..].trim_start();
    if let Some(end) = rest.find(DELIM) {
        let yaml = rest[..end].trim();
        let body = rest[end + DELIM.len()..].trim_start();
        (Some(yaml), body)
    } else {
        (None, content)
    }
}

/// Parse YAML front matter block into FrontMatter.
/// Does not validate required fields; use validate_required() for that.
pub fn parse_yaml_front_matter(yaml: &str) -> Result<FrontMatter, serde_yaml::Error> {
    let raw: HashMap<String, serde_yaml::Value> = serde_yaml::from_str(yaml)?;
    let mut fm = FrontMatter::default();
    for (k, v) in raw {
        match k.as_str() {
            "title" => fm.title = v.as_str().map(String::from),
            "author" => fm.author = v.as_str().map(String::from),
            "date" => fm.date = v.as_str().map(String::from),
            "page-size" | "page_size" | "papersize" => fm.page_size = v.as_str().map(String::from),
            "margins" => {
                if let Ok(m) = serde_yaml::from_value::<HashMap<String, f64>>(v) {
                    fm.margins = Some(MarginSpec {
                        top: m.get("top").copied(),
                        bottom: m.get("bottom").copied(),
                        left: m.get("left").copied(),
                        right: m.get("right").copied(),
                    });
                }
            }
            "margin" => {
                let n = v.as_f64().or_else(|| {
                    v.as_str().and_then(|s| {
                        let s = s.trim();
                        let (num, unit) = s.split_at(s.find(|c: char| !c.is_numeric() && c != '.').unwrap_or(s.len()));
                        let n: f64 = num.trim().parse().ok()?;
                        let mm = match unit.trim().to_lowercase().as_str() {
                            "cm" => n * 10.0,
                            "in" => n * 25.4,
                            _ => n,
                        };
                        Some(mm)
                    })
                });
                if let Some(n) = n {
                    fm.margins = Some(MarginSpec {
                        top: Some(n),
                        bottom: Some(n),
                        left: Some(n),
                        right: Some(n),
                    });
                }
            }
            "font-size" | "font_size" => fm.font_size = v.as_f64(),
            "running_header" | "runningHeader" => fm.running_header = v.as_str().map(String::from),
            "footer" => fm.footer = v.as_str().map(String::from),
            _ => {
                fm.extra.insert(k, v);
            }
        }
    }
    Ok(fm)
}

/// Validate that required fields are present. Returns list of missing keys.
pub fn validate_required(fm: &FrontMatter, required: &[&str]) -> Vec<&'static str> {
    let mut missing = Vec::new();
    for &key in required {
        match key {
            "title" if fm.title.is_none() => missing.push("title"),
            "author" if fm.author.is_none() => missing.push("author"),
            "date" if fm.date.is_none() => missing.push("date"),
            _ => {}
        }
    }
    missing
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_yaml_front_matter() {
        let yaml = r#"
title: My Doc
author: Alice
date: 2025-02-05
page-size: A4
font-size: 12
"#;
        let fm = parse_yaml_front_matter(yaml).unwrap();
        assert_eq!(fm.title.as_deref(), Some("My Doc"));
        assert_eq!(fm.author.as_deref(), Some("Alice"));
        assert_eq!(fm.date.as_deref(), Some("2025-02-05"));
        assert_eq!(fm.page_size.as_deref(), Some("A4"));
        assert_eq!(fm.font_size, Some(12.0));

        let (yaml_opt, body) = split_front_matter("---\ntitle: X\n---\n# Hello");
        assert!(yaml_opt.is_some());
        let fm2 = parse_yaml_front_matter(yaml_opt.unwrap()).unwrap();
        assert_eq!(fm2.title.as_deref(), Some("X"));
        assert_eq!(body, "# Hello");
    }
}
