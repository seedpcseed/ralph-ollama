#!/bin/bash
# migrate-v1-to-v2.sh - Migrate Ralph projects from v1.0 to v2.0 data model
# Converts prd.json from v1.0 format to v2.0 enhanced format

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/utils.sh" 2>/dev/null || true

# Logging function
log() {
    local level=$1
    shift
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $*" >&2
}

show_help() {
    cat << EOF
Ralph v1.0 to v2.0 Migration Script

Usage: $0 <project-name> [OPTIONS]

Arguments:
    project-name    Name of the Ralph project to migrate

Options:
    --dry-run       Show what would be migrated without making changes
    --backup        Create backup of original files before migration
    -h, --help      Show this help message

This script migrates:
- prd.json: v1.0 → v2.0 enhanced format
- progress.txt: → progress.json (structured)
- Creates: verification-results.json (empty)
- Creates: file-mapping.json (empty)

Examples:
    $0 editio
    $0 editio --dry-run
    $0 editio --backup
EOF
}

# Check if jq is available
check_dependencies() {
    if ! command -v jq >/dev/null 2>&1; then
        log "ERROR" "jq is required but not installed"
        log "INFO" "Install with: sudo apt install jq  # or brew install jq"
        return 1
    fi
    return 0
}

# Migrate prd.json from v1.0 to v2.0
migrate_prd_json() {
    local project_dir=$1
    local prd_file="$project_dir/prd.json"
    local dry_run=${2:-false}
    local backup=${3:-false}
    
    if [[ ! -f "$prd_file" ]]; then
        log "ERROR" "prd.json not found: $prd_file"
        return 1
    fi
    
    # Check if already v2.0
    local version
    version=$(jq -r '.version // "1.0"' "$prd_file" 2>/dev/null || echo "1.0")
    if [[ "$version" == "2.0" ]]; then
        log "INFO" "prd.json is already v2.0 format"
        return 0
    fi
    
    log "INFO" "Migrating prd.json from v1.0 to v2.0..."
    
    # Create backup if requested
    if [[ "$backup" == "true" ]]; then
        cp "$prd_file" "${prd_file}.v1.backup"
        log "INFO" "Backup created: ${prd_file}.v1.backup"
    fi
    
    # Migrate using jq
    local migrated
    migrated=$(jq '
        {
            version: "2.0",
            branchName: .branchName,
            createdAt: (now | strftime("%Y-%m-%dT%H:%M:%SZ")),
            updatedAt: (now | strftime("%Y-%m-%dT%H:%M:%SZ")),
            userStories: [.userStories[] | 
                {
                    id: .id,
                    category: .category,
                    story: .story,
                    steps: .steps,
                    acceptance: .acceptance,
                    priority: .priority,
                    
                    # ENHANCED: Status and progress
                    status: (if .passes == true then "complete" else "pending" end),
                    progress: (if .passes == true then 100 else 0 end),
                    lastAttempt: null,
                    attemptCount: 0,
                    
                    # ENHANCED: Dependencies (empty initially)
                    dependsOn: [],
                    blocks: [],
                    
                    # ENHANCED: Verification tracking
                    verify: (if (.verify | type) == "string" then {
                        command: .verify,
                        lastRun: null,
                        lastResult: "not_run",
                        expectedResult: "pass"
                    } else (.verify // {
                        command: "",
                        lastRun: null,
                        lastResult: "not_run",
                        expectedResult: "pass"
                    }) end),
                    
                    # ENHANCED: File tracking (empty initially)
                    files: [],
                    
                    # ENHANCED: Test tracking (empty initially)
                    tests: [],
                    
                    # ENHANCED: Error tracking (empty initially)
                    errors: [],
                    
                    # Existing fields
                    notes: (.notes // ""),
                    createdAt: (now | strftime("%Y-%m-%dT%H:%M:%SZ")),
                    updatedAt: (now | strftime("%Y-%m-%dT%H:%M:%SZ"))
                }
            ]
        }
    ' "$prd_file" 2>/dev/null)
    
    if [[ -z "$migrated" ]]; then
        log "ERROR" "Failed to migrate prd.json"
        return 1
    fi
    
    if [[ "$dry_run" == "true" ]]; then
        log "INFO" "DRY RUN: Would migrate prd.json"
        echo "$migrated" | jq '.' | head -50
        return 0
    fi
    
    # Write migrated JSON
    echo "$migrated" | jq '.' > "${prd_file}.tmp" && mv "${prd_file}.tmp" "$prd_file"
    log "SUCCESS" "prd.json migrated to v2.0 format"
    
    return 0
}

# Create progress.json from progress.txt (if exists)
create_progress_json() {
    local project_dir=$1
    local progress_txt="$project_dir/progress.txt"
    local progress_json="$project_dir/progress.json"
    local dry_run=${2:-false}
    
    # Check if progress.json already exists
    if [[ -f "$progress_json" ]]; then
        log "INFO" "progress.json already exists, skipping"
        return 0
    fi
    
    # Create empty progress.json structure
    local progress_structure
    progress_structure=$(jq -n '{
        version: "2.0",
        projectName: "",
        sessionId: (now | strftime("%Y%m%d_%H%M%S")),
        stories: {},
        sessionStats: {
            totalStories: 0,
            completedStories: 0,
            inProgressStories: 0,
            failedStories: 0,
            blockedStories: 0,
            totalAttempts: 0,
            totalDuration: 0,
            claudeApiCalls: 0,
            localModelCalls: 0
        }
    }')
    
    # If progress.txt exists, try to parse it (basic parsing)
    if [[ -f "$progress_txt" ]]; then
        log "INFO" "progress.txt found, creating empty progress.json (manual migration may be needed)"
        # Note: Full parsing of progress.txt is complex and may need manual review
    else
        log "INFO" "No progress.txt found, creating empty progress.json"
    fi
    
    if [[ "$dry_run" == "true" ]]; then
        log "INFO" "DRY RUN: Would create progress.json"
        echo "$progress_structure" | jq '.'
        return 0
    fi
    
    # Set project name
    local project_name
    project_name=$(basename "$project_dir")
    progress_structure=$(echo "$progress_structure" | jq ".projectName = \"$project_name\"")
    
    echo "$progress_structure" | jq '.' > "$progress_json"
    log "SUCCESS" "progress.json created"
    
    return 0
}

# Create verification-results.json (empty)
create_verification_results_json() {
    local project_dir=$1
    local verify_json="$project_dir/verification-results.json"
    local dry_run=${2:-false}
    
    if [[ -f "$verify_json" ]]; then
        log "INFO" "verification-results.json already exists, skipping"
        return 0
    fi
    
    local verify_structure
    verify_structure=$(jq -n '{
        version: "2.0",
        projectName: "",
        verifications: {}
    }')
    
    if [[ "$dry_run" == "true" ]]; then
        log "INFO" "DRY RUN: Would create verification-results.json"
        echo "$verify_structure" | jq '.'
        return 0
    fi
    
    local project_name
    project_name=$(basename "$project_dir")
    verify_structure=$(echo "$verify_structure" | jq ".projectName = \"$project_name\"")
    
    echo "$verify_structure" | jq '.' > "$verify_json"
    log "SUCCESS" "verification-results.json created"
    
    return 0
}

# Create file-mapping.json (empty)
create_file_mapping_json() {
    local project_dir=$1
    local mapping_json="$project_dir/file-mapping.json"
    local dry_run=${2:-false}
    
    if [[ -f "$mapping_json" ]]; then
        log "INFO" "file-mapping.json already exists, skipping"
        return 0
    fi
    
    local mapping_structure
    mapping_structure=$(jq -n '{
        version: "2.0",
        projectName: "",
        files: {},
        storyFiles: {}
    }')
    
    if [[ "$dry_run" == "true" ]]; then
        log "INFO" "DRY RUN: Would create file-mapping.json"
        echo "$mapping_structure" | jq '.'
        return 0
    fi
    
    local project_name
    project_name=$(basename "$project_dir")
    mapping_structure=$(echo "$mapping_structure" | jq ".projectName = \"$project_name\"")
    
    echo "$mapping_structure" | jq '.' > "$mapping_json"
    log "SUCCESS" "file-mapping.json created"
    
    return 0
}

# Main migration function
main() {
    local project_name="$1"
    local dry_run=false
    local backup=false
    
    # Parse options
    shift
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run)
                dry_run=true
                shift
                ;;
            --backup)
                backup=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                log "ERROR" "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Validate project name
    if [[ -z "$project_name" ]]; then
        log "ERROR" "Project name is required"
        show_help
        exit 1
    fi
    
    local project_dir="$SCRIPT_DIR/projects/$project_name"
    
    # Check if project exists
    if [[ ! -d "$project_dir" ]]; then
        log "ERROR" "Project '$project_name' does not exist"
        log "INFO" "Project directory: $project_dir"
        exit 1
    fi
    
    # Check dependencies
    if ! check_dependencies; then
        exit 1
    fi
    
    log "INFO" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    if [[ "$dry_run" == "true" ]]; then
        log "INFO" "DRY RUN: Migrating project '$project_name' from v1.0 to v2.0"
    else
        log "INFO" "Migrating project '$project_name' from v1.0 to v2.0"
    fi
    log "INFO" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    # Migrate prd.json
    if ! migrate_prd_json "$project_dir" "$dry_run" "$backup"; then
        log "ERROR" "Failed to migrate prd.json"
        exit 1
    fi
    
    # Create progress.json
    if ! create_progress_json "$project_dir" "$dry_run"; then
        log "ERROR" "Failed to create progress.json"
        exit 1
    fi
    
    # Create verification-results.json
    if ! create_verification_results_json "$project_dir" "$dry_run"; then
        log "ERROR" "Failed to create verification-results.json"
        exit 1
    fi
    
    # Create file-mapping.json
    if ! create_file_mapping_json "$project_dir" "$dry_run"; then
        log "ERROR" "Failed to create file-mapping.json"
        exit 1
    fi
    
    echo ""
    log "SUCCESS" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    if [[ "$dry_run" == "true" ]]; then
        log "SUCCESS" "DRY RUN complete - no changes made"
    else
        log "SUCCESS" "Migration complete!"
    fi
    log "SUCCESS" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    if [[ "$dry_run" != "true" ]]; then
        log "INFO" "Migrated files:"
        log "INFO" "  - prd.json (v2.0 format)"
        log "INFO" "  - progress.json (created)"
        log "INFO" "  - verification-results.json (created)"
        log "INFO" "  - file-mapping.json (created)"
        echo ""
        log "INFO" "Next steps:"
        log "INFO" "  1. Review prd.json to verify migration"
        log "INFO" "  2. Review progress.json (may need manual migration from progress.txt)"
        log "INFO" "  3. Test with: ./start-v2.sh $project_name"
    fi
}

# Run main if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ $# -eq 0 ]]; then
        show_help
        exit 1
    fi
    main "$@"
fi
