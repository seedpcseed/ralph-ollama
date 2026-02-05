//! Page dimensions from metadata (letter, A4, etc.).

#[derive(Debug, Clone, Copy, PartialEq)]
pub enum PageSize {
    Letter,
    A4,
    A5,
}

impl PageSize {
    /// Width and height in points (1/72 inch).
    pub fn dimensions_pt(self) -> (f64, f64) {
        match self {
            PageSize::Letter => (612.0, 792.0),
            PageSize::A4 => (595.28, 841.89),
            PageSize::A5 => (419.53, 595.28),
        }
    }
}

pub fn parse_page_size(s: &str) -> Option<PageSize> {
    match s.to_lowercase().as_str() {
        "letter" => Some(PageSize::Letter),
        "a4" => Some(PageSize::A4),
        "a5" => Some(PageSize::A5),
        _ => None,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_page_dimensions() {
        let (w, h) = PageSize::A4.dimensions_pt();
        assert!(w > 0.0 && h > 0.0);
        assert_eq!(parse_page_size("A4"), Some(PageSize::A4));
    }
}
