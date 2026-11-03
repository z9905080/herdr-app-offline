#!/usr/bin/env bash
# Offline install of Herdr (herdr-app) + herdr-core (hc) from this repo into ~/.local (no root, no network).
# Usage: ./install.sh [--copy] [--no-core]
#   default   : symlink ~/.local/bin/herdr-app to the binary inside this repo
#   --copy    : copy the app to ~/.local/share/herdr-app first (repo can be deleted afterwards)
#   --no-core : do not install/upgrade herdr-core (hc)
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
MODE=link
CORE=yes
for arg in "$@"; do
  case "$arg" in
    --copy) MODE=copy ;;
    --no-core) CORE=no ;;
    -h|--help) sed -n '2,7p' "$0"; exit 0 ;;
    *) echo "Unknown option: $arg" >&2; exit 2 ;;
  esac
done

[ "$(uname -s)" = Linux ] || { echo "This bundle is for Linux only" >&2; exit 1; }
case "$(uname -m)" in
  x86_64|amd64) ARCH=x86_64 ;;
  aarch64|arm64) ARCH=arm64 ;;
  *) echo "Unsupported architecture: $(uname -m)" >&2; exit 1 ;;
esac

SRC="$REPO_DIR/$ARCH"
[ -x "$SRC/herdr-app/herdr-app" ] || { echo "Missing $SRC/herdr-app/herdr-app" >&2; exit 1; }
[ -x "$SRC/herdr-core/herdr-core" ] || { echo "Missing $SRC/herdr-core/herdr-core" >&2; exit 1; }

BIN_DIR="$HOME/.local/bin"
DATA="${XDG_DATA_HOME:-$HOME/.local/share}"
APPS_DIR="$DATA/applications"
ICON_DIR="$DATA/icons/hicolor/scalable/apps"
STATE="$DATA/herdr-app-offline"
mkdir -p "$BIN_DIR" "$APPS_DIR" "$ICON_DIR" "$STATE"

# --- app ---------------------------------------------------------------
if [ "$MODE" = copy ]; then
  APP="$DATA/herdr-app"
  rm -rf "$APP.new"
  cp -a "$SRC/herdr-app" "$APP.new"
  touch "$APP.new/.installed-by-herdr-app-offline"
  rm -rf "$APP"
  mv "$APP.new" "$APP"
else
  APP="$SRC/herdr-app"
fi
ln -sfn "$APP/herdr-app" "$BIN_DIR/herdr-app"
cp -f "$APP/herdr-app.svg" "$ICON_DIR/herdr-app.svg"
cat > "$APPS_DIR/herdr-app.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=Herdr
Comment=Terminals and coding agents that keep running
Exec=$BIN_DIR/herdr-app
Icon=herdr-app
Terminal=false
Categories=Development;
StartupWMClass=herdr-app
DESKTOP
command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database "$APPS_DIR" >/dev/null 2>&1 || true
[ -f "$DATA/icons/hicolor/icon-theme.cache" ] && gtk-update-icon-cache -f -t "$DATA/icons/hicolor" >/dev/null 2>&1 || true

# --- herdr-core (hc) -----------------------------------------------------
# Same rules as the official core installer, minus the download:
#  - none yet           -> copy to ~/.local/bin/herdr-core, plus `hc` symlink if no hc exists
#  - ~/.local/bin one    -> upgraded with `herdr-core update --from` only if older (terminals keep running)
#  - one elsewhere on PATH (package manager) -> left alone
CORE_MSG="skipped (--no-core)"
if [ "$CORE" = yes ]; then
  NEW="$SRC/herdr-core/herdr-core"
  NEW_VER="$("$NEW" --version 2>/dev/null | awk '{print $NF}')" \
    || { echo "The bundled herdr-core does not run on this machine" >&2; exit 1; }
  CORE_BIN="$BIN_DIR/herdr-core"
  if [ -x "$CORE_BIN" ]; then
    OLD_VER="$("$CORE_BIN" --version 2>/dev/null | awk '{print $NF}' || true)"
    if [ -n "$OLD_VER" ] && [ "$OLD_VER" != "$NEW_VER" ] && \
       [ "$(printf '%s\n%s\n' "$OLD_VER" "$NEW_VER" | sort -V | head -1)" = "$OLD_VER" ]; then
      "$CORE_BIN" update --from "$NEW" >/dev/null
      CORE_MSG="upgraded $OLD_VER -> $NEW_VER ($CORE_BIN)"
    else
      CORE_MSG="kept existing ${OLD_VER:-?} ($CORE_BIN)"
    fi
  elif command -v herdr-core >/dev/null 2>&1; then
    CORE_MSG="kept existing $(command -v herdr-core) (not managed here)"
  else
    cp "$NEW" "$CORE_BIN.new"
    chmod 755 "$CORE_BIN.new"
    mv -f "$CORE_BIN.new" "$CORE_BIN"
    touch "$STATE/core-installed"
    CORE_MSG="installed $NEW_VER ($CORE_BIN)"
  fi
  if [ -x "$CORE_BIN" ] && ! command -v hc >/dev/null 2>&1 && [ ! -e "$BIN_DIR/hc" ] && [ ! -L "$BIN_DIR/hc" ]; then
    ln -s herdr-core "$BIN_DIR/hc"
    touch "$STATE/hc-link-installed"
  fi
fi

echo "Herdr $("$APP/herdr-app" --version 2>/dev/null | awk '{print $NF}') installed ($ARCH, mode: $MODE)"
echo "  app      : $APP"
echo "  command  : $BIN_DIR/herdr-app"
echo "  desktop  : $APPS_DIR/herdr-app.desktop"
echo "  icon     : $ICON_DIR/herdr-app.svg"
echo "  core (hc): $CORE_MSG"
case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *) echo
     echo "NOTE: $BIN_DIR is not on your PATH. Add this to ~/.bashrc (or ~/.zshrc):"
     echo "  export PATH=\"\$HOME/.local/bin:\$PATH\"" ;;
esac
