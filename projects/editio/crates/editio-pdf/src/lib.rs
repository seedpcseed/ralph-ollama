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

use editio_ast::{Inline, LabelRegistry, LabelType, Node};
use printpdf::*;
use std::fs::File;
use std::io::BufWriter;
use std::iter::FromIterator;

/// Create a minimal PDF document (for testing printpdf init).
pub fn init_pdf(dest: &str) -> Result<(), Box<dyn std::error::Error>> {
    let (doc, _page_idx, _layer_idx) = PdfDocument::new("editio", Mm(595.0), Mm(842.0), "Layer 1");
    doc.save(&mut BufWriter::new(File::create(dest)?))?;
    Ok(())
}

/// Resolve cross-reference target to display text.
fn resolve_cross_ref(reg: &LabelRegistry, target: &str) -> String {
    reg.get(target).map(|m| match m.label_type {
        LabelType::Figure => format!("Figure {}", m.sequential),
        LabelType::Table => format!("Table {}", m.sequential),
        LabelType::Equation => format!("Equation {}", m.sequential),
        LabelType::Theorem => format!("Theorem {}", m.sequential),
        LabelType::Algorithm => format!("Algorithm {}", m.sequential),
    }).unwrap_or_else(|| format!("[{}]", target))
}

/// Flatten inline content to plain string (for builtin font; WinAnsiEncoding).
fn inlines_to_string(inlines: &[Inline], reg: &LabelRegistry) -> String {
    let mut s = String::new();
    for i in inlines {
        match i {
            Inline::Text(t) => s.push_str(t),
            Inline::Code(t) => s.push_str(t),
            Inline::Link { text, .. } => s.push_str(text),
            Inline::Strong(inner) | Inline::Emph(inner) => s.push_str(&inlines_to_string(inner, reg)),
            Inline::Image { alt, .. } => s.push_str(alt),
            Inline::CrossReference(t) => s.push_str(&resolve_cross_ref(reg, t)),
            Inline::Citation(k) => s.push_str(&format!("[{}]", k)),
        }
    }
    s
}

/// Character width in mm per character at given point size (scale factor at 12pt).
fn char_width(pt: f64, scale_12pt: f64) -> f64 {
    (pt / 12.0) * scale_12pt
}

/// Font/style for inline segment: (font, char_width_scale at 12pt).
fn inline_font_and_cw<'a>(
    bold: bool,
    italic: bool,
    font: &'a IndirectFontRef,
    font_bold: &'a IndirectFontRef,
    font_italic: &'a IndirectFontRef,
    font_bold_italic: &'a IndirectFontRef,
    _font_code: &'a IndirectFontRef,
    pt: f64,
) -> (&'a IndirectFontRef, f64) {
    let (scale, f) = match (bold, italic) {
        (false, false) => (1.75, font),
        (true, false) => (2.2, font_bold),
        (false, true) => (1.9, font_italic),
        (true, true) => (2.1, font_bold_italic),
    };
    (f, char_width(pt, scale))
}

/// Draw paragraph inlines with bold/italic/code/link styling; recursive for nested Strong/Emph.
/// Returns final x and whether anything was drawn.
fn draw_inlines(
    inlines: &[Inline],
    reg: &LabelRegistry,
    pt: f64,
    x0: f64,
    y: f64,
    layer: &PdfLayerReference,
    font: &IndirectFontRef,
    font_bold: &IndirectFontRef,
    font_italic: &IndirectFontRef,
    font_bold_italic: &IndirectFontRef,
    font_code: &IndirectFontRef,
    page_w: f64,
    parent_bold: bool,
    parent_italic: bool,
) -> (f64, bool) {
    let mut x = x0;
    let mut drawn = false;

    for i in inlines {
        if x >= page_w - 20.0 {
            break;
        }
        match i {
            Inline::Text(t) => {
                if t.is_empty() {
                    continue;
                }
                let (f, cw) = inline_font_and_cw(
                    parent_bold, parent_italic,
                    font, font_bold, font_italic, font_bold_italic, font_code, pt,
                );
                layer.use_text(t, pt, Mm(x), Mm(y), f);
                x += t.len() as f64 * cw;
                drawn = true;
            }
            Inline::Code(t) => {
                if t.is_empty() {
                    continue;
                }
                let cw = char_width(pt, 1.5);
                layer.use_text(t, pt, Mm(x), Mm(y), font_code);
                x += t.len() as f64 * cw;
                drawn = true;
            }
            Inline::Link { text, url: _ } => {
                if text.is_empty() {
                    continue;
                }
                let cw = char_width(pt, 1.75);
                layer.set_fill_color(Color::Rgb(Rgb::new(0.0, 0.0, 0.75, None)));
                layer.use_text(text, pt, Mm(x), Mm(y), font);
                layer.set_fill_color(Color::Greyscale(Greyscale::new(0.0, None)));
                x += text.len() as f64 * cw;
                drawn = true;
            }
            Inline::Strong(inner) => {
                let (sub_x, sub_drawn) = draw_inlines(
                    inner, reg, pt, x, y, layer,
                    font, font_bold, font_italic, font_bold_italic, font_code,
                    page_w, true, parent_italic,
                );
                x = sub_x;
                drawn = drawn || sub_drawn;
            }
            Inline::Emph(inner) => {
                let (sub_x, sub_drawn) = draw_inlines(
                    inner, reg, pt, x, y, layer,
                    font, font_bold, font_italic, font_bold_italic, font_code,
                    page_w, parent_bold, true,
                );
                x = sub_x;
                drawn = drawn || sub_drawn;
            }
            Inline::Image { alt, .. } => {
                if !alt.is_empty() {
                    let cw = char_width(pt, 1.75);
                    layer.use_text(alt, pt, Mm(x), Mm(y), font);
                    x += alt.len() as f64 * cw;
                    drawn = true;
                }
            }
            Inline::CrossReference(t) => {
                let s = resolve_cross_ref(reg, t);
                if !s.is_empty() {
                    let cw = char_width(pt, 1.75);
                    layer.use_text(&s, pt, Mm(x), Mm(y), font);
                    x += s.len() as f64 * cw;
                    drawn = true;
                }
            }
            Inline::Citation(k) => {
                let s = format!("[{}]", k);
                let cw = char_width(pt, 1.75);
                layer.use_text(&s, pt, Mm(x), Mm(y), font);
                x += s.len() as f64 * cw;
                drawn = true;
            }
        }
    }
    (x, drawn)
}

/// Default A4 dimensions in mm.
fn default_page_size() -> (f64, f64) {
    (595.0, 842.0)
}

/// Resolve page size from metadata (e.g. "a4", "letter").
fn page_size_from_metadata(meta: &Option<editio_ast::DocumentMetadata>) -> (f64, f64) {
    let s = match meta {
        Some(m) => m.page_size.as_deref(),
        None => None,
    };
    match s.map(str::to_lowercase).as_deref() {
        Some("a4") => (595.0, 842.0),
        Some("letter") => (612.0, 792.0),
        _ => default_page_size(),
    }
}

/// Margin from metadata (mm), or default 50.
fn margin_from_metadata(meta: &Option<editio_ast::DocumentMetadata>) -> f64 {
    let m = match meta {
        Some(x) => x.margins.as_ref(),
        None => return 50.0,
    };
    let m = match m {
        Some(x) => x,
        None => return 50.0,
    };
    m.left.or(m.right).or(m.top).unwrap_or(50.0)
}

/// Render AST to PDF (basic: one page, paragraphs and headings as text).
pub fn render_document(ast: &Node, dest: &str) -> Result<(), Box<dyn std::error::Error>> {
    let (doc_children, metadata) = match ast {
        Node::Document { children, metadata } => (children, metadata),
        _ => return Ok(()),
    };

    let mut label_reg = LabelRegistry::new();
    label_reg.associate_labels_from_ast(ast);

    let (w, h) = page_size_from_metadata(metadata);
    let page_w = Mm(w);
    let page_h = Mm(h);
    let (doc, page_idx, layer_idx) = PdfDocument::new("editio", page_w, page_h, "Layer 1");
    let font = doc.add_builtin_font(BuiltinFont::Helvetica)?;
    let font_bold = doc.add_builtin_font(BuiltinFont::HelveticaBold)?;
    let font_italic = doc.add_builtin_font(BuiltinFont::HelveticaOblique)?;
    let font_bold_italic = doc.add_builtin_font(BuiltinFont::HelveticaBoldOblique)?;
    let font_code = doc.add_builtin_font(BuiltinFont::Courier)?;
    let layer = doc.get_page(page_idx).get_layer(layer_idx);

    let margin = margin_from_metadata(metadata);
    let mut y = page_h.0 - margin;
    let line_height = 14.0;
    let heading_sizes = [24.0, 20.0, 18.0, 16.0, 14.0, 14.0];

    let (page_num, total_pages) = (1, 1);
    if let Some(meta) = metadata {
        if let Some(ref h) = meta.running_header {
            let h = h.replace("%p", &page_num.to_string()).replace("%P", &total_pages.to_string());
            layer.use_text(&h, 10.0, Mm(margin), Mm(page_h.0 - 15.0), &font);
        }
        if let Some(ref f) = meta.footer {
            let f = f.replace("%p", &page_num.to_string()).replace("%P", &total_pages.to_string());
            layer.use_text(&f, 10.0, Mm(margin), Mm(20.0), &font);
        }
    }

    for node in doc_children {
        match node {
            Node::Heading { level, content } => {
                let size = heading_sizes.get((*level as usize).saturating_sub(1)).copied().unwrap_or(14.0);
                let text = inlines_to_string(content, &label_reg);
                if !text.is_empty() {
                    layer.use_text(&text, size, Mm(margin), Mm(y), &font);
                    y -= size * 1.2;
                }
            }
            Node::Paragraph { content } => {
                let (_, drawn) = draw_inlines(
                    content,
                    &label_reg,
                    12.0,
                    margin,
                    y,
                    &layer,
                    &font,
                    &font_bold,
                    &font_italic,
                    &font_bold_italic,
                    &font_code,
                    page_w.0,
                    false,
                    false,
                );
                if drawn {
                    y -= line_height;
                }
            }
            Node::List { ordered, items } => {
                for (idx, item) in items.iter().enumerate() {
                    let prefix = if *ordered {
                        format!("{}. ", idx + 1)
                    } else {
                        "- ".to_string()
                    };
                    let text = prefix + &inlines_to_string(item, &label_reg);
                    if !text.trim().is_empty() {
                        layer.use_text(&text, 12.0, Mm(margin), Mm(y), &font);
                        y -= line_height;
                    }
                }
            }
            Node::BlockQuote { content } => {
                for child in content {
                    match child {
                        Node::Paragraph { content: inlines } => {
                            let text = "> ".to_string() + &inlines_to_string(inlines, &label_reg);
                            if !text.trim().is_empty() {
                                layer.use_text(&text, 12.0, Mm(margin + 10.0), Mm(y), &font);
                                y -= line_height;
                            }
                        }
                        _ => {}
                    }
                }
            }
            Node::Table { header, rows, .. } => {
                let cell_w = 80.0_f64;
                let x_start = margin;
                let n_cols = header.len().max(rows.iter().map(|r| r.len()).max().unwrap_or(0));
                let n_rows = 1 + rows.len();
                let table_top = y;
                let table_h = line_height * n_rows as f64;
                let table_w = n_cols as f64 * cell_w;
                layer.set_outline_color(Color::Greyscale(Greyscale::new(0.3, None)));
                layer.set_outline_thickness(0.5);
                for row_i in 0..=n_rows {
                    let yy = table_top - row_i as f64 * line_height;
                    let line = Line::from_iter(vec![
                        (Point::new(Mm(x_start), Mm(yy)), false),
                        (Point::new(Mm(x_start + table_w), Mm(yy)), false),
                    ]);
                    let mut l = line;
                    l.set_stroke(true);
                    l.set_fill(false);
                    l.set_closed(false);
                    layer.add_shape(l);
                }
                for col_i in 0..=n_cols {
                    let xx = x_start + col_i as f64 * cell_w;
                    let line = Line::from_iter(vec![
                        (Point::new(Mm(xx), Mm(table_top)), false),
                        (Point::new(Mm(xx), Mm(table_top - table_h)), false),
                    ]);
                    let mut l = line;
                    l.set_stroke(true);
                    l.set_fill(false);
                    l.set_closed(false);
                    layer.add_shape(l);
                }
                for (col, cell) in header.iter().enumerate() {
                    let text = inlines_to_string(cell, &label_reg);
                    if !text.is_empty() {
                        layer.use_text(&text, 12.0, Mm(x_start + col as f64 * cell_w + 4.0), Mm(y - 4.0), &font);
                    }
                }
                y -= line_height;
                for row in rows.iter() {
                    for (col, cell) in row.iter().enumerate() {
                        let text = inlines_to_string(cell, &label_reg);
                        if !text.is_empty() {
                            layer.use_text(&text, 12.0, Mm(x_start + col as f64 * cell_w + 4.0), Mm(y - 4.0), &font);
                        }
                    }
                    y -= line_height;
                }
            }
            Node::CrossReference { target } => {
                let text = resolve_cross_ref(&label_reg, target);
                layer.use_text(&text, 12.0, Mm(margin), Mm(y), &font);
                y -= line_height;
            }
            Node::Math { content, .. } => {
                if !content.is_empty() {
                    layer.use_text(content, 12.0, Mm(margin), Mm(y), &font);
                    y -= line_height;
                }
            }
            Node::Theorem { caption, content, .. } => {
                if let Some(c) = caption {
                    layer.use_text(&format!("Theorem. {}", c), 12.0, Mm(margin), Mm(y), &font);
                    y -= line_height;
                }
                for child in content {
                    if let Node::Paragraph { content: inlines } = child {
                        let text = inlines_to_string(inlines, &label_reg);
                        if !text.is_empty() {
                            layer.use_text(&text, 12.0, Mm(margin + 10.0), Mm(y), &font);
                            y -= line_height;
                        }
                    }
                }
            }
            Node::Algorithm { caption, content, .. } => {
                if let Some(c) = caption {
                    layer.use_text(&format!("Algorithm. {}", c), 12.0, Mm(margin), Mm(y), &font);
                    y -= line_height;
                }
                for child in content {
                    if let Node::Paragraph { content: inlines } = child {
                        let text = inlines_to_string(inlines, &label_reg);
                        if !text.is_empty() {
                            layer.use_text(&text, 12.0, Mm(margin + 10.0), Mm(y), &font);
                            y -= line_height;
                        }
                    }
                }
            }
            Node::Citation { key } => {
                layer.use_text(&format!("[{}]", key), 12.0, Mm(margin), Mm(y), &font);
                y -= line_height;
            }
            Node::CodeBlock { content, .. } => {
                if !content.is_empty() {
                    layer.use_text(content, 11.0, Mm(margin), Mm(y), &font);
                    y -= line_height * (content.lines().count().max(1) as f64);
                }
            }
            _ => {}
        }
    }

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
