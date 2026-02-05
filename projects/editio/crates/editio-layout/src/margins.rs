//! Margins from metadata (top, bottom, left, right).

use crate::page::PageSize;

#[derive(Debug, Clone)]
pub struct Margin {
    pub top: f64,
    pub bottom: f64,
    pub left: f64,
    pub right: f64,
}

impl Default for Margin {
    fn default() -> Self {
        Margin {
            top: 72.0,
            bottom: 72.0,
            left: 72.0,
            right: 72.0,
        }
    }
}

pub fn apply_margins(page: PageSize, margin: &Margin) -> (f64, f64) {
    let (w, h) = page.dimensions_pt();
    (
        w - margin.left - margin.right,
        h - margin.top - margin.bottom,
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_margins() {
        let m = Margin::default();
        let (w, h) = apply_margins(PageSize::A4, &m);
        assert!(w > 0.0 && h > 0.0);
    }
}
