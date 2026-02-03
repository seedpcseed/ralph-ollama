def parse(filepath):
    with open(filepath, 'r') as f:
        return [line.strip() for line in f]