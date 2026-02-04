use clap::Parser;

#[derive(Parser)]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Parser)]
enum Commands {
    Compile { file: String, #[arg(short, long)] output: String },
    Check { file: String },
}

fn main() {
    let cli = Cli::parse();
    match cli.command {
        Commands::Compile { file, output } => {
            println!("Compiling {} to {}", file, output);
        }
        Commands::Check { file } => {
            println!("Checking {}", file);
        }
    }
}
```