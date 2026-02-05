//! Label registry: associate labels with nodes (Figure, Table, Equation, Theorem, Algorithm).

use crate::Node;
use std::collections::HashMap;

#[derive(Debug, Clone)]
pub struct LabelMeta {
    pub label_type: LabelType,
    pub sequential: u32,
}

#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub enum LabelType {
    Figure,
    Table,
    Equation,
    Theorem,
    Algorithm,
}

/// Registry mapping label string -> (type, sequential number).
#[derive(Debug, Default)]
pub struct LabelRegistry {
    map: HashMap<String, LabelMeta>,
    counters: HashMap<LabelType, u32>,
}

impl LabelRegistry {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn register(&mut self, label: String, label_type: LabelType) {
        let seq = self.counters.entry(label_type.clone()).or_insert(0);
        *seq += 1;
        self.map.insert(
            label.clone(),
            LabelMeta {
                label_type: label_type.clone(),
                sequential: *seq,
            },
        );
    }

    pub fn get(&self, label: &str) -> Option<&LabelMeta> {
        self.map.get(label)
    }

    pub fn associate_labels_from_ast(&mut self, node: &Node) {
        match node {
            Node::Image { attrs, .. } => {
                if let Some(ref l) = attrs.label {
                    self.register(l.clone(), LabelType::Figure);
                }
            }
            Node::Table { attrs, .. } => {
                if let Some(ref l) = attrs.label {
                    self.register(l.clone(), LabelType::Table);
                }
            }
            Node::Math { label, .. } => {
                if let Some(ref l) = label {
                    self.register(l.clone(), LabelType::Equation);
                }
            }
            Node::Theorem { label, .. } => {
                if let Some(ref l) = label {
                    self.register(l.clone(), LabelType::Theorem);
                }
            }
            Node::Algorithm { label, .. } => {
                if let Some(ref l) = label {
                    self.register(l.clone(), LabelType::Algorithm);
                }
            }
            Node::Document { children, .. } => {
                for c in children {
                    self.associate_labels_from_ast(c);
                }
            }
            Node::Theorem { content, .. } | Node::Algorithm { content, .. } => {
                for c in content {
                    self.associate_labels_from_ast(c);
                }
            }
            Node::Paragraph { .. } | Node::Heading { .. } | Node::Image { .. } | Node::Table { .. }
            | Node::Math { .. } | Node::Citation { .. } | Node::CrossReference { .. } | Node::CodeBlock { .. }
            | Node::List { .. } | Node::BlockQuote { .. } => {}
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_label_tracking() {
        let mut reg = LabelRegistry::new();
        reg.register("fig:1".into(), LabelType::Figure);
        reg.register("tbl:1".into(), LabelType::Table);
        assert_eq!(reg.get("fig:1").map(|m| m.sequential), Some(1));
        assert_eq!(reg.get("tbl:1").map(|m| m.sequential), Some(1));
    }
}
