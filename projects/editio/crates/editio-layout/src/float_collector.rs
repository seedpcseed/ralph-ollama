//! Collect floating figures from AST.

use editio_ast::Node;

#[derive(Debug, Clone)]
pub struct Float {
    pub position: String,
    pub width: f64,
    pub height: f64,
    pub label: Option<String>,
}

pub fn collect_floats(node: &Node) -> Vec<Float> {
    let mut out = Vec::new();
    fn go(n: &Node, out: &mut Vec<Float>) {
        if let Node::Image { attrs, .. } = n {
            if attrs.float.is_some() {
                out.push(Float {
                    position: attrs.float.clone().unwrap_or_else(|| "left".into()),
                    width: 0.0,
                    height: 0.0,
                    label: attrs.label.clone(),
                });
            }
        }
        if let Node::Document { children, .. } = n {
            for c in children {
                go(c, out);
            }
        }
    }
    go(node, &mut out);
    out
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_float_collection() {
        let doc = Node::Document {
            children: vec![],
            metadata: None,
        };
        let floats = collect_floats(&doc);
        assert!(floats.is_empty());
    }
}
