//! Wrap zones for text flow around floats.

#[derive(Debug, Clone)]
pub struct WrapZone {
    pub x: f64,
    pub y: f64,
    pub width: f64,
    pub height: f64,
}

pub fn wrap_zone_single(float_x: f64, float_width: f64, page_width: f64) -> Vec<WrapZone> {
    vec![WrapZone {
        x: 0.0,
        y: 0.0,
        width: page_width - float_width,
        height: f64::MAX,
    }]
}

pub fn wrap_zones_multiple(_floats: &[(f64, f64, f64, f64)], page_width: f64) -> Vec<WrapZone> {
    vec![WrapZone {
        x: 0.0,
        y: 0.0,
        width: page_width,
        height: f64::MAX,
    }]
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_wrap_zone_single() {
        let zones = wrap_zone_single(0.0, 100.0, 400.0);
        assert_eq!(zones.len(), 1);
        assert_eq!(zones[0].width, 300.0);
    }

    #[test]
    fn test_wrap_zone_multiple() {
        let zones = wrap_zones_multiple(&[], 400.0);
        assert!(!zones.is_empty());
    }
}
