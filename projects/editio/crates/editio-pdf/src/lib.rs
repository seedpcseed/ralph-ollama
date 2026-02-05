//! Editio PDF renderer.

pub mod algorithm_renderer;
pub mod citation_renderer;
pub mod code_renderer;
pub mod cross_ref_renderer;
pub mod figure_renderer;
pub mod header_footer;
pub mod math_renderer;
pub mod table_renderer;
pub mod text_renderer;
pub mod theorem_renderer;

use printpdf::*;
use std::fs::File;
use std::io::BufWriter;

/// Create a minimal PDF document (for testing printpdf init).
pub fn init_pdf(dest: &str) -> Result<(), Box<dyn std::error::Error>> {
    let (doc, _page_idx, _layer_idx) = PdfDocument::new("editio", Mm(595.0), Mm(842.0), "Layer 1");
    doc.save(&mut BufWriter::new(File::create(dest)?))?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::env;

    #[test]
    fn test_printpdf_init() {
        let path = env::temp_dir().join("editio_test_init.pdf");
        let r = init_pdf(path.to_str().unwrap());
        assert!(r.is_ok());
    }
}
