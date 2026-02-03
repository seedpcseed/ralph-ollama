import click
from loglens import version

@click.group()
@click.version_option(version=version.__version__)
def cli():
    pass

@cli.command("analyze")
@click.argument('logfile', type=click.Path(exists=True))
def analyze(logfile):
    """Analyze a log file"""
    click.echo(f"Analyzing {logfile}...")