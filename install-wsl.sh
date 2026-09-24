#!/usr/bin/env bash
# install-wsl.sh - install WSL dependencies and link shared configs into WSL $HOME.
# Idempotent: safe to re-run after every git pull.

set -euo pipefail

REPO="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"

NOBACKUP=0
for arg in "$@"; do
    case "$arg" in
        --no-backup) NOBACKUP=1 ;;
        -h|--help)
            echo "Usage: $0 [--no-backup]"
            echo "  --no-backup  Replace existing configs without creating .bak.* backups"
            exit 0
            ;;
    esac
done

link() {
    local src="$(readlink -f "$1/$2")" tgt="$3"
    [ -L "$tgt" ] && [ "$(readlink -f "$tgt")" = "$src" ] && return 0
    mkdir -p "$(dirname "$tgt")"
    if [ -e "$tgt" ] || [ -L "$tgt" ]; then
        if [ "$NOBACKUP" -eq 1 ]; then
            rm -rf "$tgt"
        else
            mv "$tgt" "$tgt.bak.$(date +%s)"
        fi
    fi
    ln -s "$src" "$tgt"
}

export PATH="$HOME/.local/bin:$PATH"

# dependencies
packages=(
    base-devel
    bat
    curl
    eza
    fastfetch
    fd
    fzf
    git
    lazygit
    less
    mise
    neovim
    openssh
    ripgrep
    tmux
    unzip
    yazi
    zoxide
    zsh
)

# win32yank
if ! command -v win32yank.exe >/dev/null 2>&1; then
    echo '  installing win32yank'
    mkdir -p "$HOME/.local/bin"
    curl -fsSL \
        https://github.com/equalsraf/win32yank/releases/latest/download/win32yank-x64.zip \
        -o /tmp/win32yank.zip
    unzip -o /tmp/win32yank.zip -d "$HOME/.local/bin" >/dev/null
    chmod +x "$HOME/.local/bin/win32yank.exe"
    rm -f /tmp/win32yank.zip
fi

missing=()
for pkg in "${packages[@]}"; do
    pacman -Q "$pkg" &>/dev/null || missing+=("$pkg")
done

if [ "${#missing[@]}" -gt 0 ]; then
    echo "  installing: ${missing[*]}"
    sudo pacman -S --needed --noconfirm "${missing[@]}"
fi

# AUR helper
if ! command -v paru >/dev/null 2>&1; then
    echo '  installing paru'
     tmpdir="$(mktemp -d)"
    git clone -q https://aur.archlinux.org/paru.git "$tmpdir/paru"
     (
        cd "$tmpdir/paru"
         makepkg -si --noconfirm
     )
     rm -rf "$tmpdir"
 fi

# Remove yay if it was previously installed.
if pacman -Q yay &>/dev/null; then
    echo '  removing yay'
    sudo pacman -Rns --noconfirm yay
fi

# link configs
link "$REPO/wsl/zsh" .zshenv "$HOME/.zshenv"
link "$REPO/wsl/zsh" .config/zsh "$HOME/.config/zsh"
link "$REPO/wsl/tmux" . "$HOME/.config/tmux"
link "$REPO/nvim" . "$HOME/.config/nvim"
link "$REPO/bat" . "$HOME/.config/bat"
link "$REPO/lazygit" . "$HOME/.config/lazygit"
link "$REPO/wsl/opencode" . "$HOME/.config/opencode"
link "$REPO/starship" starship.toml "$HOME/.config/starship.toml"
link "$REPO/fastfetch" . "$HOME/.config/fastfetch"
link "$REPO/yazi" . "$HOME/.config/yazi"
link "$REPO/mise" . "$HOME/.config/mise"
link "$REPO" .gitconfig "$HOME/.gitconfig"

mise install

# migrate: ~/.tmux.conf moved to ~/.config/tmux
old_conf="$(readlink -f "$HOME/.tmux.conf" 2>/dev/null || true)"
case "$old_conf" in
    "$REPO"/*) rm "$HOME/.tmux.conf" ;;
esac

# tpm + tmux plugins: with a config at ~/.config/tmux, TPM keeps plugins
# there too. Clone anything declared as "@plugin 'owner/repo'".
plugins_dir="$HOME/.config/tmux/plugins"
if [ ! -d "$plugins_dir/tpm" ]; then
    echo '  installing tpm'
    git clone -q https://github.com/tmux-plugins/tpm "$plugins_dir/tpm"
fi
conf="$HOME/.config/tmux/tmux.conf"
[ -f "$conf" ] && while IFS= read -r repo; do
    name="${repo##*/}"
    [ -d "$plugins_dir/$name" ] || \
        git clone -q "https://github.com/$repo" "$plugins_dir/$name"
done < <(sed -n "s/^set -g @plugin '\([^']*\)'.*/\1/p" "$conf")

# bat cache
command -v bat >/dev/null 2>&1 && bat cache --build >/dev/null 2>&1

# opencode
if [ -x "$HOME/.opencode/bin/opencode" ]; then
    mkdir -p "$HOME/.local/bin"
    ln -sfn "$HOME/.opencode/bin/opencode" "$HOME/.local/bin/opencode"
elif ! command -v opencode >/dev/null 2>&1; then
    echo '  installing opencode'
    curl -fsSL https://opencode.ai/install | bash -s -- --no-modify-path
    mkdir -p "$HOME/.local/bin"
    ln -sfn "$HOME/.opencode/bin/opencode" "$HOME/.local/bin/opencode"
fi

sed -i "\|^export PATH=$HOME/\.opencode/bin:\$PATH$|d" "$HOME/.zshenv"

# check requirements
missing=0
for bin in zsh tmux nvim starship bat lazygit opencode fastfetch paru win32yank.exe; do
     command -v "$bin" >/dev/null 2>&1 || { echo "  $bin missing"; missing=1; }
done
[ "$missing" -eq 0 ] || echo '  some requirements missing - see README.md'

echo ''
echo 'Done.'
echo ''
echo 'Next steps:'
echo '  exec zsh'
echo '  chsh -s /usr/bin/zsh'
echo ''
