import click
from rich import print  # Using Rich for better terminal output

@click.command()
def cli():
    """Welcome to Log Lens!"""
    print("[bold green]Welcome to Log Lens![/bold green]")