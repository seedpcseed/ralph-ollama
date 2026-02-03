import click
import pandas as pd
from parsers import ApacheLogParser

@click.command()
@click.argument('input_file', type=click.Path(exists=True))
def cli(input_file):
    """Simple CLI tool to parse and analyze Apache log files."""
    parser = ApacheLogParser(input_file)
    df = pd.DataFrame([astuple(entry) for entry in parser])
    click.echo(df)