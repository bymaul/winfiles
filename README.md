# winfiles

Windows and WSL dotfiles. Shared configs sync with
[dotfiles](https://github.com/bymaul/dotfiles); desktop-only configs
(hypr, waybar, kitty, vague-theme, ...) live only there.

## Layout

```
nvim/ starship/ bat/ lazygit/ opencode/   # cross-platform (root)
wsl/zsh/ wsl/tmux/                         # WSL-only
windows/                                   # native Windows (PowerShell, Windows Terminal)
```

## Windows

Fresh machine, elevated PowerShell:

```powershell
git clone https://github.com/bymaul/winfiles $HOME\winfiles
Set-Location $HOME\winfiles
.\install.ps1    # links configs, installs the coding toolchain (choco + winget)
```

After a pull, just re-run `.\install.ps1` to re-link and update.

## WSL

```sh
git clone https://github.com/bymaul/winfiles ~/winfiles
~/winfiles/install-wsl.sh
exec zsh
chsh -s /usr/bin/zsh   # once: make zsh the default shell
```

## Requirements

- Windows: a [GitHub PAT](https://github.com/settings/tokens) as the `GH_TOKEN`
  secret in both repos (repo scope) for the sync workflow.
- WSL: `zsh`, `tmux`, `nvim`, `starship`, `bat`, `lazygit`.
- On Windows, nvim needs a C toolchain for treesitter parsers - see
  `nvim/README.md`.

## Sync

`nvim`, `starship`, `bat`, `lazygit`, `opencode` and the WSL-only `zsh`/`tmux`
sync bidirectionally with `dotfiles` via `.github/workflows/sync.yml`. Line
endings are pinned to LF (`.gitattributes`) so synced files stay byte-identical.
