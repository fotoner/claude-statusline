#!/usr/bin/env bash
# Install Claude Code Statusline
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
SETTINGS="$CLAUDE_DIR/settings.json"
TARGET="$CLAUDE_DIR/statusline-command.sh"

mkdir -p "$CLAUDE_DIR"

# Copy script
cp "$SCRIPT_DIR/statusline-command.sh" "$TARGET"
chmod +x "$TARGET"
echo "✅ Installed statusline-command.sh → $TARGET"

# Update settings.json
if [ -f "$SETTINGS" ]; then
  # Preserve existing settings, add/overwrite statusLine
  tmp="$(mktemp)"
  jq '.statusLine = {"type": "command", "command": "bash ~/.claude/statusline-command.sh"}' "$SETTINGS" > "$tmp"
  mv "$tmp" "$SETTINGS"
  echo "✅ Updated $SETTINGS (existing settings preserved)"
else
  cat > "$SETTINGS" <<'EOF'
{
  "statusLine": {
    "type": "command",
    "command": "bash ~/.claude/statusline-command.sh"
  }
}
EOF
  echo "✅ Created $SETTINGS"
fi

echo "🎉 Done! Restart Claude Code to see the new statusline."
