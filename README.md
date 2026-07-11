# dotfiles

Personal terminal environment: zsh + oh-my-zsh + powerlevel10k, tmux (+TPM), Neovim,
[herdr](https://herdr.dev), Homebrew-managed CLI tools, and Claude Code settings.

Works on **macOS and Linux**. One command sets up a bare machine, and the same
command is safe to re-run any time to bring an existing machine up to date —
this isn't just a fresh-install script.

## Usage

```sh
git clone <this-repo-url> ~/dotfiles   # or clone it anywhere you like
cd ~/dotfiles
./install.sh
```

Re-run `./install.sh` whenever you want to pick up updates (newer Homebrew
formulae, latest powerlevel10k/TPM/nvim commits, etc.) — every step installs
what's missing and updates what's already there.

## Prerequisites

- **SSH key registered with GitHub** on the new machine, before running
  `install.sh` — the Neovim config (`git@github.com:VismaSan/nvim.git`) is
  cloned over SSH.
- macOS or Linux. (Windows/WSL is untested — treat as Linux at your own risk.)

## What gets set up

| Piece | How |
|---|---|
| Homebrew | official installer if missing, `brew update` if present |
| CLI tools | `brew bundle --file=Brewfile --upgrade` (see `Brewfile`) |
| oh-my-zsh + powerlevel10k | official installer / `git pull` on the p10k theme repo |
| `.zshrc`, `.p10k.zsh`, `.tmux.conf` | symlinked from this repo into `$HOME` |
| herdr | official installer (self-updating), plus `herdr integration install claude` |
| tmux plugins (TPM, dracula/tmux) | TPM cloned/pulled, `install_plugins` + `update_plugins all` |
| Neovim config | cloned/pulled from `VismaSan/nvim`, `lazy.nvim` synced headlessly |
| .NET SDK + global tools | cross-platform `dotnet-install.sh`, then `dotnet-format`/`csharpier` |
| Claude Code settings | `settings.json`, `skills/`, `statusline-command.sh`, plugin config symlinked into `~/.claude` |
| Nerd Font | Homebrew cask on macOS, downloaded + `fc-cache`'d on Linux |
| Default shell | `chsh` to the Homebrew-installed `zsh` |

## The one manual step

Set your terminal app's font to **"Hack Nerd Font"** in its preferences —
there's no scriptable, cross-platform way to do this from a terminal, since
it's a GUI setting per terminal emulator. The font file itself is installed
automatically (see table above); you just need to select it.

## OS-specific notes

- **Linux:** `postgresql@14` and `mono` may build from source on first run
  (no bottle for every distro) and can take a while. There's no scripted
  terminal-emulator install on Linux — iTerm2 (used on macOS) has no Linux
  equivalent, so use whatever your distro/desktop provides.
- **macOS:** iTerm2 is installed via Homebrew cask (`cask "iterm2"`).

## Known companion fix (separate repo)

`VismaSan/nvim`'s `lua/visma/core/options.lua` currently hardcodes a stale
Linux path (`/home/vsanda/.dotnet/tools`) onto `PATH`. This should be fixed
in the nvim repo itself (not here) to something portable, e.g.:

```lua
vim.env.PATH = vim.env.PATH .. ":" .. vim.env.HOME .. "/.dotnet/tools"
```

## What's intentionally excluded

- `~/.claude.json`, `~/.claude/security/`, `~/.claude/session-env/`,
  `~/.claude/history.jsonl`, `sessions/`, `projects/`, and other cache/session
  state — machine-local or contains auth tokens, never symlinked or committed
  (see `.gitignore` and `scripts/07_claude.sh`, which only symlinks specific
  known-safe leaf files).
- `~/.config/nvim-safed` — an inactive, separate Neovim config, out of scope.
- `~/.claude/plugins/marketplaces/` — fetched cache of each marketplace's
  upstream repo (hundreds of files, managed by Claude Code itself); rebuilt
  automatically from `settings.json`'s `extraKnownMarketplaces` +
  `enabledPlugins`, so it's never symlinked or committed here.
- `starship` — installed via Homebrew for parity with the source machine's
  `brew leaves`, but not actually wired into `.zshrc` (powerlevel10k is the
  active prompt). Kept in the Brewfile in case that changes; harmless if not
  used.
