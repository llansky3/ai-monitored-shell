# ai-monitored-shell

A tmux-based shell session where Claude automatically analyzes your terminal output after each command.

## How it works

- **Left pane** — your normal shell, recorded via `script -f` to a log file in the current directory
- **Right pane** — `claude_monitor.sh` watches the log with `inotifywait`, detects when a command finishes (prompt reappears), strips ANSI/CR noise, and sends the output to `claude -p` for analysis
- The tmux status bar turns red while Claude is thinking

## Requirements

- `tmux`
- `inotifywait` (package: `inotify-tools`)
- `claude` CLI authenticated and on `$PATH`

## Usage

```bash
./ai_monitored_shell.sh
```

This creates a tmux session named `ai-monitored-shell` and attaches to it.

## Controls (from the user shell)

| Command | Action |
|---|---|
| `stop_monitor` | Pause AI analysis (shows session cost) |
| `start_monitor` | Resume AI analysis |
| `Ctrl+B` then `:kill-session` | Exit everything |

## Files

| File | Purpose |
|---|---|
| `ai_monitored_shell.sh` | Entry point — creates tmux session, starts monitor, injects aliases |
| `claude_monitor.sh` | Watches log, triggers Claude on each completed command |
| `analysis_instructions.md` | System prompt / rules passed to Claude on every analysis |
| `tmux_session.log` | Live log of the shell session (created at startup, gitignored) |
