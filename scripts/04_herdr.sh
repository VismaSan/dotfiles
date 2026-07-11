#!/usr/bin/env bash
set -euo pipefail
DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$DOTFILES_DIR/scripts/lib.sh"

# herdr's installer is self-updating in place, so this is always safe to rerun
# and doubles as the "update if present" step.
log "installing/updating herdr"
curl -fsSL https://herdr.dev/install.sh | sh

if have_cmd herdr; then
  log "wiring herdr's claude integration"
  herdr integration install claude || log "warning: herdr claude integration install failed (safe to rerun)"
else
  die "herdr install failed — herdr not found on PATH after install"
fi
