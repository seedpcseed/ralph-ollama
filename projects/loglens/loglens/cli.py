@click.command()
@click.argument('filename', type=click.Path(exists=True))
@click.option("--output", "-o", default=None, help="Output file or database name")
def analyze(filename, output):
    parser = ParserFactory().get_parser(os.path.splitext(filename)[1][1:])
    
    # ... other code ...

    reporter_type = os.path.splitext(output)[1][1:] if output else "console"
    reporter = ReporterFactory().get_reporter(reporter_type, output)