#!/bin/bash

# Updated Session Name
SESSION="ai-monitored-shell"
LOG_FILE="$(pwd)/tmux_session.log"

touch "$LOG_FILE"
> "$LOG_FILE"

tmux new-session -d -s "$SESSION"

# Pane 1: Main Shell
tmux send-keys -t "$SESSION" "echo '===================================================='" C-m
tmux send-keys -t "$SESSION" "echo '🤖 AI-MONITORED-SHELL: ONLINE'" C-m
tmux send-keys -t "$SESSION" "echo '----------------------------------------------------'" C-m
tmux send-keys -t "$SESSION" "echo 'AI CONTROL:'" C-m
tmux send-keys -t "$SESSION" "echo '  - STOP AI:   Type stop_monitor'" C-m
tmux send-keys -t "$SESSION" "echo '  - START AI:  Type start_monitor'" C-m
tmux send-keys -t "$SESSION" "echo ''" C-m
tmux send-keys -t "$SESSION" "echo 'EXIT EVERYTHING: Ctrl+B then :kill-session'" C-m
tmux send-keys -t "$SESSION" "echo '===================================================='" C-m
tmux send-keys -t "$SESSION" "script -f $LOG_FILE" C-m

# Pane 2: The AI Monitor
tmux split-window -h -t "$SESSION"
tmux send-keys -t "$SESSION" "./claude_monitor.sh $LOG_FILE" C-m

# Define start/stop aliases in user shell
tmux send-keys -t "${SESSION}:0.0" "alias start_monitor='tmux send-keys -t ${SESSION}:0.1 \"./claude_monitor.sh ${LOG_FILE}\" C-m'" C-m
tmux send-keys -t "${SESSION}:0.0" "alias stop_monitor='tmux send-keys -t ${SESSION}:0.1 C-c'" C-m

# Focus back on user shell
tmux select-pane -t 0
tmux attach-session -t "$SESSION"