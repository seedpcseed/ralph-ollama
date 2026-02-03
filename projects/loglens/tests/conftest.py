import pytest
from app import cli

@pytest.fixture
def runner():
    return cli.cli

@pytest.fixture
def mock_file(tmpdir):
    f = tmpdir.join("mockdata.txt")
    f.write("line1\nline2\nline3")
    return str(f)