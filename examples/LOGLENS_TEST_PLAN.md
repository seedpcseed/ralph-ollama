# LogLens Test Plan for Ralph-Ollama

This document outlines how to test Ralph-Ollama using the LogLens project as a comprehensive challenge.

## Why LogLens Tests Ralph Well

1. **Incremental Complexity**: 14 user stories ranging from simple (setup) to complex (anomaly detection)
2. **Multiple Domains**: File I/O, parsing, algorithms, CLI, reporting
3. **Performance Requirements**: Must handle large files efficiently
4. **Error Handling**: Must gracefully handle malformed input
5. **Testing Required**: Needs actual test fixtures and verification
6. **Quality Gates**: Code coverage, performance benchmarks

## Test Setup

### 1. Initialize the Project

```bash
cd ralph-ollama

# Create the LogLens project
./new.sh loglens

# Copy the PRD
cp examples/loglens-prd.md projects/loglens/prd.md

# Copy test fixtures
mkdir -p projects/loglens/test-fixtures
cp examples/test-fixtures/* projects/loglens/test-fixtures/

# Convert PRD to JSON
./convert.sh loglens deepseek-coder:latest
```

### 2. Review Generated Tasks

```bash
# Check that stories were properly generated
jq '.userStories[] | {id, priority, story}' projects/loglens/prd.json

# Should have ~14 stories prioritized 1-24
# Story 1.1: Core infrastructure (priority 1)
# Story 1.2: Apache parser (priority 2)
# ... etc
```

### 3. Start Ralph Loop

```bash
# Start with monitoring
./start.sh loglens --monitor --model deepseek-coder:latest

# Or for faster iteration with smaller model
./start.sh loglens --monitor --model codellama:13b

# Or best quality (if you have 32GB+ RAM)
./start.sh loglens --monitor --model deepseek-coder:33b
```

## What to Watch For

### Success Indicators

✅ **Story Completion**: Each story marked `passes: true` in prd.json  
✅ **Learnings**: Progress.txt grows with insights  
✅ **Git Commits**: Automatic commits after each story (if in git repo)  
✅ **No Circuit Breaker**: Stays in CLOSED state  
✅ **Code Actually Works**: Can run the generated code  

### Challenge Points (Expected)

These are areas where Ralph might struggle - document how it handles them:

#### Challenge 1: Project Structure (Story 1.1)
- **Expected**: Should create proper Python package structure
- **Watch For**: Does it understand pytest? pip dependencies? setup.py?
- **Success**: `pytest` command works, imports succeed

#### Challenge 2: Streaming Parser (Story 1.2)
- **Expected**: Must parse without loading entire file
- **Watch For**: Does it use generators? Open file with context manager?
- **Success**: Parses 100MB file without excessive memory

#### Challenge 3: Regex Complexity (Story 1.2)
- **Expected**: Apache log format is complex regex
- **Watch For**: Does it get the regex right? Test edge cases?
- **Success**: 100% field extraction on valid lines

#### Challenge 4: CLI Design (Story 1.4)
- **Expected**: Use Click properly with subcommands
- **Watch For**: Help text, error handling, argument validation
- **Success**: `loglens --help` is clear, commands work

#### Challenge 5: Statistics Without Full Load (Story 1.3)
- **Expected**: Incremental stats calculation
- **Watch For**: Streaming aggregation vs loading all into memory
- **Success**: Memory stays constant regardless of file size

#### Challenge 6: Anomaly Detection (Story 2.3)
- **Expected**: This is algorithmically complex
- **Watch For**: Does it understand statistical methods? Z-scores?
- **Success**: Detects the planted anomaly in test fixture

#### Challenge 7: HTML Generation (Story 2.4)
- **Expected**: Generate self-contained HTML
- **Watch For**: Proper HTML structure, embedded CSS, no external deps
- **Success**: Opens in browser, all sections render

## Verification Tests

After Ralph completes each phase, manually verify:

### Phase 1 Verification (MVP)

```bash
cd projects/loglens

# Test 1: Installation works
pip install -e .
loglens --version

# Test 2: Parse Apache logs
loglens parse test-fixtures/apache-sample.log --format apache

# Expected output:
# - Total requests: ~47 (excluding malformed)
# - 2xx responses: ~30
# - 4xx responses: ~10
# - 5xx responses: ~3
# - Top paths, IPs shown

# Test 3: Error detection
loglens analyze test-fixtures/apache-sample.log --errors-only

# Expected:
# - Should list all 4xx and 5xx responses
# - Should identify error rate

# Test 4: CLI help
loglens --help
loglens parse --help

# Expected:
# - Clear, helpful output
# - All options documented
```

### Phase 2 Verification (Advanced)

```bash
# Test 5: JSON parsing
loglens parse test-fixtures/json-sample.log --format json

# Expected:
# - Parse nested JSON objects
# - Extract timestamp, level, message
# - Handle various field types

# Test 6: Pattern detection
loglens analyze test-fixtures/apache-sample.log --patterns

# Expected:
# - Detect bot traffic (Googlebot, Bingbot)
# - Flag SQL injection attempts
# - Identify suspicious IPs

# Test 7: Anomaly detection
loglens analyze test-fixtures/apache-sample.log --anomalies

# Expected:
# - Flag spike from 192.168.1.250 (7 requests in 1 second)
# - Potentially flag security issues

# Test 8: HTML report
loglens analyze test-fixtures/apache-sample.log --output report.html

# Then open in browser:
open report.html  # macOS
xdg-open report.html  # Linux

# Expected:
# - Professional-looking report
# - Summary stats
# - Charts/graphs (if implemented)
# - Error highlights
```

### Performance Testing

```bash
# Generate large test file
python -c "
with open('test-fixtures/apache-sample.log', 'r') as f:
    lines = f.readlines()
with open('large-test.log', 'w') as out:
    for i in range(2000):  # ~100K lines
        for line in lines:
            out.write(line)
"

# Time the parsing
time loglens analyze large-test.log

# Expected:
# - Complete in <10 seconds
# - Memory usage stays reasonable
# - No crashes
```

## Measuring Ralph's Success

### Quantitative Metrics

| Metric | Target | How to Check |
|--------|--------|-------------|
| Stories Completed | 5+ (MVP) | `jq '[.userStories[] | select(.passes==true)] | length' prd.json` |
| Circuit Breaker Opens | 0-2 | Check `projects/loglens/.circuit_breaker` |
| Code Quality | Works | Manual testing |
| Performance | <10s for 100K lines | `time loglens analyze large-test.log` |
| Error Handling | No crashes | Try malformed inputs |

### Qualitative Assessment

**Excellent (A+)**: 
- Completes 10+ stories
- Code works perfectly
- Proper tests included
- Performance meets specs
- Clean, maintainable code

**Good (B+)**:
- Completes 5-9 stories
- Core functionality works
- Minor bugs present
- Performance acceptable
- Code is understandable

**Acceptable (C+)**:
- Completes 3-5 stories
- Basic parsing works
- Some bugs/missing features
- Performance issues
- Code is rough

**Poor (D)**:
- Completes <3 stories
- Frequent failures
- Circuit breaker opens often
- Code doesn't run

## Common Issues & Solutions

### Issue 1: Ralph Gets Stuck on Story 1.2 (Regex)
**Symptom**: Loops multiple times without marking complete  
**Diagnosis**: Complex regex is hard for LLMs  
**Solution**: 
```bash
# Manually simplify the story in prd.json
# Break regex into sub-steps
# Or try a larger model
./start.sh loglens --model deepseek-coder:33b
```

### Issue 2: Circuit Breaker Opens Early
**Symptom**: Stops after 2-3 stories  
**Diagnosis**: Model struggling with task complexity  
**Solution**:
```bash
# Check what's failing
tail -100 projects/loglens/logs/loop_*.log

# Try different model
./start.sh loglens --reset --model codellama:13b

# Or simplify PRD
nano projects/loglens/prd.json
# Remove complex stories, keep simple ones
```

### Issue 3: Code Doesn't Actually Work
**Symptom**: Story marked complete but code has bugs  
**Diagnosis**: Response analyzer accepting too easily  
**Solution**:
```bash
# Manually test
cd projects/loglens
python -m pytest  # Do tests exist and pass?
loglens --help    # Does CLI work?

# If broken, mark story incomplete
jq '.userStories[X].passes = false' prd.json > tmp && mv tmp prd.json

# Resume
./start.sh loglens --monitor
```

### Issue 4: Model Too Slow
**Symptom**: Each story takes 20+ minutes  
**Solution**:
```bash
# Use smaller, faster model
./start.sh loglens --model codellama:latest

# Or increase timeout
./start.sh loglens --timeout 30
```

## Advanced Testing

### Test Different Models

Run the same project with different models to compare:

```bash
# Fast model
./start.sh loglens --model codellama:latest
# Note: completion rate, quality, speed

# Reset for next test
jq '.userStories[].passes = false' projects/loglens/prd.json > tmp
mv tmp projects/loglens/prd.json

# Better model
./start.sh loglens --model deepseek-coder:33b
# Compare results
```

### Test Prompt Variations

Modify `projects/loglens/PROMPT.md` to see impact:

```bash
# Baseline
./start.sh loglens --model deepseek-coder:latest

# Record: stories completed, quality

# Then modify PROMPT.md:
# - Add more specific instructions
# - Include examples
# - Emphasize testing

# Reset and re-run
# Compare results
```

### Test PRD Quality Impact

Try with different PRD complexity:

```bash
# Simple PRD (fewer stories, clear acceptance)
# vs
# Complex PRD (many stories, vague requirements)

# Measure: completion rate, time taken
```

## Success Checklist

After running Ralph on LogLens, you should be able to answer:

- [ ] Did Ralph complete at least 5 stories?
- [ ] Does the generated code actually run?
- [ ] Can you parse the sample log files?
- [ ] Are the statistics accurate?
- [ ] Did Ralph handle errors gracefully?
- [ ] Is the CLI usable?
- [ ] Did learnings accumulate in progress.txt?
- [ ] Was the circuit breaker behavior appropriate?
- [ ] What was the completion time per story?
- [ ] Which model worked best?

## Documenting Results

Create a results file:

```bash
cat > projects/loglens/TEST_RESULTS.md << 'EOF'
# LogLens Ralph Test Results

## Configuration
- Model: deepseek-coder:latest
- Date: 2024-01-15
- Duration: X hours

## Stories Completed: X/14

### Phase 1 (MVP)
- [x] 1.1 Core Infrastructure - PASS
- [x] 1.2 Apache Parser - PASS (with minor issues)
- [ ] 1.3 Statistics - FAIL (incomplete)
...

## Code Quality
- Works: YES/NO
- Tests: YES/NO
- Performance: Acceptable/Poor
- Error Handling: Good/Fair/Poor

## Key Learnings
- Model struggled with: [list]
- Model excelled at: [list]
- Circuit breaker opened: X times
- Most helpful prompt additions: [list]

## Recommendations
- Use model X for this type of project
- PRD could be improved by: [suggestions]
- Ralph improvements needed: [list]
EOF
```

## Next Steps

1. **Document Findings**: Record what worked and what didn't
2. **Try Another Model**: See if different model does better
3. **Iterate on Prompts**: Improve PROMPT.md based on learnings
4. **Simplify or Expand**: Adjust PRD complexity for next test
5. **Share Results**: Help improve Ralph-Ollama

This test plan turns LogLens into a comprehensive benchmark for Ralph-Ollama!
