#!/usr/bin/env bash
set -euo pipefail
DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$DOTFILES_DIR/scripts/lib.sh"

if have_cmd brew; then
  log "Homebrew already installed, updating"
  brew update
else
  log "installing Homebrew"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Locate brew regardless of OS/arch and make it available for the rest of this run.
for candidate in /opt/homebrew/bin/brew /usr/local/bin/brew /home/linuxbrew/.linuxbrew/bin/brew; do
  if [[ -x "$candidate" ]]; then
    eval "$("$candidate" shellenv)"
    break
  fi
done

have_cmd brew || die "Homebrew installation failed or brew not found on PATH"
