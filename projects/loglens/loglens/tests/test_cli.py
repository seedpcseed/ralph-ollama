import unittest
from click.testing import CliRunner
from loglens.cli import cli

class TestCli(unittest.TestCase):
    def setUp(self):
        self.runner = CliRunner()

    def test_parse(self):
        result = self.runner.invoke(cli, ['parse'])
        assert 'Parsing logs...' in result.output
        
    def test_analyze(self):
        result = self.runner.invoke(cli, ['analyze'])
        assert 'Analyzing logs...' in result.output