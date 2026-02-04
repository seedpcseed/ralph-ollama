# Data Model Analysis: Current vs. Proposed

## Current System Analysis

### Current Data Model

1. **prd.json** - User stories with completion status
2. **progress.txt** - Unstructured learning journal
3. **requirements.md** - Technical specifications (markdown)

### Current Structure (prd.json)

```json
{
  "branchName": "ralph/editio",
  "userStories": [
    {
      "id": "1.1",
      "category": "technical",
      "story": "Add pulldown-cmark dependency",
      "steps": ["Open Cargo.toml"],
      "acceptance": "Cargo.toml includes pulldown-cmark dependency.",
      "priority": 10,
      "passes": true/false,  // Binary: done or not done
      "notes": "",
      "verify": "grep -q pulldown-cmark Cargo.toml"
    }
  ]
}
```

### Current Structure (progress.txt)

```
---
## 2026-02-04 05:46 - Story 1.1
Applied edit to projects/editio/src/lib.rs
Applied edit to projects/editio/Cargo.toml
Commit adc6a75 feat: Add pulldown-cmark dependency...
Summarization failed...
```

---

## Problems with Current System

### 1. **Binary Completion Status**
- **Problem**: `passes: true/false` is binary - story is either done or not done
- **Issue**: No way to track partial completion, incremental progress, or "mostly done but needs refinement"
- **Impact**: Stories marked complete prematurely, no way to track 80% complete stories

### 2. **No Dependency Tracking**
- **Problem**: Stories have `priority` but no explicit dependencies
- **Issue**: Can't enforce "Story 2.1 requires Story 1.5 to be complete"
- **Impact**: System might try to implement stories out of order, causing failures

### 3. **Weak Verification Model**
- **Problem**: `verify` is just a string command, no structured results
- **Issue**: Can't track verification history, failures, or retry attempts
- **Impact**: No way to see "this story failed 3 times with these errors"

### 4. **Unstructured Progress Tracking**
- **Problem**: `progress.txt` is free-form text, hard to parse programmatically
- **Issue**: Can't query "what errors occurred in story 1.3?" or "which stories had compilation errors?"
- **Impact**: Hard to learn from failures, no structured error analysis

### 5. **No File-to-Story Mapping**
- **Problem**: No way to know which files relate to which stories
- **Issue**: Can't answer "what stories affect src/parser.rs?" or "which stories are incomplete for the CLI module?"
- **Impact**: Poor context building, can't focus on relevant files

### 6. **No Test Coverage Tracking**
- **Problem**: No way to track if tests exist, pass, or cover the story
- **Issue**: Stories marked complete without tests, or tests exist but fail
- **Impact**: False completion, poor code quality

### 7. **No Incremental Progress**
- **Problem**: Story is either 0% or 100% complete
- **Issue**: Can't track "parser.rs exists but incomplete" or "tests written but failing"
- **Impact**: Can't resume partial work, have to start over

### 8. **No Error History**
- **Problem**: Errors are logged in progress.txt but not structured
- **Issue**: Can't analyze error patterns, categorize failures, or learn from mistakes
- **Impact**: Same errors repeated, no systematic improvement

### 9. **No Code Quality Metrics**
- **Problem**: No tracking of compilation status, test coverage, code complexity
- **Issue**: Can't measure "is this story actually complete?"
- **Impact**: Stories marked complete but code is broken

### 10. **Separation of Concerns**
- **Problem**: PRD (what), requirements.md (how), prd.json (tasks) are separate
- **Issue**: No clear relationship between them, hard to maintain consistency
- **Impact**: Requirements drift, stories don't match PRD

---

## Proposed Improvements

### Option 1: Enhanced JSON Schema (Evolutionary)

**Keep current structure but enhance it:**

```json
{
  "branchName": "ralph/editio",
  "userStories": [
    {
      "id": "1.1",
      "category": "technical",
      "story": "Add pulldown-cmark dependency",
      "steps": ["Open Cargo.toml"],
      "acceptance": "Cargo.toml includes pulldown-cmark dependency.",
      "priority": 10,
      
      // ENHANCED: Status tracking
      "status": "complete" | "in_progress" | "blocked" | "failed",
      "progress": 0-100,  // Percentage complete
      "lastAttempt": "2026-02-04T07:30:00Z",
      "attemptCount": 3,
      
      // ENHANCED: Dependencies
      "dependsOn": ["1.0"],  // Story IDs that must be complete first
      "blocks": ["1.2"],     // Story IDs blocked by this one
      
      // ENHANCED: Verification tracking
      "verify": {
        "command": "grep -q pulldown-cmark Cargo.toml",
        "lastRun": "2026-02-04T07:30:00Z",
        "lastResult": "pass" | "fail",
        "history": [
          {"timestamp": "...", "result": "fail", "error": "..."},
          {"timestamp": "...", "result": "pass"}
        ]
      },
      
      // ENHANCED: File tracking
      "files": [
        {"path": "Cargo.toml", "status": "modified", "lines": 8}
      ],
      
      // ENHANCED: Test tracking
      "tests": [
        {"name": "test_dependency", "status": "pass", "coverage": true}
      ],
      
      // ENHANCED: Error tracking
      "errors": [
        {"type": "compilation", "message": "...", "timestamp": "..."}
      ],
      
      "notes": ""
    }
  ]
}
```

**Pros:**
- ✅ Backward compatible (can migrate existing prd.json)
- ✅ Structured, queryable data
- ✅ Tracks dependencies, progress, errors
- ✅ Still JSON (familiar, easy to work with)

**Cons:**
- ❌ More complex schema
- ❌ Still single file (could get large)
- ❌ No relational structure

---

### Option 2: Structured Progress Tracking (JSON)

**Replace progress.txt with progress.json:**

```json
{
  "sessionId": "2026-02-04_07-30-00",
  "stories": [
    {
      "storyId": "1.1",
      "attempts": [
        {
          "timestamp": "2026-02-04T07:30:00Z",
          "action": "implement",
          "filesModified": ["Cargo.toml"],
          "gitCommit": "abc123",
          "verification": {
            "command": "grep -q pulldown-cmark Cargo.toml",
            "result": "pass"
          }
        },
        {
          "timestamp": "2026-02-04T07:31:00Z",
          "action": "fix",
          "error": "compilation failed: missing import",
          "filesModified": ["src/lib.rs"],
          "verification": {
            "result": "pass"
          }
        }
      ],
      "learnings": [
        "Need to add use statement for pulldown_cmark"
      ],
      "errors": [
        {
          "type": "compilation",
          "message": "cannot find type `Node`",
          "file": "src/parser.rs",
          "line": 4
        }
      ]
    }
  ]
}
```

**Pros:**
- ✅ Structured, queryable
- ✅ Can track error patterns
- ✅ Can analyze what works/fails
- ✅ Better for learning system

**Cons:**
- ❌ Breaking change (progress.txt → progress.json)
- ❌ More complex to write/read
- ❌ Could get large over time

---

### Option 3: Database Approach (SQLite)

**Use SQLite instead of JSON files:**

```sql
-- Stories table
CREATE TABLE stories (
  id TEXT PRIMARY KEY,
  project_id TEXT,
  category TEXT,
  story TEXT,
  priority INTEGER,
  status TEXT,  -- complete, in_progress, blocked, failed
  progress INTEGER,  -- 0-100
  depends_on TEXT,  -- JSON array of story IDs
  verify_command TEXT,
  created_at TIMESTAMP,
  updated_at TIMESTAMP
);

-- Story attempts table
CREATE TABLE story_attempts (
  id INTEGER PRIMARY KEY,
  story_id TEXT,
  timestamp TIMESTAMP,
  action TEXT,  -- implement, fix, verify
  files_modified TEXT,  -- JSON array
  git_commit TEXT,
  verification_result TEXT,  -- pass, fail
  error_message TEXT,
  FOREIGN KEY (story_id) REFERENCES stories(id)
);

-- Files table (track which files relate to which stories)
CREATE TABLE story_files (
  story_id TEXT,
  file_path TEXT,
  status TEXT,  -- created, modified, deleted
  lines_added INTEGER,
  lines_removed INTEGER,
  FOREIGN KEY (story_id) REFERENCES stories(id)
);

-- Errors table
CREATE TABLE story_errors (
  id INTEGER PRIMARY KEY,
  story_id TEXT,
  error_type TEXT,  -- compilation, test, verification
  error_message TEXT,
  file_path TEXT,
  line_number INTEGER,
  timestamp TIMESTAMP,
  FOREIGN KEY (story_id) REFERENCES stories(id)
);
```

**Pros:**
- ✅ Relational structure (dependencies, file mapping)
- ✅ Queryable (SQL)
- ✅ Scalable (handles large projects)
- ✅ Can track complex relationships
- ✅ Better for analytics

**Cons:**
- ❌ Major breaking change
- ❌ Requires SQLite dependency
- ❌ More complex setup
- ❌ Harder to version control (binary file)

---

### Option 4: Hybrid Approach (Recommended)

**Combine best of all:**

1. **prd.json** - Keep for story definitions (source of truth)
   - Enhanced with dependencies, status, progress
   - Still human-readable, version-controllable

2. **progress.json** - Replace progress.txt with structured JSON
   - Track attempts, errors, learnings
   - Queryable, analyzable

3. **verification-results.json** - New file for verification tracking
   - Structured verification history
   - Test results, compilation status

4. **file-mapping.json** - New file for file-to-story relationships
   - Which files belong to which stories
   - File status, modification history

**Structure:**

```
projects/editio/
├── prd.json                    # Story definitions (enhanced)
├── progress.json               # Attempts, errors, learnings (structured)
├── verification-results.json    # Verification history
├── file-mapping.json           # File-to-story relationships
└── requirements.md             # Technical specs (keep as markdown)
```

**Example prd.json (enhanced):**
```json
{
  "branchName": "ralph/editio",
  "userStories": [
    {
      "id": "1.1",
      "category": "technical",
      "story": "Add pulldown-cmark dependency",
      "steps": ["Open Cargo.toml"],
      "acceptance": "Cargo.toml includes pulldown-cmark dependency.",
      "priority": 10,
      "dependsOn": [],
      "status": "complete",
      "progress": 100,
      "verify": {
        "command": "grep -q pulldown-cmark Cargo.toml",
        "lastResult": "pass"
      },
      "files": ["Cargo.toml"],
      "notes": ""
    }
  ]
}
```

**Example progress.json:**
```json
{
  "stories": {
    "1.1": {
      "attempts": [
        {
          "timestamp": "2026-02-04T07:30:00Z",
          "action": "implement",
          "filesModified": ["Cargo.toml"],
          "verification": "pass"
        }
      ],
      "learnings": [],
      "errors": []
    }
  }
}
```

**Pros:**
- ✅ Backward compatible (can migrate gradually)
- ✅ Structured but still readable
- ✅ Separates concerns (stories vs. progress vs. verification)
- ✅ Queryable, analyzable
- ✅ Version controllable (all JSON/text)

**Cons:**
- ❌ Multiple files to manage
- ❌ Need to keep them in sync
- ❌ More complex than single file

---

## Recommendation: Hybrid Approach (Option 4)

### Why Hybrid?

1. **Best of both worlds**: Structured data + human readability
2. **Gradual migration**: Can enhance prd.json first, add new files later
3. **Separation of concerns**: Stories, progress, verification are separate
4. **Queryable**: Can analyze patterns, learn from failures
5. **Version controllable**: All JSON/text files, Git-friendly

### Migration Path

1. **Phase 1**: Enhance prd.json schema (add dependencies, status, progress)
2. **Phase 2**: Create progress.json (structured tracking)
3. **Phase 3**: Create verification-results.json (verification history)
4. **Phase 4**: Create file-mapping.json (file relationships)

### Key Enhancements

1. **Dependency Graph**: `dependsOn` and `blocks` arrays
2. **Status Tracking**: `status` (complete/in_progress/blocked/failed) + `progress` (0-100)
3. **Verification History**: Track verification attempts and results
4. **File Mapping**: Know which files relate to which stories
5. **Error Tracking**: Structured error history for learning

---

## Questions to Answer

1. **Do we need a database?** Or is enhanced JSON sufficient?
   - **Answer**: Enhanced JSON is sufficient for now. Can migrate to SQLite later if needed.

2. **Should progress.txt become progress.json?**
   - **Answer**: Yes, structured JSON is better for querying and analysis.

3. **Do we need file-mapping.json?**
   - **Answer**: Yes, helps with context building and understanding relationships.

4. **Should verification be in prd.json or separate file?**
   - **Answer**: Keep verify command in prd.json, but track results in verification-results.json.

5. **How to handle story dependencies?**
   - **Answer**: Add `dependsOn` array to each story, validate before execution.

---

## Conclusion

**Current system is insufficient** - binary completion, no dependencies, unstructured progress.

**Recommended: Hybrid Approach (Option 4)**
- Enhanced prd.json with dependencies, status, progress
- Structured progress.json for tracking
- Separate verification-results.json for verification history
- file-mapping.json for file relationships

**Benefits:**
- Better tracking and analysis
- Dependency enforcement
- Incremental progress tracking
- Error learning and improvement
- Still human-readable and Git-friendly

**Next Steps:**
1. Design enhanced schema
2. Create migration script
3. Update convert-v2.sh to generate enhanced format
4. Update start-v2.sh to use enhanced format
