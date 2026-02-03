from parsers import base

def filter_errors(file):
    parser = base.get_parser(file)  # Use a generic parser to get entries
    errors = [entry for entry in parser if 'error' in str(entry).lower()]
    return errors