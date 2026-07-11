#!/usr/bin/env bash
set -euo pipefail
DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$DOTFILES_DIR/scripts/lib.sh"

link "$DOTFILES_DIR/zsh/zshrc"      "$HOME/.zshrc"
link "$DOTFILES_DIR/zsh/p10k.zsh"   "$HOME/.p10k.zsh"
link "$DOTFILES_DIR/tmux/tmux.conf" "$HOME/.tmux.conf"
