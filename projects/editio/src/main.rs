use clap::{Parser, Subcommand};

#[derive(Parser)]
#[command(author, version, about, long_about = None)]
pub struct Args {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Compile a document
    Compile(CompileArgs),

    /// Check the syntax of a document
    Check(CheckArgs),
}

#[derive(clap::Args)]
pub struct CompileArgs {
    #[arg(short, long)]
    file: String,

    #[arg(short = 'o', long)]
    output: Option<String>,
}

#[derive(clap::Args)]
pub struct CheckArgs {
    #[arg(short, long)]
    file: String,
}

fn main() {
    let args = Args::parse();

    match args.command {
        Commands::Compile(args) => compile_document(args),
        Commands::Check(args) => check_document(args),
    }
}

fn compile_document(args: CompileArgs) {
    // TODO: Implement document compilation here
    unimplemented!()
}

fn check_document(args: CheckArgs) {
    // TODO: Implement syntax checking here
    unimplemented!()
}
