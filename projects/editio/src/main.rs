use std::env;
use std::fs;
use std::path::PathBuf;

fn main() {
    let args: Vec<String> = env::args().collect();
    if args.len() < 2 {
        println!("Usage: editio 《file》");
        return;
    }

    let filename = &args[1];
    match fs::read_to_string(filename) {
        Ok(contents) => {
            // Parse the markdown file and process figures and tables
            let mut figure_count = 0;
            let mut table_count = 0;
            for line in contents.lines() {
                if line.starts_with("![") && line.ends_with(')') {
                    figure_count += 1;
                    println!("Figure 《{}》: 《{}》", figure_count, line);
                } else if line.starts_with("|") && line.ends_with('|') {
                    table_count += 1;
                    println!("Table 《{}》: 《{}》", table_count, line);
                }
            }
        },
        Err(_) => {
            eprintln!("Could not read file 《{}》", filename);
        }
    }
}
