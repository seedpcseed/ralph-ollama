#!/bin/bash
#
# Review Ralph session logs
# Shows summary of recent session activity, failures, and stuck loops
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECTS_DIR="$SCRIPT_DIR/projects"

if [ $# -eq 0 ]; then
    echo "Usage: $0 <project-name> [--latest|--all]"
    echo ""
    echo "Options:"
    echo "  --latest    Show only the most recent session (default)"
    echo "  --all       Show all sessions"
    echo ""
    echo "Example: $0 loglens"
    exit 1
fi

PROJECT_NAME="$1"
PROJECT_DIR="$PROJECTS_DIR/$PROJECT_NAME"
LOG_DIR="$PROJECT_DIR/logs"

if [ ! -d "$LOG_DIR" ]; then
    echo "Error: Project logs not found: $LOG_DIR"
    exit 1
fi

SHOW_ALL=false
if [ "$2" = "--all" ]; then
    SHOW_ALL=true
fi

echo "=================================================="
echo "Ralph Session Review: $PROJECT_NAME"
echo "=================================================="
echo ""

# Find session logs
SESSION_LOGS=$(ls -t "$LOG_DIR"/session_*.log 2>/dev/null | head -1)

if [ -z "$SESSION_LOGS" ]; then
    echo "No session logs found."
    exit 0
fi

if [ "$SHOW_ALL" = true ]; then
    SESSION_LOGS=$(ls -t "$LOG_DIR"/session_*.log 2>/dev/null)
fi

for SESSION_LOG in $SESSION_LOGS; do
    echo "Session: $(basename "$SESSION_LOG")"
    echo "----------------------------------------"
    
    # Summary stats (ensure single integer output)
    TOTAL_LOOPS=$(grep -c "Loop #" "$SESSION_LOG" 2>/dev/null | head -1 | awk '{print $1}' || echo "0")
    SUCCESSES=$(grep -c "SUCCESS" "$SESSION_LOG" 2>/dev/null | head -1 | awk '{print $1}' || echo "0")
    VERIFY_FAILS=$(grep -c "VERIFY_FAIL" "$SESSION_LOG" 2>/dev/null | head -1 | awk '{print $1}' || echo "0")
    ERRORS=$(grep -c "ERROR" "$SESSION_LOG" 2>/dev/null | head -1 | awk '{print $1}' || echo "0")
    STUCK=$(grep -c "STUCK" "$SESSION_LOG" 2>/dev/null | head -1 | awk '{print $1}' || echo "0")
    
    echo "Loops: $TOTAL_LOOPS | Successes: $SUCCESSES | Verify failures: $VERIFY_FAILS | Errors: $ERRORS | Stuck: $STUCK"
    echo ""
    
    # Show stuck loops
    if [ "$STUCK" -gt 0 ]; then
        echo "⚠️  Stuck Loops Detected:"
        grep "STUCK" "$SESSION_LOG" | sed 's/^/  /'
        echo ""
    fi
    
    # Show recent errors
    if [ "$ERRORS" -gt 0 ]; then
        echo "Recent Errors:"
        grep "ERROR" "$SESSION_LOG" | tail -5 | sed 's/^/  /'
        echo ""
    fi
    
    # Show recent verify failures
    if [ "$VERIFY_FAILS" -gt 0 ]; then
        echo "Recent Verify Failures:"
        grep "VERIFY_FAIL" "$SESSION_LOG" | tail -5 | sed 's/^/  /'
        echo ""
    fi
    
    # Show completed stories
    if [ "$SUCCESSES" -gt 0 ]; then
        echo "Completed Stories:"
        grep "SUCCESS" "$SESSION_LOG" | sed 's/^/  /'
        echo ""
    fi
    
    if [ "$SHOW_ALL" = false ]; then
        break
    fi
    
    echo ""
done

echo "Full session log: $SESSION_LOG"
echo "=================================================="
