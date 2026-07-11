#!/usr/bin/env bash
set -euo pipefail
DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$DOTFILES_DIR/scripts/lib.sh"

git_clone_or_pull "https://github.com/tmux-plugins/tpm" "$HOME/.tmux/plugins/tpm"

log "installing any missing tmux plugins"
"$HOME/.tmux/plugins/tpm/bin/install_plugins"

log "updating already-installed tmux plugins"
"$HOME/.tmux/plugins/tpm/bin/update_plugins" all
