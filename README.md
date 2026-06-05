# 🤖 Claude Code Statusline

Pretty 3-line statusline for Claude Code with ANSI 256-color support.

![statusline](https://img.shields.io/badge/Claude_Code-Statusline-blue?style=flat-square)

## Preview

```
🤖 Opus 4.8  ⚡high  v2.1.90
📁 ~/projects/my-app  🌿 main ✅  🔗 #1234 ✓approved
🧠 [########------------] 40%  📝 +42 -7  💰 $1.23  ⏱️ 12m 34s  📊 23% · 41%
```

## Features

- **Line 1**: Model name + reasoning effort (⚡, when supported) + CLI version
- **Line 2**: Working directory + Git branch & status (clean ✅ / dirty ✏️) + open PR badge with review state (clickable via OSC 8)
- **Line 3**: Context usage bar + lines changed + cost + session duration + Pro/Max rate limits (📊, when present)

Git lookups are cached per session (5s TTL) to keep the status line fast, and `refreshInterval` keeps the duration ticking while the session is idle. PR and rate-limit segments only appear when Claude Code provides that data.

## Install

```bash
git clone https://github.com/fotoner/claude-statusline.git
cd claude-statusline
bash install.sh
```

Or manually:
```bash
cp statusline-command.sh ~/.claude/statusline-command.sh
chmod +x ~/.claude/statusline-command.sh
```

Then add to `~/.claude/settings.json`:
```json
{
  "statusLine": {
    "type": "command",
    "command": "bash ~/.claude/statusline-command.sh",
    "refreshInterval": 3
  }
}
```

## Requirements

- `jq` — JSON parser
- `git` — for branch/status display
- Bash 4+
- Terminal with 256-color support

## Color Palette

| Element | Color | Code |
|---------|-------|------|
| Model name | Cyan | `38;5;117` |
| Effort / Cost | Yellow | `38;5;222` |
| Directory / PR / Rate limits | Blue | `38;5;153` |
| Branch | Magenta | `38;5;183` |
| Context (ok) | Green | `38;5;151` |
| Context (warn) | Yellow | `38;5;222` |
| Context (critical) | Red | `38;5;210` |
| Lines changed | Pink | `38;5;218` |
| Cost | Yellow | `38;5;222` |
| Duration | Green | `38;5;151` |

## License

MIT
