from .base import BaseReporter
import click

class ConsoleReporter(BaseReporter):
    def report(self, data):
        click.echo(data)