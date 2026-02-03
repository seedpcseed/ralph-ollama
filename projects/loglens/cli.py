import click
from parsers import ApacheLogParser

@click.group()
def cli():
    pass

@click.command()
@click.option('--format', help='Custom date format')
@click.argument('logfile')
def apache(format, logfile):
    parser = ApacheLogParser(date_format=format)
    for entry in parser.parse(logfile):
        print(entry)

cli.add_command(apache)
if __name__ == '__main__':
    cli()