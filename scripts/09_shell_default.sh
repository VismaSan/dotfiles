#!/usr/bin/env bash
set -euo pipefail
DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$DOTFILES_DIR/scripts/lib.sh"

# If the login shell is already some zsh (even if not the exact Homebrew
# binary — e.g. the system /bin/zsh), there's nothing to do: chsh only
# matters for picking *a* zsh, and forcing a switch to the Homebrew build
# would just prompt for a password for no real benefit.
if [[ "$(basename "${SHELL:-}")" == "zsh" ]]; then
  log "default shell is already zsh ($SHELL) — skipping chsh"
else
  have_cmd zsh || die "zsh not found on PATH — Homebrew step should have installed it"
  ZSH_PATH="$(command -v zsh)"

  if ! grep -qxF "$ZSH_PATH" /etc/shells 2>/dev/null; then
    log "registering $ZSH_PATH in /etc/shells (requires sudo)"
    echo "$ZSH_PATH" | sudo tee -a /etc/shells >/dev/null
  fi

  log "setting default shell to $ZSH_PATH (requires your login password)"
  chsh -s "$ZSH_PATH"
fi
