#!/bin/bash

if [ -z "$1" ]; then
    echo "Usage: $0 <session_file> [cost_file]"
    exit 1
fi
SESSION_FILE="$1"
COST_FILE="${2:-}"

echo "Waiting for AI monitor session..."
while [ ! -s "$SESSION_FILE" ]; do
    sleep 1
done

SESSION_ID=$(cat "$SESSION_FILE")
echo "Session ID: $SESSION_ID"
echo "Focus this pane: Ctrl+B + → Right arrow"
echo "Ask questions about your shell session. Type 'exit' to quit."
echo ""

while true; do
    read -r -p "> " USER_INPUT || break
    [ "$USER_INPUT" = "exit" ] && break
    [ -z "$USER_INPUT" ] && continue

    # Refresh session ID in case monitor updated it
    SESSION_ID=$(cat "$SESSION_FILE" 2>/dev/null || echo "$SESSION_ID")

    echo ""
    RESPONSE=$(claude --resume "$SESSION_ID" -p "$USER_INPUT" --output-format json </dev/null 2>/dev/null)
    if [ -n "$RESPONSE" ]; then
        CALL_COST=$(jq -r '.total_cost_usd // 0' <<< "$RESPONSE" 2>/dev/null || echo "0")
        jq -r '.result // .' <<< "$RESPONSE" 2>/dev/null || echo "$RESPONSE"
        if [ -n "$COST_FILE" ] && [ -f "$COST_FILE" ]; then
            PREV_COST=$(cat "$COST_FILE" | tr -d '$' 2>/dev/null || echo "0")
            printf '$%.4f' "$(awk "BEGIN {printf \"%.4f\", $PREV_COST + $CALL_COST}")" > "$COST_FILE"
        fi
    fi
    echo ""
done

echo "Chat session ended."
