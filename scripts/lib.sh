#!/usr/bin/env bash
# Shared helpers for dotfiles install scripts. Sourced, not executed directly.

log()     { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
section() { echo; log "$*"; }
have_cmd() { command -v "$1" >/dev/null 2>&1; }
die() { echo "ERROR: $*" >&2; exit 1; }

os() {
  case "$(uname)" in
    Darwin) echo "macos" ;;
    Linux)  echo "linux" ;;
    *) die "Unsupported OS: $(uname)" ;;
  esac
}

# ~/.local/bin and ~/.dotnet hold tools installed outside Homebrew (herdr,
# dotnet). A non-interactive script never sources .zshrc, so PATH has to be
# fixed here too, not just in the symlinked dotfile — otherwise a step run
# later in this same install.sh invocation won't see what an earlier step
# just installed there.
export PATH="$HOME/.local/bin:$HOME/.dotnet:$PATH"

# Symlink src -> dest. No-op if already correctly linked. Backs up any
# pre-existing real file/different link before replacing it.
link() {
  local src="$1" dest="$2"
  if [[ -L "$dest" && "$(readlink "$dest")" == "$src" ]]; then
    log "skip (already linked): $dest"
    return 0
  fi
  if [[ -e "$dest" || -L "$dest" ]]; then
    local backup
    backup="${dest}.bak.$(date +%Y%m%d%H%M%S)"
    log "backing up existing $dest -> $backup"
    mv "$dest" "$backup"
  fi
  mkdir -p "$(dirname "$dest")"
  ln -s "$src" "$dest"
  log "linked $dest -> $src"
}

# Clone a repo if missing, otherwise fast-forward pull. This is the core
# "install if missing, update if present" mechanism for every git-based tool.
git_clone_or_pull() {
  local url="$1" dest="$2"
  if [[ -d "$dest/.git" ]]; then
    log "updating $dest"
    git -C "$dest" pull --ff-only || log "warning: could not fast-forward $dest (local changes?), leaving as-is"
  else
    log "cloning $url -> $dest"
    git clone "$url" "$dest"
  fi
}
