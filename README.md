# winfiles

Windows and WSL dotfiles.

## Windows

Fresh machine, elevated PowerShell 7:

```powershell
git clone https://github.com/bymaul/winfiles
cd winfiles
.\install.ps1    # links configs, installs the toolchain (scoop + winget), sets up WSL + Arch
```

Re-run after every `git pull`. Existing configs are backed up as
`<name>.bak.<timestamp>`; pass `-NoBackup` to replace them instead.

## WSL

From the Windows clone (no second clone needed):

```sh
/mnt/c/Users/$USER/winfiles/install-wsl.sh
```

Standalone:

```sh
git clone https://github.com/bymaul/winfiles
cd winfiles
./install-wsl.sh
```

Same backup behavior as Windows (`--no-backup` to replace instead).
Re-run after every `git pull`. Then:

```sh
exec zsh
chsh -s /usr/bin/zsh   # once: make zsh the default shell
```

## Requirements

`install-wsl.sh` installs its dependencies automatically.
On Windows, nvim needs a C toolchain for treesitter parsers - see
`nvim/README.md`.
