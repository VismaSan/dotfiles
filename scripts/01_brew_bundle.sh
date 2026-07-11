#!/usr/bin/env bash
set -euo pipefail
DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$DOTFILES_DIR/scripts/lib.sh"

have_cmd brew || die "Homebrew not found on PATH — run 00_homebrew.sh first"

brew update
brew bundle --file="$DOTFILES_DIR/Brewfile" --upgrade
