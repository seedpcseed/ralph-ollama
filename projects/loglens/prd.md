# PRD: LogLens - Intelligent Log Analysis Tool

## Overview
Build a command-line log parser and analysis tool that can ingest various log formats, extract insights, detect anomalies, and generate reports. This tool should handle production-scale log files (100MB+) efficiently.

## Goals
- Parse multiple common log formats (Apache, Nginx, JSON, syslog)
- Identify patterns, errors, and anomalies automatically
- Generate actionable insights and reports
- Handle large files without loading everything into memory
- Be extensible for custom log formats

## Target Users
- DevOps engineers debugging production issues
- SREs monitoring system health
- Developers analyzing application logs

## Technical Requirements

### Technology Stack
- **Language**: Python 3.9+
- **Key Libraries**: 
  - `click` for CLI interface
  - `pandas` for data analysis (optional)
  - `rich` for terminal output
  - Standard library: `re`, `json`, `csv`, `datetime`
- **Testing**: pytest with sample log files
- **Performance**: Stream processing, handle 100MB+ files

### Architecture
```
loglens/
├── cli.py              # Main CLI entry point
├── parsers/
│   ├── base.py         # Base parser interface
│   ├── apache.py       # Apache/Nginx parser
│   ├── json.py         # JSON logs parser
│   └── syslog.py       # Syslog parser
├── analyzers/
│   ├── patterns.py     # Pattern detection
│   ├── errors.py       # Error analysis
│   └── anomalies.py    # Anomaly detection
├── reporters/
│   ├── console.py      # Terminal output
│   └── html.py         # HTML report
└── tests/
    └── fixtures/       # Sample log files
```

## Features

### Phase 1: MVP (Priority 1-10)

#### 1.1 Core Infrastructure (Priority 1)
- Set up project structure
- Configure dev environment
- Add dependencies (click, rich, pytest)
- Create base classes and interfaces
- **Acceptance**: `pytest` passes, imports work

#### 1.2 Apache/Nginx Log Parser (Priority 2)
- Parse common Apache/Nginx combined log format
- Extract: timestamp, IP, method, path, status, size, referrer, user-agent
- Handle malformed lines gracefully
- Stream processing (don't load entire file)
- **Acceptance**: Parse 1000-line Apache log in <1s, correctly extract all fields

#### 1.3 Basic Statistics (Priority 3)
- Count total requests
- Count by status code (2xx, 3xx, 4xx, 5xx)
- Top 10 most requested paths
- Top 10 IP addresses
- Request rate over time (requests per minute)
- **Acceptance**: Accurate stats for test fixture, outputs to console

#### 1.4 CLI Interface (Priority 4)
- `loglens parse <file> --format apache` - Parse and show stats
- `loglens analyze <file>` - Auto-detect format and analyze
- `--output <file>` - Save report to file
- `--quiet` and `--verbose` flags
- Progress bar for large files
- **Acceptance**: All commands work, help text clear

#### 1.5 Error Detection (Priority 5)
- Identify all 4xx and 5xx responses
- Group errors by path and status code
- Show error rate over time
- Flag sudden spikes in error rate (>50% increase)
- **Acceptance**: Correctly identifies errors in test data, flags spikes

### Phase 2: Advanced Features (Priority 11-20)

#### 2.1 JSON Log Parser (Priority 11)
- Parse JSON logs (one JSON object per line)
- Auto-detect schema
- Extract nested fields
- Handle different timestamp formats
- **Acceptance**: Parse JSON logs from common frameworks (Express, FastAPI)

#### 2.2 Pattern Recognition (Priority 12)
- Identify repeated patterns (e.g., bots, scrapers)
- Detect login attempts (successful/failed)
- Find potential security issues (SQL injection attempts, XSS)
- Suspicious user agents
- **Acceptance**: Flags known attack patterns in test data

#### 2.3 Anomaly Detection (Priority 13)
- Response time anomalies (unusually slow requests)
- Traffic anomalies (unusual traffic patterns)
- Geographic anomalies (unexpected IP locations)
- Simple statistical anomaly detection (Z-score)
- **Acceptance**: Detects planted anomalies in test fixtures

#### 2.4 HTML Report Generation (Priority 14)
- Generate static HTML report with:
  - Summary statistics
  - Charts (requests over time, status codes)
  - Top tables (paths, IPs, errors)
  - Anomaly highlights
- Self-contained (embedded CSS/JS)
- **Acceptance**: Opens in browser, all sections present

#### 2.5 Time Range Filtering (Priority 15)
- `--from "2024-01-01 00:00:00"`
- `--to "2024-01-02 23:59:59"`
- Natural language: `--last 1h`, `--last 24h`, `--today`
- **Acceptance**: Correctly filters logs by time range

### Phase 3: Professional Features (Priority 21+)

#### 3.1 Syslog Parser (Priority 21)
- Parse RFC 3164 and RFC 5424 formats
- Extract facility, severity, hostname, process
- **Acceptance**: Parse standard syslog files

#### 3.2 Custom Format Support (Priority 22)
- Define custom regex patterns
- YAML config file for custom formats
- **Acceptance**: Parse custom format via config

#### 3.3 Real-time Monitoring (Priority 23)
- `loglens tail <file>` - Follow log file like `tail -f`
- Live statistics updating
- Alert on error rate threshold
- **Acceptance**: Updates stats in real-time

#### 3.4 Export Capabilities (Priority 24)
- Export to CSV
- Export to JSON
- Export to SQLite database
- **Acceptance**: All export formats valid and loadable

## Data Model

### Parsed Log Entry
```python
@dataclass
class LogEntry:
    timestamp: datetime
    level: str  # INFO, WARN, ERROR, etc.
    source_ip: str | None
    method: str | None
    path: str | None
    status_code: int | None
    response_time: float | None
    size: int | None
    user_agent: str | None
    raw: str  # Original log line
    metadata: dict  # Additional fields
```

### Analysis Result
```python
@dataclass
class AnalysisResult:
    total_requests: int
    time_range: tuple[datetime, datetime]
    status_codes: dict[int, int]
    top_paths: list[tuple[str, int]]
    top_ips: list[tuple[str, int]]
    errors: list[LogEntry]
    anomalies: list[dict]
    patterns: list[dict]
```

## Test Data

### Apache Log Fixture (100 lines)
- Normal traffic (70%)
- Errors 4xx (20%)
- Errors 5xx (5%)
- Bot traffic (5%)
- Include one anomaly: spike of 50 requests from single IP in 1 second

### JSON Log Fixture (100 lines)
- Application logs from a web service
- Mix of info, warn, error levels
- Include stack traces
- Include one security pattern (SQL injection attempt)

## Acceptance Criteria

### Verifiable Acceptance (recommended)
Use runnable criteria so Ralph can verify automatically:
- **RUN format**: In story acceptance, use `RUN "command"` - e.g. `RUN "pytest"` or `RUN "loglens --help"`
- **verify field**: In prd.json, add `"verify": "pytest"` to stories with executable checks
- Stories with verify/RUN are only marked complete when the command succeeds

### Functional Requirements
- ✅ Parse Apache logs accurately (100% field extraction)
- ✅ Parse JSON logs correctly
- ✅ Handle 100MB file in <10 seconds
- ✅ Detect errors correctly (no false positives)
- ✅ Generate readable HTML report
- ✅ CLI is intuitive and well-documented

### Quality Requirements
- ✅ Test coverage >80%
- ✅ All tests pass
- ✅ No crashes on malformed input
- ✅ Clear error messages
- ✅ Memory efficient (streaming)

### Deliverables
1. Working `loglens` command installed via pip
2. README with usage examples
3. Test fixtures and tests
4. Sample HTML report from test data
5. Documentation on adding custom formats

## Example Usage

```bash
# Basic analysis
loglens analyze access.log

# Apache format specifically
loglens parse access.log --format apache --verbose

# Generate HTML report
loglens analyze access.log --output report.html

# Filter by time
loglens analyze access.log --last 1h

# Focus on errors only
loglens analyze access.log --errors-only

# Real-time monitoring
loglens tail /var/log/nginx/access.log --alert-on-errors
```

## Success Metrics

1. **Performance**: Parse 100MB Apache log in <10 seconds
2. **Accuracy**: 100% field extraction on valid log lines
3. **Reliability**: Handle malformed input without crashing
4. **Usability**: Generate report with one command
5. **Extensibility**: Add new format in <50 lines of code

## Stretch Goals (Not in PRD)
- Machine learning anomaly detection
- Integration with monitoring systems (Prometheus, Grafana)
- Distributed log analysis (multiple files)
- Cloud storage support (S3, GCS)
- REST API for programmatic access

## Known Challenges

1. **Performance**: Streaming large files efficiently
2. **Format Variety**: Many log format variations
3. **Timestamp Parsing**: Many datetime formats in the wild
4. **Memory Management**: Keeping stats without loading all data
5. **Anomaly Detection**: Avoiding false positives

## Notes

This project intentionally has:
- **Gradual complexity** (simple parser → advanced analysis)
- **Multiple domains** (parsing, analysis, visualization)
- **Edge cases** (malformed logs, large files)
- **Performance requirements** (streaming, speed)
- **Quality gates** (tests, coverage)

Perfect for testing an autonomous development loop!
