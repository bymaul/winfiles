#!/usr/bin/env bash
# install-wsl.sh - link shared configs into WSL $HOME. Idempotent: safe to re-run
# after every git pull. Uses GNU Stow when available, plain symlinks otherwise.

set -euo pipefail

REPO="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"

log()  { printf '\033[1;36m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m==>\033[0m %s\n' "$*" >&2; }

# link <pkgdir> <relpath> <target>
# symlink one package path into place; backs up anything already there.
link() {
    local pkgdir="$1" rel="$2" tgt="$3"
    local src="$(readlink -f "$pkgdir/$rel")"
    if [ -L "$tgt" ] && [ "$(readlink -f "$tgt")" = "$src" ]; then
        return 0
    fi
    mkdir -p "$(dirname "$tgt")"
    if [ -e "$tgt" ] || [ -L "$tgt" ]; then
        mv "$tgt" "$tgt.bak.$(date +%s)"
        warn "moved existing $tgt to $tgt.bak"
    fi
    ln -s "$src" "$tgt"
    log "linked $tgt -> $src"
}

# backup_conflicts <pkgdir> <target>
# move any real files/dirs that would collide with a stow package out of the way.
backup_conflicts() {
    local pkgdir="$1" tgt="$2"
    while IFS= read -r rel; do
        [ -z "$rel" ] && continue
        local path="$tgt/$rel"
        if [ -L "$path" ]; then
            if [ "$(readlink -f "$path")" != "$(readlink -f "$pkgdir/$rel")" ]; then
                mv "$path" "$path.bak.$(date +%s)"
                warn "moved existing symlink $path to $path.bak"
            fi
        elif [ -e "$path" ]; then
            if [ -d "$path" ] && [ -d "$pkgdir/$rel" ]; then
                continue  # real dir stow will descend into
            fi
            mv "$path" "$path.bak.$(date +%s)"
            warn "moved existing $path to $path.bak"
        fi
    done < <(cd "$pkgdir" && find . | sed 's|^\./||')
}

log "installing winfiles into $HOME (from $REPO)"

if command -v stow >/dev/null 2>&1; then
    log "using GNU Stow"
    stow_pkg() {
        local pkg="$1" tgt="$2"
        local dir="$REPO"
        [ -d "$REPO/wsl/$pkg" ] && dir="$REPO/wsl"
        backup_conflicts "$dir/$pkg" "$tgt"
        stow --dir "$dir" --target "$tgt" -S "$pkg"
        log "stowed $pkg"
    }
    mkdir -p "$HOME/.config"
    stow_pkg zsh "$HOME"
    stow_pkg tmux "$HOME"
    stow_pkg nvim "$HOME/.config"
    stow_pkg bat "$HOME/.config"
    stow_pkg lazygit "$HOME/.config"
    stow_pkg opencode "$HOME/.config"
    stow_pkg starship "$HOME/.config"
else
    warn "stow not found - using plain symlinks"
    link "$REPO/wsl/zsh" .zshenv "$HOME/.zshenv"
    link "$REPO/wsl/zsh" .config/zsh "$HOME/.config/zsh"
    link "$REPO/wsl/tmux" .tmux.conf "$HOME/.tmux.conf"
    link "$REPO/nvim" . "$HOME/.config/nvim"
    link "$REPO/bat" . "$HOME/.config/bat"
    link "$REPO/lazygit" . "$HOME/.config/lazygit"
    link "$REPO/opencode" . "$HOME/.config/opencode"
    link "$REPO/starship" starship.toml "$HOME/.config/starship.toml"
fi

# register vendored bat theme
if command -v bat >/dev/null 2>&1; then
    bat cache --build >/dev/null 2>&1 && log "rebuilt bat cache"
fi

# requirements check (warn-only; full list in README)
log "checking requirements"
missing=0
for bin in zsh tmux nvim starship bat lazygit opencode; do
    if ! command -v "$bin" >/dev/null 2>&1; then
        printf '  \033[1;31m%s\033[0m missing\n' "$bin"
        missing=1
    fi
done
[ "$missing" -eq 0 ] || warn "some requirements are missing - see README.md"

cat <<EOF

done. next steps:
  exec zsh                 # restart the shell to pick up the new config
  chsh -s /usr/bin/zsh     # once: make zsh the default shell
EOF
