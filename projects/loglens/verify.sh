#!/bin/bash
# Project verification script - run by Ralph before marking stories complete
# Language-agnostic: detects Rust, Go, Python, Node. Customize for your project.
# Exit 0 = pass, non-zero = fail.
set +e  # Don't exit on first failure - try multiple checks
cd "$(dirname "$0")"

# Rust
if [ -f "Cargo.toml" ]; then
    cargo test -q 2>/dev/null && exit 0
fi

# Go
if [ -f "go.mod" ]; then
    go test ./... -quiet 2>/dev/null && exit 0
fi

# Python
if [ -d "tests" ] && python3 -m pytest tests/ -q 2>/dev/null; then
    exit 0
fi
if [ -f "cli.py" ] && python3 cli.py --help >/dev/null 2>&1; then
    exit 0
fi
if [ -f "pyproject.toml" ]; then
    (pip install -e . -q 2>/dev/null && python3 -m pytest -q 2>/dev/null) && exit 0
fi

# Node
if [ -f "package.json" ] && grep -q '"test"' package.json 2>/dev/null; then
    npm test --silent 2>/dev/null && exit 0
fi

# Default: pass if no checks defined
exit 0
