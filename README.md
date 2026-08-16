# winfiles

Windows and WSL dotfiles.

## Layout

```
nvim/ starship/ bat/ lazygit/                # cross-platform (root)
wsl/zsh/ wsl/tmux/ wsl/opencode/              # WSL-only
windows/                                     # native Windows (PowerShell, Windows Terminal)
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

Same machine as the Windows clone? No second clone - run the mounted copy:

```sh
/mnt/c/Users/$USER/winfiles/install-wsl.sh
```

WSL-only machine? Clone once:

```sh
git clone https://github.com/bymaul/winfiles
cd winfiles
./install-wsl.sh
```

Then:

```sh
exec zsh
chsh -s /usr/bin/zsh   # once: make zsh the default shell
```

## Requirements

- WSL: `zsh`, `tmux`, `nvim`, `starship`, `bat`, `lazygit`. `opencode` is installed automatically by `install-wsl.sh`.
- On Windows, nvim needs a C toolchain for treesitter parsers - see
  `nvim/README.md`.
