# Cross-platform CLI tools — install via Homebrew formula on both macOS and Linux
brew "eza"
brew "fd"                # gap-fix: missing on source machine, needed by nvim's Telescope
brew "fzf"
brew "gh"
brew "git"
brew "git-lfs"
brew "go"
brew "lazygit"
brew "neovim"
brew "node"               # gap-fix: missing on source machine, needed by Mason (ts_ls/eslint/jsonls/dockerls)
brew "p7zip"
brew "ripgrep"
brew "tmux"
brew "zsh"
brew "cloudflared"
brew "mkcert"
brew "pgpdump"
brew "postgresql@14"
brew "starship"           # currently unreferenced in .zshrc; kept for parity, see README
brew "supabase/tap/supabase"

if OS.mac?
  brew "mono"
  cask "font-hack-nerd-font"
  cask "iterm2"
end

if OS.linux?
  # dotnet SDK, gcloud CLI, and ngrok are installed via their own cross-platform
  # vendor scripts (see scripts/06_nvim.sh and README) rather than here, since
  # they either have no Linux cask equivalent or a better-maintained official
  # installer that already handles both OSes uniformly. There is no scripted
  # terminal-emulator install on Linux (iTerm2 is macOS-only and wasn't part of
  # what's actually used day-to-day) — use whatever your distro/desktop provides.
end
