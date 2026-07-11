#!/usr/bin/env bash
set -euo pipefail
DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$DOTFILES_DIR/scripts/lib.sh"

# herdr's installer is self-updating in place, so this is always safe to rerun
# and doubles as the "update if present" step.
log "installing/updating herdr"
curl -fsSL https://herdr.dev/install.sh | sh

# Must run after 04_claude.sh: this patches ~/.claude/settings.json in place
# with a machine-correct hook path (~/.claude/hooks/herdr-agent-state.sh).
# Since settings.json is a symlink into this repo, whichever step runs last
# is what ends up committed — running this before the claude symlink step
# would let 04_claude.sh clobber the correct, local hook path with whatever
# was last committed from a different machine.
if have_cmd herdr; then
  log "wiring herdr's claude integration"
  herdr integration install claude || log "warning: herdr claude integration install failed (safe to rerun)"
else
  die "herdr install failed — herdr not found on PATH after install"
fi

link "$DOTFILES_DIR/herdr/config.toml" "$HOME/.config/herdr/config.toml"
