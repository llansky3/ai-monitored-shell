# ai-monitored-shell

A tmux-based shell session where Claude automatically analyzes your terminal output after each command.

## Requirements

- `tmux`, `inotify-tools`, `jq`
- `claude` CLI authenticated and on `$PATH`

## Usage

```bash
./ai_monitored_shell.sh
```

## Layout

```
┌─────────────────────────┬──────────────┐
│      SHELL (bash)       │  AI MONITOR  │
│                         ├──────────────┤
│                         │   AI CHAT    │
└─────────────────────────┴──────────────┘
```

Each pane has a visible title. The tmux status bar shows:
- **Left**: `WAITING FOR USER INPUT` (green) / `AI IS THINKING` (red) / `AI MONITORING STOPPED` (red)
- **Right**: accumulated session cost | hostname | time

## How it works

- **SHELL (left)** — interactive bash recorded via `script -f`; aliases and banner injected via `--init-file`
- **AI MONITOR (top-right)** — watches the log with `inotifywait`, detects prompt reappearance, strips ANSI/CR noise, sends output to `claude -p` for analysis; all calls share one Claude session via `--resume`
- **AI CHAT (bottom-right)** — ask follow-up questions in the same Claude session; cost is tracked alongside the monitor

Cost per call is extracted from `--output-format json` and accumulated in `.claude_session_cost`, which the status bar reads every 5 seconds.

## Controls

| Command | Action |
|---|---|
| `stop_monitor` | Pause AI analysis, print total session cost |
| `start_monitor` | Resume AI analysis |
| `quit` | Kill the entire tmux session |
| `Ctrl+B →` then `Ctrl+B ↓` | Focus the AI CHAT pane |

## Files

| File | Purpose |
|---|---|
| `ai_monitored_shell.sh` | Entry point — session setup, pane layout, init script |
| `claude_monitor.sh` | Log watcher, analysis trigger, status bar manager |
| `claude_chat.sh` | Interactive chat sharing the monitor's Claude session |
| `analysis_instructions.md` | System prompt passed to Claude on every analysis |
| `tmux_session.log` | Shell session log (gitignored) |
| `.claude_session_id` | Shared Claude session ID (gitignored) |
| `.claude_session_cost` | Running cost total read by status bar (gitignored) |
