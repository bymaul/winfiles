#!/usr/bin/env bash
# install-wsl.sh - link shared configs into WSL $HOME. Idempotent: safe to re-run
# after every git pull.

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

# link configs
link "$REPO/wsl/zsh" .zshenv "$HOME/.zshenv"
link "$REPO/wsl/zsh" .config/zsh "$HOME/.config/zsh"
link "$REPO/wsl/tmux" .tmux.conf "$HOME/.tmux.conf"
link "$REPO/nvim" . "$HOME/.config/nvim"
link "$REPO/bat" . "$HOME/.config/bat"
link "$REPO/lazygit" . "$HOME/.config/lazygit"
link "$REPO/wsl/opencode" . "$HOME/.config/opencode"
link "$REPO/starship" starship.toml "$HOME/.config/starship.toml"
link "$REPO/fastfetch" . "$HOME/.config/fastfetch"

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
for bin in zsh tmux nvim starship bat lazygit opencode fastfetch; do
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
