use clap::{Parser, Subcommand};
use editio_ast::{DocumentMetadata, LayoutMetadata};
use editio_parser::{parse_yaml_front_matter, split_front_matter};

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

/// Heuristic: fail if markdown has likely unclosed delimiter (** or [ without ]).
fn validate_markdown(body: &str) -> Result<(), Box<dyn std::error::Error>> {
    let star2_count = body.matches("**").count();
    if star2_count % 2 != 0 {
        return Err("Invalid markdown: unclosed ** (bold)".into());
    }
    let mut bracket = 0u32;
    for c in body.chars() {
        match c {
            '[' => bracket = bracket.saturating_add(1),
            ']' => bracket = bracket.saturating_sub(1),
            _ => {}
        }
    }
    if bracket != 0 {
        return Err("Invalid markdown: unclosed [ (link or reference)".into());
    }
    Ok(())
}

fn run(cli: Cli) -> Result<(), Box<dyn std::error::Error>> {
    match cli.command {
        Commands::Compile { input, output } => {
            let md = std::fs::read_to_string(&input)
                .map_err(|e| format!("read {}: {}", input, e))?;
            let (yaml_opt, body) = split_front_matter(&md);
            let metadata = if let Some(yaml) = yaml_opt {
                let fm = parse_yaml_front_matter(yaml)
                    .map_err(|e| format!("Invalid YAML front matter: {}", e))?;
                Some(DocumentMetadata {
                    title: fm.title,
                    author: fm.author,
                    date: fm.date,
                    page_size: fm.page_size,
                    margins: fm.margins.map(|m| LayoutMetadata {
                        top: m.top,
                        bottom: m.bottom,
                        left: m.left,
                        right: m.right,
                    }),
                    font_size: fm.font_size,
                    running_header: fm.running_header,
                    footer: fm.footer,
                })
            } else {
                None
            };
            let mut ast = editio_ast::build_from_markdown(body);
            if let Some(m) = metadata {
                ast = editio_ast::with_metadata(ast, m);
            }
            editio_pdf::render_document(&ast, &output)?;
            Ok(())
        }
        Commands::Check { input } => {
            let md = std::fs::read_to_string(&input)
                .map_err(|e| format!("check {}: {}", input, e))?;
            let (yaml_opt, body) = split_front_matter(&md);
            if let Some(yaml) = yaml_opt {
                parse_yaml_front_matter(yaml).map_err(|e| format!("Invalid YAML front matter: {}", e))?;
            }
            validate_markdown(body)?;
            let _ast = editio_ast::build_from_markdown(body);
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
