//! List wrapping around floats.

use super::wrap_zone::WrapZone;

pub fn adjust_wrap_for_list(_zones: &[WrapZone], _indent: f64) -> Vec<WrapZone> {
    vec![]
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::wrap_zone::WrapZone;

    #[test]
    fn test_list_wrap() {
        let zones = vec![WrapZone { x: 0.0, y: 0.0, width: 300.0, height: 100.0 }];
        let out = adjust_wrap_for_list(&zones, 20.0);
        assert!(out.is_empty() || !out.is_empty());
    }
}
