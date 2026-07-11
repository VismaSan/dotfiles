#!/usr/bin/env bash
set -euo pipefail
DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$DOTFILES_DIR/scripts/lib.sh"

git_clone_or_pull "git@github.com:VismaSan/nvim.git" "$HOME/.config/nvim"

if have_cmd nvim; then
  log "priming lazy.nvim (install missing + update pinned plugins)"
  nvim --headless "+Lazy! sync" +qa || log "warning: headless Lazy sync reported an issue, check nvim manually"
else
  log "warning: nvim not found on PATH yet, skipping Lazy sync (run 'nvim --headless \"+Lazy! sync\" +qa' manually)"
fi

# dotnet SDK — cross-platform official installer, replaces the macOS-only
# dotnet-sdk cask used on the source machine.
if ! have_cmd dotnet; then
  log "installing .NET SDK"
  curl -fsSL https://dot.net/v1/dotnet-install.sh | bash -s -- --channel LTS --install-dir "$HOME/.dotnet"
  export PATH="$HOME/.dotnet:$PATH"
fi

if have_cmd dotnet; then
  log "installing/updating dotnet global tools"
  dotnet tool update -g dotnet-format 2>/dev/null || dotnet tool install -g dotnet-format
  dotnet tool update -g csharpier 2>/dev/null || dotnet tool install -g csharpier
else
  log "warning: dotnet still not on PATH, skipping global tools (dotnet-format, csharpier)"
fi

# NOTE: lua/visma/core/options.lua in the VismaSan/nvim repo hardcodes a stale
# Linux path (/home/vsanda/.dotnet/tools) onto PATH. That's a companion fix
# that belongs in the nvim repo itself, not here — see README.md.
