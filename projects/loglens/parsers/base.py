import re

class RegexParser:
    def __init__(self, pattern):
        self.pattern = re.compile(pattern)

    def parse_line(self, line):
        match = self.pattern.match(line)
        if match:
            return match.groupdict()