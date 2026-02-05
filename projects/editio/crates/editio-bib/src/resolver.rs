//! Resolve citation keys against bibliography.

use crate::parser::BibEntry;
use std::collections::HashMap;

pub fn resolve_citations<'a>(keys: &[String], entries: &'a [BibEntry]) -> Result<Vec<&'a BibEntry>, Vec<String>> {
    let map: HashMap<_, _> = entries.iter().map(|e| (e.key.as_str(), e)).collect();
    let mut missing = Vec::new();
    let mut out = Vec::new();
    for k in keys {
        if let Some(e) = map.get(k.as_str()) {
            out.push(*e);
        } else {
            missing.push(k.clone());
        }
    }
    if missing.is_empty() {
        Ok(out)
    } else {
        Err(missing)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::parser::parse_bibtex;

    #[test]
    fn test_citation_resolve() {
        let bib = "@article{a1, title = {X}}";
        let entries = parse_bibtex(bib);
        let keys = vec!["a1".to_string()];
        let r = resolve_citations(&keys, &entries);
        assert!(r.is_ok());
    }
}
