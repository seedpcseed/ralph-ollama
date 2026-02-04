#!/bin/bash
# test-agent.sh - Proof of concept test for Cursor Agent integration
# Tests basic Cursor Agent invocation

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/cursor_agent.sh"

echo "=== Testing Cursor Agent Integration ==="
echo ""

# Check if agent is available
if ! check_cursor_agent; then
    echo "❌ Cursor Agent not available. Exiting."
    exit 1
fi

echo "✅ Cursor Agent is available"
echo ""

# Test 1: Simple prompt without files
echo "Test 1: Simple prompt"
echo "Prompt: 'Add a comment to this file explaining what it does'"
echo ""

# Create a test file
TEST_FILE="$SCRIPT_DIR/test-file.txt"
echo "#!/bin/bash
# This is a test script
echo 'Hello World'" > "$TEST_FILE"

echo "Test file created: $TEST_FILE"
echo ""

# Test agent invocation
echo "Invoking Cursor Agent..."
if invoke_cursor_agent "Add a comment at the top of this file explaining what it does" "$TEST_FILE"; then
    echo "✅ Agent invocation successful"
    echo ""
    echo "File contents after agent:"
    cat "$TEST_FILE"
else
    echo "❌ Agent invocation failed"
    exit 1
fi

echo ""
echo "=== Test Complete ==="

# Cleanup
rm -f "$TEST_FILE"
