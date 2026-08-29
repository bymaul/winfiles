#!/usr/bin/env bash
# install-wsl.sh - install WSL dependencies and link shared configs into WSL $HOME.
# Idempotent: safe to re-run after every git pull.

set -euo pipefail

REPO="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"

link() {
    local src="$(readlink -f "$1/$2")" tgt="$3"
    [ -L "$tgt" ] && [ "$(readlink -f "$tgt")" = "$src" ] && return 0
    mkdir -p "$(dirname "$tgt")"
    if [ -e "$tgt" ] || [ -L "$tgt" ]; then
        mv "$tgt" "$tgt.bak.$(date +%s)"
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
    fnm
    fzf
    git
    lazygit
    less
    neovim
    openssh
    ripgrep
    tmux
    zoxide
    zsh
)

missing=()
for pkg in "${packages[@]}"; do
    pacman -Q "$pkg" &>/dev/null || missing+=("$pkg")
done

if [ "${#missing[@]}" -gt 0 ]; then
    echo "  installing: ${missing[*]}"
    sudo pacman -S --needed --noconfirm "${missing[@]}"
fi

# AUR helper
if ! command -v yay >/dev/null 2>&1; then
    echo '  installing yay'
    tmpdir="$(mktemp -d)"
    git clone -q https://aur.archlinux.org/yay.git "$tmpdir/yay"
    (
        cd "$tmpdir/yay"
        makepkg -si --noconfirm
    )
    rm -rf "$tmpdir"
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

# check requirements
missing=0
for bin in zsh tmux nvim starship bat lazygit opencode fastfetch yay; do
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
