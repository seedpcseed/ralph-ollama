from click.testing import CliRunner
from cli import cli
import pytest

runner = CliRunner()

def test_parse():
    result = runner.invoke(cli, ['parse', '--file', './tests/logs.txt', '--format', 'apache'])
    assert result.exit_code == 0  # Successful exit code
    
def test_analyze():
    result = runner.invoke(cli, ['analyze', '--format', 'errors'])
    assert result.exit_code == 0  # Successful exit code