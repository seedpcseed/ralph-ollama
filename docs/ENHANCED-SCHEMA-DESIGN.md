# Enhanced Data Model Schema Design

**Version:** 1.0  
**Date:** 2026-02-04  
**Status:** Approved (Option 4 - Hybrid Approach)

---

## Overview

This document defines the enhanced data model schema for Ralph 2.0, using a hybrid approach that enhances JSON files while maintaining backward compatibility and human readability.

---

## File Structure

```
projects/<project-name>/
├── prd.json                    # Enhanced story definitions
├── progress.json               # Structured progress tracking (NEW)
├── verification-results.json    # Verification history (NEW)
├── file-mapping.json           # File-to-story relationships (NEW)
└── requirements.md             # Technical specs (unchanged)
```

---

## 1. Enhanced prd.json Schema

### Base Structure

```json
{
  "version": "2.0",
  "branchName": "ralph/editio",
  "createdAt": "2026-02-04T07:00:00Z",
  "updatedAt": "2026-02-04T07:30:00Z",
  "userStories": [...]
}
```

### Enhanced Story Schema

```json
{
  "id": "1.1",
  "category": "technical" | "functional" | "ui",
  "story": "Add pulldown-cmark dependency to Cargo.toml",
  "steps": [
    "Open Cargo.toml",
    "Add pulldown-cmark = \"0.9\" to [dependencies]"
  ],
  "acceptance": "Cargo.toml includes pulldown-cmark dependency.",
  
  // ENHANCED: Status and progress tracking
  "status": "complete" | "in_progress" | "blocked" | "failed" | "pending",
  "progress": 0-100,  // Percentage complete
  "lastAttempt": "2026-02-04T07:30:00Z",
  "attemptCount": 3,
  
  // ENHANCED: Dependencies
  "dependsOn": ["1.0"],  // Array of story IDs that must be complete first
  "blocks": ["1.2"],     // Array of story IDs blocked by this one
  
  // ENHANCED: Verification tracking
  "verify": {
    "command": "grep -q pulldown-cmark Cargo.toml",
    "lastRun": "2026-02-04T07:30:00Z",
    "lastResult": "pass" | "fail" | "not_run",
    "expectedResult": "pass"  // What result indicates completion
  },
  
  // ENHANCED: File tracking
  "files": [
    {
      "path": "Cargo.toml",
      "status": "created" | "modified" | "deleted",
      "linesAdded": 1,
      "linesRemoved": 0
    }
  ],
  
  // ENHANCED: Test tracking
  "tests": [
    {
      "name": "test_dependency_exists",
      "file": "tests/dependencies.rs",
      "status": "pass" | "fail" | "not_written",
      "coverage": true
    }
  ],
  
  // ENHANCED: Error tracking
  "errors": [
    {
      "type": "compilation" | "test" | "verification" | "runtime",
      "message": "cannot find type `Node`",
      "file": "src/parser.rs",
      "line": 4,
      "timestamp": "2026-02-04T07:25:00Z",
      "resolved": false
    }
  ],
  
  // Existing fields
  "priority": 10,
  "notes": "",
  "createdAt": "2026-02-04T07:00:00Z",
  "updatedAt": "2026-02-04T07:30:00Z"
}
```

### Status Values

- **pending**: Story not yet started
- **in_progress**: Story currently being worked on
- **blocked**: Story blocked by incomplete dependencies
- **failed**: Story failed after max attempts
- **complete**: Story verified and complete

### Priority Rules

- Lower number = higher priority (do first)
- Priority 1-3: Critical/architecture (use Claude API)
- Priority 4-7: Important features (use Claude or local)
- Priority 8-10: Nice-to-have (use local model)

---

## 2. progress.json Schema (NEW)

### Structure

```json
{
  "version": "2.0",
  "projectName": "editio",
  "sessionId": "2026-02-04_07-30-00",
  "stories": {
    "1.1": {
      "attempts": [
        {
          "id": "attempt-1",
          "timestamp": "2026-02-04T07:30:00Z",
          "action": "implement" | "fix" | "verify",
          "model": "ollama/deepseek-coder:33b",
          "filesModified": ["Cargo.toml"],
          "gitCommit": "abc123",
          "verification": {
            "command": "grep -q pulldown-cmark Cargo.toml",
            "result": "pass" | "fail",
            "output": "...",
            "duration": 0.5
          },
          "compilation": {
            "result": "pass" | "fail",
            "errors": [],
            "warnings": []
          },
          "tests": {
            "result": "pass" | "fail" | "not_run",
            "passed": 5,
            "failed": 0,
            "output": "..."
          }
        }
      ],
      "learnings": [
        "Need to add use statement for pulldown_cmark",
        "Cargo.toml format requires exact version syntax"
      ],
      "totalAttempts": 3,
      "totalDuration": 45.2,
      "firstAttempt": "2026-02-04T07:30:00Z",
      "lastAttempt": "2026-02-04T07:32:00Z"
    }
  },
  "sessionStats": {
    "totalStories": 15,
    "completedStories": 5,
    "inProgressStories": 1,
    "failedStories": 0,
    "blockedStories": 2,
    "totalAttempts": 23,
    "totalDuration": 1200.5,
    "claudeApiCalls": 3,
    "localModelCalls": 20
  }
}
```

---

## 3. verification-results.json Schema (NEW)

### Structure

```json
{
  "version": "2.0",
  "projectName": "editio",
  "verifications": {
    "1.1": {
      "command": "grep -q pulldown-cmark Cargo.toml",
      "history": [
        {
          "timestamp": "2026-02-04T07:30:00Z",
          "result": "fail",
          "exitCode": 1,
          "output": "grep: Cargo.toml: No such file or directory",
          "duration": 0.1
        },
        {
          "timestamp": "2026-02-04T07:31:00Z",
          "result": "pass",
          "exitCode": 0,
          "output": "",
          "duration": 0.05
        }
      ],
      "lastResult": "pass",
      "lastRun": "2026-02-04T07:31:00Z",
      "totalRuns": 2,
      "passCount": 1,
      "failCount": 1
    }
  }
}
```

---

## 4. file-mapping.json Schema (NEW)

### Structure

```json
{
  "version": "2.0",
  "projectName": "editio",
  "files": {
    "Cargo.toml": {
      "stories": ["1.1"],
      "status": "modified",
      "lastModified": "2026-02-04T07:30:00Z",
      "lines": 8,
      "gitCommit": "abc123"
    },
    "src/parser.rs": {
      "stories": ["1.7", "1.8", "1.9", "1.10", "1.11", "1.12", "1.13"],
      "status": "created",
      "lastModified": "2026-02-04T07:35:00Z",
      "lines": 150,
      "gitCommit": "def456"
    }
  },
  "storyFiles": {
    "1.1": ["Cargo.toml"],
    "1.7": ["src/parser.rs", "src/ast.rs"],
    "1.8": ["src/parser.rs"],
    "1.9": ["src/parser.rs", "src/ast.rs"]
  }
}
```

---

## 5. Migration from v1.0 to v2.0

### Migration Script Logic

```bash
# Pseudocode for migration
for story in prd.json.userStories:
    # Set status based on passes field
    if story.passes == true:
        story.status = "complete"
        story.progress = 100
    else:
        story.status = "pending"
        story.progress = 0
    
    # Initialize new fields
    story.dependsOn = []
    story.blocks = []
    story.attemptCount = 0
    story.lastAttempt = null
    
    # Convert verify string to object
    if story.verify is string:
        story.verify = {
            "command": story.verify,
            "lastRun": null,
            "lastResult": "not_run",
            "expectedResult": "pass"
        }
    
    # Initialize files array
    story.files = []
    
    # Initialize tests array
    story.tests = []
    
    # Initialize errors array
    story.errors = []

# Create progress.json from progress.txt
progress.json = {
    "version": "2.0",
    "stories": {}
}

# Parse progress.txt and populate progress.json
# (This is more complex, may need manual review)

# Create verification-results.json (empty initially)
verification-results.json = {
    "version": "2.0",
    "verifications": {}
}

# Create file-mapping.json (empty initially)
file-mapping.json = {
    "version": "2.0",
    "files": {},
    "storyFiles": {}
}
```

---

## 6. Validation Rules

### Story Validation

1. **ID uniqueness**: All story IDs must be unique
2. **Dependency validation**: `dependsOn` must reference existing story IDs
3. **Status consistency**: 
   - `status: "complete"` → `progress: 100` and `verify.lastResult: "pass"`
   - `status: "blocked"` → at least one dependency has `status != "complete"`
4. **Priority range**: Must be 1-10
5. **Progress range**: Must be 0-100

### Dependency Validation

1. **No circular dependencies**: Story A cannot depend on Story B if B depends on A
2. **Dependency completion**: Story cannot be `status: "complete"` if dependencies are incomplete
3. **Blocking relationships**: If Story A blocks Story B, B cannot be started until A is complete

### File Mapping Validation

1. **File existence**: Files in `file-mapping.json` should exist in filesystem
2. **Story consistency**: Files listed in story.files should match file-mapping.json

---

## 7. Query Examples

### Find incomplete stories

```bash
jq '.userStories[] | select(.status != "complete")' prd.json
```

### Find stories blocking others

```bash
jq '.userStories[] | select(.blocks | length > 0)' prd.json
```

### Find stories with errors

```bash
jq '.userStories[] | select(.errors | length > 0)' prd.json
```

### Find files related to a story

```bash
jq '.storyFiles["1.1"]' file-mapping.json
```

### Find stories affecting a file

```bash
jq '.files["src/parser.rs"].stories' file-mapping.json
```

### Get verification history for a story

```bash
jq '.verifications["1.1"].history' verification-results.json
```

### Get progress statistics

```bash
jq '.sessionStats' progress.json
```

---

## 8. Implementation Notes

### Backward Compatibility

- Old prd.json (v1.0) can be migrated automatically
- Old progress.txt can be parsed (with some manual review)
- New scripts should handle both v1.0 and v2.0 formats

### Performance Considerations

- prd.json may get large (100+ stories) but JSON is still efficient
- progress.json will grow over time - consider archiving old sessions
- file-mapping.json should be updated incrementally

### Git Integration

- All JSON files are version-controllable
- Consider .gitignore for large progress.json files
- Keep verification-results.json in git for history

---

## 9. Schema Versioning

### Version Field

All files include a `version` field:
- `"version": "1.0"` - Original format
- `"version": "2.0"` - Enhanced format

### Migration Path

1. Scripts check `version` field
2. If v1.0, run migration to v2.0
3. If v2.0, use directly
4. Future versions can add migration scripts

---

## 10. Example: Complete Story Lifecycle

### Story Creation (convert-v2.sh)

```json
{
  "id": "1.1",
  "status": "pending",
  "progress": 0,
  "dependsOn": [],
  "verify": {
    "command": "grep -q pulldown-cmark Cargo.toml",
    "expectedResult": "pass"
  }
}
```

### Story Started (start-v2.sh)

```json
{
  "id": "1.1",
  "status": "in_progress",
  "progress": 0,
  "lastAttempt": "2026-02-04T07:30:00Z",
  "attemptCount": 1
}
```

### Story Implementation Attempt

```json
// progress.json
{
  "1.1": {
    "attempts": [{
      "action": "implement",
      "filesModified": ["Cargo.toml"],
      "verification": {"result": "fail"},
      "compilation": {"result": "pass"}
    }]
  }
}
```

### Story Verification Failed

```json
// prd.json
{
  "id": "1.1",
  "status": "in_progress",
  "progress": 50,
  "errors": [{
    "type": "verification",
    "message": "grep command failed",
    "resolved": false
  }]
}

// verification-results.json
{
  "1.1": {
    "history": [{
      "result": "fail",
      "output": "grep: Cargo.toml: No such file"
    }]
  }
}
```

### Story Fixed and Verified

```json
// prd.json
{
  "id": "1.1",
  "status": "complete",
  "progress": 100,
  "verify": {
    "lastResult": "pass",
    "lastRun": "2026-02-04T07:31:00Z"
  },
  "files": [{
    "path": "Cargo.toml",
    "status": "modified"
  }]
}

// verification-results.json
{
  "1.1": {
    "lastResult": "pass",
    "passCount": 1,
    "failCount": 1
  }
}
```

---

## 11. API Functions (for scripts)

### Story Management

```bash
# Get next story to work on
get_next_story(prd.json) -> story

# Mark story complete
mark_story_complete(story_id, prd.json)

# Update story progress
update_story_progress(story_id, progress, prd.json)

# Check dependencies
check_dependencies(story_id, prd.json) -> bool

# Get blocked stories
get_blocked_stories(prd.json) -> [story_ids]
```

### Progress Tracking

```bash
# Record attempt
record_attempt(story_id, attempt_data, progress.json)

# Get story attempts
get_story_attempts(story_id, progress.json) -> [attempts]

# Get learnings
get_story_learnings(story_id, progress.json) -> [learnings]
```

### Verification

```bash
# Run verification
run_verification(story_id, prd.json) -> result

# Record verification result
record_verification(story_id, result, verification-results.json)

# Get verification history
get_verification_history(story_id, verification-results.json) -> [results]
```

### File Mapping

```bash
# Update file mapping
update_file_mapping(file_path, story_id, file-mapping.json)

# Get files for story
get_story_files(story_id, file-mapping.json) -> [files]

# Get stories for file
get_file_stories(file_path, file-mapping.json) -> [story_ids]
```

---

## 12. Next Steps

1. **Create migration script** (`migrate-v1-to-v2.sh`)
2. **Update convert-v2.sh** to generate v2.0 format
3. **Update start-v2.sh** to use v2.0 format
4. **Create helper library** (`lib/data-model.sh`) with API functions
5. **Add validation** to ensure schema compliance
6. **Test migration** with existing projects

---

## Appendix: Full Example Files

See `examples/enhanced-schema/` directory for complete example files.
