#!/usr/bin/env bash
set -euo pipefail
DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$DOTFILES_DIR/scripts/lib.sh"

have_cmd zsh || die "zsh not found on PATH — Homebrew step should have installed it"
ZSH_PATH="$(command -v zsh)"

if ! grep -qxF "$ZSH_PATH" /etc/shells 2>/dev/null; then
  log "registering $ZSH_PATH in /etc/shells (requires sudo)"
  echo "$ZSH_PATH" | sudo tee -a /etc/shells >/dev/null
fi

if [[ "${SHELL:-}" != "$ZSH_PATH" ]]; then
  log "setting default shell to $ZSH_PATH (requires your login password)"
  chsh -s "$ZSH_PATH"
else
  log "default shell already $ZSH_PATH"
fi
