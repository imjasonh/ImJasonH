#!/bin/bash

# Claude hook to run goimports on changed Go files after tool use
# Only processes .go files that were modified by Edit, Write, or MultiEdit tools

# Require jq for JSON parsing
if ! command -v jq &> /dev/null; then
    exit 1
fi

# Read JSON input from stdin
INPUT=$(cat)

# Extract hook event name and tool name using jq
HOOK_EVENT=$(echo "$INPUT" | jq -r '.hook_event_name // empty')
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
TOOL_INPUT=$(echo "$INPUT" | jq -r '.tool_input // empty')

# Check if this is a PostToolUse event
if [[ "$HOOK_EVENT" != "PostToolUse" ]]; then
    echo '{"decision": "approve"}'
    exit 0
fi

# Check if the tool was one that modifies files
case "$TOOL_NAME" in
    Edit|Write|MultiEdit)
        ;;
    *)
        echo '{"decision": "approve"}'
        exit 0
        ;;
esac

# Parse the tool input to find the file path
FILE_PATH=""

# Extract file_path from the tool input JSON
# Note: tool_input is a JSON string containing JSON, so we need to parse it twice
if [[ -n "$TOOL_INPUT" ]]; then
    # First parse the JSON string, then extract file_path
    FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input' | jq -r '.file_path // empty' 2>/dev/null)
fi

# Check if we found a file path and it's a Go file
if [[ -n "$FILE_PATH" && "$FILE_PATH" == *.go && -f "$FILE_PATH" ]]; then
    # Run goimports on the file
    goimports -w "$FILE_PATH"
fi

# Always approve - formatting is non-blocking
echo '{"decision": "approve"}'
