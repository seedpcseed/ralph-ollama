import click
from loglens import parsers, analyzers  # Assuming we have a Parser and Analyzer classes

@click.group()
def loglens():
    pass

@loglens.command()
@click.argument('file')
def parse(file):
    parser = parsers.ParserFactory().get_parser(file)  # This is a factory method that returns the appropriate parser based on the file type
    parsed_data = parser.parse(file)
    
    print(parsed_data)

@loglens.command()
@click.argument('file')
def analyze(file):
    analyzer = analyzers.AnalyzerFactory().get_analyzer(file)  # This is a factory method that returns the appropriate analyzer based on the file type
    analysis = analyzer.analyze(file)
    
    print(analysis)