use clap::{Parser, Subcommand};

#[derive(Parser)]
#[command(name = "editio")]
#[command(about = "Editio document compiler", long_about = None)]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Compile document to output format
    Compile {
        #[arg(short, long)]
        input: String,
        #[arg(short, long)]
        output: String,
    },
    /// Check document for errors
    Check {
        #[arg(short, long)]
        input: String,
    },
    /// Watch and recompile on changes
    Watch {
        #[arg(short, long)]
        input: String,
        #[arg(short, long)]
        output: Option<String>,
    },
    /// Initialize a new project
    Init {
        #[arg(default_value = ".")]
        path: String,
    },
    /// List or apply templates
    Template {
        #[command(subcommand)]
        sub: Option<TemplateSub>,
    },
    /// Manage plugins
    Plugin {
        #[command(subcommand)]
        sub: Option<PluginSub>,
    },
}

#[derive(Subcommand)]
enum TemplateSub {
    List,
    New { name: String },
}

#[derive(Subcommand)]
enum PluginSub {
    List,
    Install { name: String },
    Uninstall { name: String },
}

fn main() {
    let cli = Cli::parse();
    if let Err(e) = run(cli) {
        eprintln!("error: {}", e);
        std::process::exit(1);
    }
}

fn run(cli: Cli) -> Result<(), Box<dyn std::error::Error>> {
    match cli.command {
        Commands::Compile { input, output } => {
            let md = std::fs::read_to_string(&input)
                .map_err(|e| format!("read {}: {}", input, e))?;
            let _ast = editio_ast::build_from_markdown(&md);
            editio_pdf::init_pdf(&output)?;
            Ok(())
        }
        Commands::Check { input } => {
            let md = std::fs::read_to_string(&input)
                .map_err(|e| format!("check {}: {}", input, e))?;
            let _ast = editio_ast::build_from_markdown(&md);
            Ok(())
        }
        _ => Ok(()),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_check_command() {
        let md = "# Hello\n\nWorld.";
        let _ast = editio_ast::build_from_markdown(md);
    }
}
