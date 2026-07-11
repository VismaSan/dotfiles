#!/usr/bin/env bash
set -euo pipefail
DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$DOTFILES_DIR/scripts/lib.sh"

case "$(os)" in
  macos)
    log "font handled by 'cask \"font-hack-nerd-font\"' in the Brewfile (on_macos block) — nothing to do here"
    ;;
  linux)
    FONT_DIR="$HOME/.local/share/fonts"
    mkdir -p "$FONT_DIR"
    if fc-list 2>/dev/null | grep -qi "Hack Nerd Font"; then
      log "Hack Nerd Font already installed"
    else
      log "installing Hack Nerd Font"
      curl -fsSL -o /tmp/HackNerdFont.zip \
        https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Hack.zip
      unzip -oq /tmp/HackNerdFont.zip -d "$FONT_DIR"
      rm -f /tmp/HackNerdFont.zip
      fc-cache -f "$FONT_DIR" >/dev/null 2>&1 || true
    fi
    ;;
esac
