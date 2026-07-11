#!/usr/bin/env bash
set -euo pipefail
DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$DOTFILES_DIR/scripts/lib.sh"

mkdir -p "$HOME/.claude/plugins"

# Only specific leaf files/dirs are symlinked — never the whole ~/.claude or
# ~/.claude/plugins directory — so machine-local state (cache/, sessions/,
# history.jsonl, security/, etc.) keeps living as ordinary local files and can
# never end up inside this repo's working tree.
link "$DOTFILES_DIR/claude/settings.json"         "$HOME/.claude/settings.json"
link "$DOTFILES_DIR/claude/statusline-command.sh" "$HOME/.claude/statusline-command.sh"
link "$DOTFILES_DIR/claude/skills"                "$HOME/.claude/skills"

link "$DOTFILES_DIR/claude/plugins/installed_plugins.json"  "$HOME/.claude/plugins/installed_plugins.json"
link "$DOTFILES_DIR/claude/plugins/known_marketplaces.json" "$HOME/.claude/plugins/known_marketplaces.json"

# plugins/marketplaces/ is deliberately NOT symlinked here: it's a fetched
# cache of each marketplace's upstream repo content (hundreds of files,
# managed by Claude Code itself via a .gcs-sha marker), reconstructible from
# settings.json's extraKnownMarketplaces + enabledPlugins. Claude Code
# re-fetches it on demand — committing it would just be dead weight.
