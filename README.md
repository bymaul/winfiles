# winfiles

Windows and WSL dotfiles, the Windows-side half of a two-repo setup.

| repo | purpose |
| --- | --- |
| [`bymaul/dotfiles`](https://github.com/bymaul/dotfiles) | Linux desktop (Hyprland). Canonical home of the shared configs. |
| `bymaul/winfiles` | this repo: WSL + native Windows |

The seven shared packages (`nvim`, `starship`, `bat`, `lazygit`, `opencode`,
`zsh`, `tmux`) are synced bidirectionally by `.github/workflows/sync.yml`. The
cross-platform ones live at the repo root; the WSL-only ones (`zsh`, `tmux`)
live under `wsl/`. Desktop-only configs (hypr, waybar, mako, rofi, kitty,
wleave, gtk, vague-theme, wallpapers, bin, btop, yazi) live only in `dotfiles`.

```
winfiles/
├── nvim/ starship/ bat/ lazygit/ opencode/   # cross-platform (root)
├── wsl/zsh/ wsl/tmux/                         # WSL-only
├── windows/                                   # native Windows
├── install-wsl.sh  install.ps1
└── .github/workflows/sync.yml
```

## Install

### WSL (Linux)

```sh
git clone https://github.com/bymaul/winfiles ~/winfiles
# install requirements (zsh, tmux, nvim, starship, bat, lazygit), then:
~/winfiles/install-wsl.sh
exec zsh
chsh -s /usr/bin/zsh   # once: make zsh the default shell
```

`install-wsl.sh` uses GNU Stow when available and falls back to plain symlinks
otherwise. The zsh bootstrap sets `ZDOTDIR` to `~/.config/zsh`, exactly like the
desktop. It is idempotent: re-run it after every `git pull`.

### Native Windows (PowerShell)

```powershell
git clone https://github.com/bymaul/winfiles $HOME\winfiles
Set-Location $HOME\winfiles
.\install.ps1
```

`install.ps1` creates directory junctions (no admin needed) for the five
cross-platform packages (`nvim` -> `%LOCALAPPDATA%\nvim`, `bat` ->
`%APPDATA%\bat`, `lazygit` -> `%APPDATA%\lazygit`, `starship` ->
`%APPDATA%\starship`, `opencode` -> `%USERPROFILE%\.config\opencode`) plus the
`windows/` items: the PowerShell profile and Windows Terminal settings. Existing
directories are backed up to `.bak` before being replaced. Re-run after every
`git pull`.

`zsh` and `tmux` are Linux-only and are not installed on native Windows. On
Windows, nvim needs a C toolchain for treesitter parsers - see
`nvim/README.md`.

## Sync flow

A push to `master` touching any shared package opens a sync PR in the other repo
via the `GH_TOKEN` secret (PAT with `repo` scope, set in both repos). The PR
auto-merges when clean; on conflict it stays open for manual resolution. An
empty diff produces no PR, which keeps the loop between the two repos safe.

`dotfiles` keeps the shared configs flat at its root, so `zsh`/`tmux` are
mapped between `wsl/zsh`/`wsl/tmux` here and `zsh`/`tmux` there during sync.

Line endings are pinned to LF (`.gitattributes`, `core.autocrlf=false`) so
synced files stay byte-identical across platforms.
