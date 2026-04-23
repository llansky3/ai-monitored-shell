#!/bin/bash

if [ -z "$1" ]; then
    echo "Usage: $0 <log_file>"
    exit 1
fi
LOG_FILE="$1"
SESSION_FILE="${2:-$(mktemp)}"
COST_FILE="${3:-$(mktemp)}"
[ ! -s "$COST_FILE" ] && echo '$0.0000' > "$COST_FILE"
INSTRUCTIONS="analysis_instructions.md"
LAST_LINE=$(wc -l < "$LOG_FILE" 2>/dev/null || echo 0)
START_TIME=$(date +%s)

# --- Dynamic Model Detection ---
CURRENT_MODEL=$(claude -p "/context" 2>/dev/null | grep "**Model:**" | sed 's/\*\*Model:\*\* //g' | xargs)
[ -z "$CURRENT_MODEL" ] && CURRENT_MODEL="not known"

ORIGINAL_BG=$(tmux show-option -gv status-style | grep -o 'bg=[^ ]*' || echo "bg=default")
ORIGINAL_STATUS_LEFT_LEN=$(tmux show-option -gv status-left-length 2>/dev/null || echo "10")
ORIGINAL_STATUS_RIGHT=$(tmux show-option -gv status-right 2>/dev/null || echo "")
ORIGINAL_STATUS_INTERVAL=$(tmux show-option -gv status-interval 2>/dev/null || echo "15")

set_status_waiting() {
    tmux set-option status-left-length 30
    tmux set-option status-style "$ORIGINAL_BG"
    tmux set-option status-left "WAITING FOR USER INPUT "
}

set_status_thinking() {
    tmux set-option status-left-length 30
    tmux set-option status-style "bg=red,fg=white"
    tmux set-option status-left "AI IS THINKING "
}

set_status_stopped() {
    tmux set-option status-left-length 30
    tmux set-option status-style  "bg=red,fg=white"
    tmux set-option status-left "AI MONITORING STOPPED "
}

cleanup() {
    tmux set-option status-right "$ORIGINAL_STATUS_RIGHT"
    tmux set-option status-interval "$ORIGINAL_STATUS_INTERVAL"
    set_status_stopped
    echo -e "\n🛑 AI MONITOR PAUSED."
    echo "Total session cost: $(cat "$COST_FILE" 2>/dev/null || echo '$0.0000')"
    rm -f "$SESSION_FILE"
    echo "To resume analysis, type: start_monitor"
    exit 0
}

trap cleanup SIGINT SIGTERM

tmux set-option status-interval 5
tmux set-option status-right "#(cat ${COST_FILE}) | $(hostname) | %H:%M "

set_status_waiting

echo "🚀 ai-monitored-shell Active [Model: $CURRENT_MODEL]"
echo "Session file: $SESSION_FILE"
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
            
            set_status_thinking

            PROMPT_FILE=$(mktemp)
            printf 'Rules:\n%s\n\nContext:\n%s\n' "$(cat "$INSTRUCTIONS")" "$CLEAN_CHUNK" > "$PROMPT_FILE"

            echo ""
            echo "--- Analyzing ${NEW_CONTENT_COUNT} lines ---"
            if [ -s "$SESSION_FILE" ]; then
                RESUME_FLAG="--resume $(cat "$SESSION_FILE")"
            else
                RESUME_FLAG=""
            fi
            RESPONSE=$(timeout 120 claude $RESUME_FLAG -p "$(cat "$PROMPT_FILE")" --output-format json </dev/null 2>/dev/null)
            EXIT_CODE=$?
            rm -f "$PROMPT_FILE"
            if [ "$EXIT_CODE" -eq 0 ] && [ -n "$RESPONSE" ]; then
                jq -r '.session_id // empty' <<< "$RESPONSE" > "$SESSION_FILE" 2>/dev/null
                CALL_COST=$(jq -r '.total_cost_usd // 0' <<< "$RESPONSE" 2>/dev/null || echo "0")
                PREV_COST=$(cat "$COST_FILE" 2>/dev/null | tr -d '$' || echo "0")
                printf '$%.4f' "$(awk "BEGIN {printf \"%.4f\", $PREV_COST + $CALL_COST}")" > "$COST_FILE"
                jq -r '.result // .' <<< "$RESPONSE" 2>/dev/null || echo "$RESPONSE"
            else
                echo "⚠️  claude -p failed or timed out (exit: $EXIT_CODE)"
                CALL_COST=0
            fi
            echo "--- Done [cost: \$$(printf '%.4f' "$CALL_COST")] ---"

            set_status_waiting
            LAST_LINE=$TOTAL_LINES
        fi
    fi
done