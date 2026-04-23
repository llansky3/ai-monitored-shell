#!/bin/bash

# Updated Session Name
SESSION="ai-monitored-shell"
LOG_FILE="$(pwd)/tmux_session.log"
SESSION_FILE="$(pwd)/.claude_session_id"
COST_FILE="$(pwd)/.claude_session_cost"

touch "$LOG_FILE"
> "$LOG_FILE"
> "$SESSION_FILE"
echo '$0.0000' > "$COST_FILE"

tmux new-session -d -s "$SESSION"
tmux set-option -t "$SESSION" pane-border-status top
tmux set-option -t "$SESSION" pane-border-format " #{pane_title} "

# Write an init script sourced by bash inside the script session
INIT_SCRIPT=$(mktemp /tmp/session_init_XXXXXX.sh)
cat > "$INIT_SCRIPT" <<INITEOF
source ~/.bashrc 2>/dev/null || true
alias start_monitor='tmux send-keys -t ${SESSION}:0.1 "./claude_monitor.sh ${LOG_FILE} ${SESSION_FILE} ${COST_FILE}" C-m'
alias stop_monitor='tmux send-keys -t ${SESSION}:0.1 C-c'
alias quit='tmux kill-session -t ${SESSION}'
clear
echo '===================================================='
echo '🤖 AI-MONITORED-SHELL: ONLINE'
echo '----------------------------------------------------'
echo 'AI CONTROL:'
echo '  - STOP AI:   Type stop_monitor'
echo '  - START AI:  Type start_monitor'
echo ''
echo 'EXIT EVERYTHING: Type quit'
echo '===================================================='
rm -f "${INIT_SCRIPT}"
INITEOF

# Pane 1: Main Shell — bash reads the init file inside the script session
tmux send-keys -t "$SESSION" "script -f $LOG_FILE -c \"bash --init-file $INIT_SCRIPT\"" C-m
tmux select-pane -t "${SESSION}:0.0" -T "SHELL ($(basename $SHELL))"

# Pane 2: The AI Monitor (top-right, 70% of right side)
tmux split-window -h -p 25 -t "$SESSION"
tmux select-pane -t "${SESSION}:0.1" -T "AI MONITOR"
tmux send-keys -t "$SESSION" "./claude_monitor.sh $LOG_FILE $SESSION_FILE $COST_FILE" C-m

# Pane 3: Chat with Claude (bottom-right, 30% of right side)
tmux split-window -v -p 30 -t "${SESSION}:0.1"
tmux select-pane -t "${SESSION}:0.2" -T "AI CHAT"
tmux send-keys -t "${SESSION}:0.2" "./claude_chat.sh $SESSION_FILE $COST_FILE" C-m

# Focus back on user shell
tmux select-pane -t 0
tmux attach-session -t "$SESSION"