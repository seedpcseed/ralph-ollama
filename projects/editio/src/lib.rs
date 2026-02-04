extern crate printpdf;
use printpdf::{Color, Document, Fixed, Image};
use std::fs::File;
use std::io::prelude::*;
use std::path::Path;

pub fn markdown_to_html(markdown: &str) -> String {
    let parser = Parser::new(&markdown);
    let mut html_output = String::new();
    html::push_html(&mut html_output, parser);
    html_output
}
