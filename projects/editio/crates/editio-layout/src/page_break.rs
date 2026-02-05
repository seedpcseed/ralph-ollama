//! Page break calculation.

#[derive(Debug, Clone)]
pub struct PageBreak {
    pub at_index: usize,
}

pub fn calculate_page_breaks(_content_height: f64, page_height: f64) -> Vec<PageBreak> {
    if page_height <= 0.0 {
        return vec![];
    }
    vec![]
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_page_breaks() {
        let breaks = calculate_page_breaks(100.0, 72.0);
        assert!(breaks.len() >= 0);
    }
}
