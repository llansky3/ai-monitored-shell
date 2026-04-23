#!/bin/bash

if [ -z "$1" ]; then
    echo "Usage: $0 <log_file>"
    exit 1
fi
LOG_FILE="$1"
INSTRUCTIONS="analysis_instructions.md"
LAST_LINE=$(wc -l < "$LOG_FILE" 2>/dev/null || echo 0)
START_TIME=$(date +%s)

# --- Dynamic Model Detection ---
CURRENT_MODEL=$(claude -p "/context" 2>/dev/null | grep "**Model:**" | sed 's/\*\*Model:\*\* //g' | xargs)
[ -z "$CURRENT_MODEL" ] && CURRENT_MODEL="not known"

ORIGINAL_BG=$(tmux show-option -gv status-style | grep -o 'bg=[^ ]*' || echo "bg=default")

cleanup() {
    tmux set-option status-style "$ORIGINAL_BG"
    tmux set-option status-left ""
    echo -e "\n🛑 AI MONITOR PAUSED."
    echo "Session cost:"
    claude -p "/cost" </dev/null 2>/dev/null || true
    echo "To resume analysis, type: start_monitor"
    exit 0
}

trap cleanup SIGINT SIGTERM

echo "🚀 ai-monitored-shell Active [Model: $CURRENT_MODEL]"
echo "Press Ctrl+C in this pane to pause the AI."

inotifywait -m -e modify "$LOG_FILE" --format '%w%f' | while read -r line; do
    while true; do
        SIZE_START=$(wc -l < "$LOG_FILE")
        sleep 1
        SIZE_END=$(wc -l < "$LOG_FILE")
        if [ "$SIZE_START" -eq "$SIZE_END" ]; then break; fi
    done

    TOTAL_LINES=$(wc -l < "$LOG_FILE")
    if [ "$TOTAL_LINES" -gt "$LAST_LINE" ]; then
        NEW_CONTENT_COUNT=$((TOTAL_LINES - LAST_LINE))
        [ "$NEW_CONTENT_COUNT" -gt 150 ] && NEW_CONTENT_COUNT=150
        RAW_CHUNK=$(tail -n "$NEW_CONTENT_COUNT" "$LOG_FILE")
        CLEAN_LAST_LINE=$(tail -n 1 "$LOG_FILE" | sed -r "s/\x1B\[([0-9]{1,3}(;[0-9]{1,2})?)?[mGK]//g" | tr -d '\r')

        if echo "$RAW_CHUNK" | cat -v | grep -qE "\^M|\\$" && echo "$CLEAN_LAST_LINE" | grep -qE "[$#>] ?$"; then
            CLEAN_CHUNK=$(echo "$RAW_CHUNK" | sed -r "s/\x1B\[([0-9]{1,3}(;[0-9]{1,2})?)?[mGK]//g" | tr -d '\r')
            
            tmux set-option status-style bg=red,fg=white
            tmux set-option status-left "[AI IS THINKING...] "

            PROMPT_FILE=$(mktemp)
            printf 'Rules:\n%s\n\nContext:\n%s\n' "$(cat "$INSTRUCTIONS")" "$CLEAN_CHUNK" > "$PROMPT_FILE"

            echo ""
            echo "--- Analyzing ${NEW_CONTENT_COUNT} lines ---"
            timeout 120 claude -p "$(cat "$PROMPT_FILE")" </dev/null || echo "⚠️  claude -p failed or timed out (exit: $?)"
            rm -f "$PROMPT_FILE"
            echo "--- Done ---"

            tmux set-option status-style "$ORIGINAL_BG"
            tmux set-option status-left ""
            LAST_LINE=$TOTAL_LINES
        fi
    fi
done