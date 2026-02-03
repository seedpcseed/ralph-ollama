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
            println!("{}", contents);
        },
        Err(_) => {
            eprintln!("Could not read file 《{}》", filename);
        }
    }
}
