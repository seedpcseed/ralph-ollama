from .base import RegexParser

SYSLOG_PATTERN = r'^<(?P<pri>\d+)>[1] (?P<timestamp>.*?) \[\*\*\] %KERNEL: (\[(?P<facility>.*?):(?P<severity>.*?)\]: )?(?P<message>.*)$'

class SyslogParser:
    def __init__(self):
        self._parser = RegexParser(SYSLOG_PATTERN)