#!/usr/bin/env bash
set -euo pipefail
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export DOTFILES_DIR
source "$DOTFILES_DIR/scripts/lib.sh"

case "$(uname)" in
  Darwin|Linux) ;;
  *) die "Unsupported OS: $(uname). This installer supports macOS and Linux only." ;;
esac

section "Homebrew";         bash "$DOTFILES_DIR/scripts/00_homebrew.sh"
section "Brew bundle";      bash "$DOTFILES_DIR/scripts/01_brew_bundle.sh"
section "oh-my-zsh + p10k"; bash "$DOTFILES_DIR/scripts/02_oh_my_zsh.sh"
section "Dotfile symlinks"; bash "$DOTFILES_DIR/scripts/03_dotfiles_symlink.sh"
section "Claude settings";  bash "$DOTFILES_DIR/scripts/04_claude.sh"
section "herdr";            bash "$DOTFILES_DIR/scripts/05_herdr.sh"
section "tmux + TPM";       bash "$DOTFILES_DIR/scripts/06_tmux_tpm.sh"
section "nvim";             bash "$DOTFILES_DIR/scripts/07_nvim.sh"
section "Fonts";            bash "$DOTFILES_DIR/scripts/08_fonts.sh"
section "Default shell";    bash "$DOTFILES_DIR/scripts/09_shell_default.sh"

echo
log "Done. Manual step remaining: set your terminal app's font to 'Hack Nerd Font'. Then restart your terminal (or run 'exec zsh')."
