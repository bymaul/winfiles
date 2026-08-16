# winfiles

Windows and WSL dotfiles.

## Layout

```
nvim/ starship/ bat/ lazygit/ opencode/   # cross-platform (root)
wsl/zsh/ wsl/tmux/                         # WSL-only
windows/                                   # native Windows (PowerShell, Windows Terminal)
install.ps1  install-wsl.sh
```

## Windows

Fresh machine, elevated PowerShell 7:

```powershell
git clone https://github.com/bymaul/winfiles
cd winfiles
.\install.ps1    # links configs (junctions), installs the toolchain (choco + winget), sets up WSL + Arch
```

Re-run `.\install.ps1` after every `git pull` to re-link and update.

## WSL

No second clone needed on the same machine - the Windows copy is already
visible to WSL at `/mnt/c/Users/Maulana/winfiles`:

```sh
/mnt/c/Users/Maulana/winfiles/install-wsl.sh
exec zsh
chsh -s /usr/bin/zsh   # once: make zsh the default shell
```

On a WSL-only machine, clone once and run:

```sh
git clone https://github.com/bymaul/winfiles
~/winfiles/install-wsl.sh
exec zsh
chsh -s /usr/bin/zsh   # once: make zsh the default shell
```

## Requirements

- WSL: `zsh`, `tmux`, `nvim`, `starship`, `bat`, `lazygit`.
- On Windows, nvim needs a C toolchain for treesitter parsers - see
  `nvim/README.md`.
