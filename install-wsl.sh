#!/usr/bin/env bash
# install-wsl.sh - link shared configs into WSL $HOME. Idempotent: safe to re-run
# after every git pull. Uses GNU Stow when available, plain symlinks otherwise.

set -euo pipefail

REPO="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"

log()  { printf '\033[1;36m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m==>\033[0m %s\n' "$*" >&2; }

link() {
    local src="$(readlink -f "$1/$2")" tgt="$3"
    [ -L "$tgt" ] && [ "$(readlink -f "$tgt")" = "$src" ] && return 0
    mkdir -p "$(dirname "$tgt")"
    if [ -e "$tgt" ] || [ -L "$tgt" ]; then
        mv "$tgt" "$tgt.bak.$(date +%s)"
    fi
    ln -s "$src" "$tgt"
}

backup_conflicts() {
    local pkgdir="$1" tgt="$2"
    while IFS= read -r rel; do
        [ -z "$rel" ] && continue
        local path="$tgt/$rel"
        if [ -L "$path" ]; then
            [ "$(readlink -f "$path")" != "$(readlink -f "$pkgdir/$rel")" ] && mv "$path" "$path.bak.$(date +%s)"
        elif [ -e "$path" ]; then
            [ -d "$path" ] && [ -d "$pkgdir/$rel" ] || mv "$path" "$path.bak.$(date +%s)"
        fi
    done < <(cd "$pkgdir" && find . | sed 's|^\./||')
}

export PATH="$HOME/.local/bin:$PATH"

# link configs
if command -v stow >/dev/null 2>&1; then
    stow_pkg() {
        local pkg="$1" tgt="$2" dir="$REPO"
        [ -d "$REPO/wsl/$pkg" ] && dir="$REPO/wsl"
        backup_conflicts "$dir/$pkg" "$tgt"
        stow --dir "$dir" --target "$tgt" -S "$pkg"
    }
    mkdir -p "$HOME/.config"
    for p in zsh tmux; do stow_pkg "$p" "$HOME"; done
    for p in nvim bat lazygit opencode starship fastfetch; do stow_pkg "$p" "$HOME/.config"; done
else
    warn "stow not found - using plain symlinks"
    link "$REPO/wsl/zsh" .zshenv "$HOME/.zshenv"
    link "$REPO/wsl/zsh" .config/zsh "$HOME/.config/zsh"
    link "$REPO/wsl/tmux" .tmux.conf "$HOME/.tmux.conf"
    link "$REPO/nvim" . "$HOME/.config/nvim"
    link "$REPO/bat" . "$HOME/.config/bat"
    link "$REPO/lazygit" . "$HOME/.config/lazygit"
    link "$REPO/wsl/opencode" . "$HOME/.config/opencode"
    link "$REPO/starship" starship.toml "$HOME/.config/starship.toml"
    link "$REPO/fastfetch" . "$HOME/.config/fastfetch"
fi

# bat cache
command -v bat >/dev/null 2>&1 && bat cache --build >/dev/null 2>&1

# opencode
if [ -x "$HOME/.opencode/bin/opencode" ]; then
    mkdir -p "$HOME/.local/bin"
    ln -sfn "$HOME/.opencode/bin/opencode" "$HOME/.local/bin/opencode"
elif ! command -v opencode >/dev/null 2>&1; then
    log "installing opencode"
    curl -fsSL https://opencode.ai/install | bash -s -- --no-modify-path
    mkdir -p "$HOME/.local/bin"
    ln -sfn "$HOME/.opencode/bin/opencode" "$HOME/.local/bin/opencode"
fi

# check requirements
missing=0
for bin in zsh tmux nvim starship bat lazygit opencode fastfetch; do
    command -v "$bin" >/dev/null 2>&1 || { printf '  \033[1;31m%s\033[0m missing\n' "$bin"; missing=1; }
done
[ "$missing" -eq 0 ] || warn "some requirements missing - see README.md"

log "done. run 'exec zsh' to reload."
