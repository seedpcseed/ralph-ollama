# Ralph-Ollama Examples

This directory contains example PRDs, test fixtures, and challenge projects for Ralph-Ollama.

## Quick Examples

### 1. Todo API (Simple)
**Complexity**: ⭐☆☆☆☆ (Beginner)  
**Time**: ~30 minutes with codellama:latest  
**Stories**: ~5

A simple REST API for todo items. Great first project to test Ralph.

```bash
# Quick start
./new.sh todo-api
cp examples/todo-api-prd.md projects/todo-api/prd.md
./convert.sh todo-api
./start.sh todo-api --monitor
```

**What it tests:**
- Basic CRUD operations
- Simple file structure
- Error handling
- Testing basics

---

### 2. LogLens (Comprehensive Challenge)
**Complexity**: ⭐⭐⭐⭐☆ (Advanced)  
**Time**: 2-4 hours with deepseek-coder:latest  
**Stories**: 14 (5 MVP + 5 Advanced + 4 Professional)

A complete log analysis tool with parsing, analysis, and reporting.

```bash
# Automated setup
cd examples
./start-loglens-test.sh

# Or manual
./new.sh loglens
cp examples/loglens-prd.md projects/loglens/prd.md
cp -r examples/test-fixtures projects/loglens/
./convert.sh loglens deepseek-coder:latest
./start.sh loglens --monitor --model deepseek-coder:latest
```

**What it tests:**
- File I/O and streaming
- Complex parsing (regex)
- Data analysis algorithms
- CLI design
- Performance optimization
- Error handling
- Testing and fixtures
- Incremental complexity

**See**: `LOGLENS_TEST_PLAN.md` for detailed testing guide

---

## Test Fixtures

### Apache Logs (`test-fixtures/apache-sample.log`)
50-line Apache combined format log with:
- Normal traffic (70%)
- Client errors 4xx (20%)
- Server errors 5xx (6%)
- Bot traffic (6%)
- Anomaly: Spike from single IP
- Security: SQL injection attempts
- Malformed lines (for error handling)

### JSON Logs (`test-fixtures/json-sample.log`)
48-line JSON log with:
- Application logs from web service
- Multiple log levels (INFO, WARN, ERROR)
- Varied events (requests, jobs, errors)
- Stack traces
- Performance data
- Security events

---

## Creating Your Own Examples

### Structure
```
examples/
├── your-project-prd.md       # The PRD
├── test-fixtures/            # Sample data
│   └── sample-input.txt
└── YOUR_PROJECT_TEST_PLAN.md # Testing guide
```

### Good Example PRD Checklist

✅ **Clear Goals**: What are we building?  
✅ **Technical Stack**: Language, frameworks specified  
✅ **Incremental Stories**: Start simple, get complex  
✅ **Acceptance Criteria**: How to verify success  
✅ **Test Data**: Sample inputs for verification  
✅ **Performance Targets**: Speed, memory requirements  
✅ **Edge Cases**: Error handling, malformed input  

### Example Template

```markdown
# PRD: Your Project Name

## Overview
One paragraph description

## Goals
- Specific goal 1
- Specific goal 2

## Technical Requirements
- Language: Python 3.9+
- Libraries: click, requests
- Testing: pytest

## Features

### Phase 1: MVP (Priority 1-10)
1. Story 1.1: Setup project structure
2. Story 1.2: Implement core feature
...

## Acceptance Criteria
- Feature X works correctly
- Tests pass
- Performance meets Y

## Test Data
Provide sample inputs
```

---

## Difficulty Levels

### ⭐ Beginner (1-2 hours)
- Todo API
- URL Shortener
- Simple Calculator CLI
- Contact Form Handler

**Characteristics:**
- 3-5 user stories
- Single file possible
- Clear inputs/outputs
- Minimal dependencies

### ⭐⭐ Intermediate (2-4 hours)
- Blog Engine
- Weather CLI
- File Converter
- Basic Web Scraper

**Characteristics:**
- 5-8 user stories
- Multiple files
- External API or file I/O
- Some complexity

### ⭐⭐⭐ Advanced (4-8 hours)
- LogLens (included)
- Code Linter
- Data Pipeline
- Microservice

**Characteristics:**
- 8-12 user stories
- Proper architecture
- Performance requirements
- Testing essential

### ⭐⭐⭐⭐ Expert (8+ hours)
- Compiler/Interpreter
- Distributed System
- ML Pipeline
- Full Application

**Characteristics:**
- 12+ user stories
- Complex algorithms
- Multiple domains
- Production-quality code

---

## Model Recommendations by Project

| Project Type | Best Model | Alternative |
|--------------|------------|-------------|
| Simple API | codellama:latest | deepseek-coder:latest |
| CLI Tool | codellama:latest | qwen2.5-coder:latest |
| Data Processing | deepseek-coder:latest | codellama:13b |
| Web App | codellama:13b | deepseek-coder:latest |
| Complex Algorithm | deepseek-coder:33b | codellama:13b |
| Full Stack | deepseek-coder:33b | qwen2.5-coder:latest |

---

## Example Results

### Todo API with codellama:latest
- Stories completed: 5/5 ✓
- Time: 27 minutes
- Circuit breaker opens: 0
- Code quality: Works, basic tests
- Learnings: 3 useful patterns

### LogLens with deepseek-coder:latest
- Stories completed: 8/14 (MVP + 3 advanced)
- Time: 3.5 hours
- Circuit breaker opens: 1 (reset and continued)
- Code quality: Works well, good structure
- Learnings: 12 patterns documented

*(Your results may vary based on model, hardware, PRD quality)*

---

## Tips for Success

1. **Start Simple**: Test with Todo API before LogLens
2. **Right Model**: Match model size to project complexity
3. **Good PRD**: Clear acceptance criteria = better results
4. **Watch Early**: Use `--monitor` to catch issues
5. **Iterate**: Refine PRD based on what works
6. **Document**: Save results in TEST_RESULTS.md

---

## Contributing Examples

Want to share your own challenging projects?

1. Create PRD following the template
2. Include test fixtures if applicable
3. Write a test plan
4. Document expected results
5. Test with at least 2 models
6. Submit as PR or share in community

**Good Challenge Projects:**
- Real-world utility
- Clear verification
- Incremental complexity
- Multiple domains
- Edge cases
- Performance requirements

---

## Resources

- **Main README**: `../README.md`
- **Quick Start**: `../QUICKSTART.md`
- **Comparison**: `../COMPARISON.md`
- **Test Plan**: `LOGLENS_TEST_PLAN.md`

---

## Quick Commands

```bash
# List all example PRDs
ls -1 examples/*.md

# Run Todo API test
./new.sh todo-test
cp examples/todo-api-prd.md projects/todo-test/prd.md
./convert.sh todo-test && ./start.sh todo-test --monitor

# Run LogLens challenge
cd examples && ./start-loglens-test.sh

# Create your own
./new.sh my-project
nano projects/my-project/prd.md
./convert.sh my-project
./start.sh my-project --monitor
```

Happy testing! 🚀
