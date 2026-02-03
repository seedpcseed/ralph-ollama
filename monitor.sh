#!/bin/bash
#
# Ralph-Ollama Monitor
# Live status dashboard
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECTS_DIR="$SCRIPT_DIR/projects"

if [ $# -eq 0 ]; then
    echo "Usage: $0 <project-name>"
    exit 1
fi

PROJECT_NAME="$1"
PROJECT_DIR="$PROJECTS_DIR/$PROJECT_NAME"

if [ ! -d "$PROJECT_DIR" ]; then
    echo "Error: Project not found: $PROJECT_DIR"
    exit 1
fi

STATUS_FILE="$PROJECT_DIR/status.json"
PRD_FILE="$PROJECT_DIR/prd.json"
LOG_DIR="$PROJECT_DIR/logs"
CB_FILE="$PROJECT_DIR/.circuit_breaker"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

clear

while true; do
    # Move cursor to top
    tput cup 0 0
    
    echo "=================================================="
    echo "  Ralph-Ollama Monitor: $PROJECT_NAME"
    echo "  $(date '+%Y-%m-%d %H:%M:%S')"
    echo "=================================================="
    echo ""
    
    # Status
    if [ -f "$STATUS_FILE" ]; then
        STATUS=$(jq -r '.status // "unknown"' "$STATUS_FILE")
        LOOPS=$(jq -r '.loop_count // 0' "$STATUS_FILE")
        COMPLETED=$(jq -r '.completed_stories // 0' "$STATUS_FILE")
        
        case "$STATUS" in
            "running")
                echo -e "${GREEN}Status: RUNNING${NC}"
                ;;
            "completed")
                echo -e "${GREEN}Status: COMPLETED${NC}"
                ;;
            *)
                echo -e "${YELLOW}Status: $STATUS${NC}"
                ;;
        esac
        
        echo "Loops executed: $LOOPS"
        echo "Stories completed: $COMPLETED"
    else
        echo -e "${YELLOW}Status: No status file${NC}"
    fi
    
    echo ""
    
    # Story progress
    if [ -f "$PRD_FILE" ]; then
        TOTAL=$(jq '[.userStories[]] | length' "$PRD_FILE")
        DONE=$(jq '[.userStories[] | select(.passes == true)] | length' "$PRD_FILE")
        REMAINING=$((TOTAL - DONE))
        
        PERCENT=0
        if [ $TOTAL -gt 0 ]; then
            PERCENT=$((DONE * 100 / TOTAL))
        fi
        
        echo "Stories: $DONE/$TOTAL ($PERCENT%)"
        
        # Progress bar
        BAR_WIDTH=40
        FILLED=$((PERCENT * BAR_WIDTH / 100))
        BAR=$(printf "%-${BAR_WIDTH}s" "#" | sed "s/ /-/g" | sed "s/#/█/g" | cut -c1-$FILLED)
        EMPTY=$(printf "%-$((BAR_WIDTH - FILLED))s" " " | sed "s/ /░/g")
        echo -e "[$BAR$EMPTY]"
        
        echo ""
        
        # Current/next stories
        if [ $REMAINING -gt 0 ]; then
            echo -e "${BLUE}Next stories:${NC}"
            jq -r '
                .userStories 
                | map(select(.passes == false))
                | sort_by(.priority)
                | .[0:3]
                | .[]
                | "  [\(.id)] \(.story | .[0:60])"
            ' "$PRD_FILE"
        else
            echo -e "${GREEN}✓ All stories complete!${NC}"
        fi
    fi
    
    echo ""
    
    # Circuit breaker
    if [ -f "$CB_FILE" ]; then
        CB_STATE=$(cat "$CB_FILE")
        if [ "$CB_STATE" = "OPEN" ]; then
            FAILURES=$(cat "${CB_FILE}.failures" 2>/dev/null || echo "?")
            echo -e "${RED}⚠️  Circuit Breaker: OPEN${NC} (failures: $FAILURES)"
        else
            FAILURES=$(cat "${CB_FILE}.failures" 2>/dev/null || echo "0")
            echo -e "${GREEN}Circuit Breaker: CLOSED${NC} (failures: $FAILURES/5)"
        fi
    fi
    
    echo ""
    
    # Recent log
    echo "Recent activity:"
    echo "--------------------"
    if [ -d "$LOG_DIR" ]; then
        LATEST_LOG=$(ls -t "$LOG_DIR"/loop_*.log 2>/dev/null | head -n1)
        if [ -n "$LATEST_LOG" ]; then
            tail -n 15 "$LATEST_LOG" | sed 's/^/  /'
        else
            echo "  No logs yet"
        fi
    fi
    
    echo ""
    echo "=================================================="
    echo "Press Ctrl+C to exit monitor"
    
    # Clear rest of screen
    tput ed
    
    sleep 2
done
