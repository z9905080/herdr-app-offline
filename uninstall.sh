#!/usr/bin/env bash
# Remove what install.sh created. Leaves this repo and your settings (~/.config/herdr-app) untouched.
# herdr-core is removed only if install.sh put it there (not if it already existed).
set -euo pipefail

BIN_DIR="$HOME/.local/bin"
DATA="${XDG_DATA_HOME:-$HOME/.local/share}"
APPS_DIR="$DATA/applications"
ICON="$DATA/icons/hicolor/scalable/apps/herdr-app.svg"
STATE="$DATA/herdr-app-offline"
APP="$DATA/herdr-app"

link="$BIN_DIR/herdr-app"
if [ -L "$link" ] && readlink "$link" | grep -q '/herdr-app/herdr-app$'; then
  rm -f "$link" && echo "removed $link"
fi
[ -f "$APPS_DIR/herdr-app.desktop" ] && rm -f "$APPS_DIR/herdr-app.desktop" && echo "removed $APPS_DIR/herdr-app.desktop"
[ -f "$ICON" ] && rm -f "$ICON" && echo "removed $ICON"
if [ -f "$APP/.installed-by-herdr-app-offline" ]; then
  rm -rf "$APP" && echo "removed $APP"
fi

if [ -f "$STATE/hc-link-installed" ]; then
  if [ -L "$BIN_DIR/hc" ] && [ "$(readlink "$BIN_DIR/hc")" = herdr-core ]; then
    rm -f "$BIN_DIR/hc" && echo "removed $BIN_DIR/hc"
  fi
fi
if [ -f "$STATE/core-installed" ] && [ -f "$BIN_DIR/herdr-core" ]; then
  rm -f "$BIN_DIR/herdr-core" && echo "removed $BIN_DIR/herdr-core"
  echo "  (an hc server that is still running keeps running until it exits; 'pkill -x herdr-core' stops it and its terminals)"
fi
rm -rf "$STATE"

command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database "$APPS_DIR" >/dev/null 2>&1 || true
[ -f "$DATA/icons/hicolor/icon-theme.cache" ] && gtk-update-icon-cache -f -t "$DATA/icons/hicolor" >/dev/null 2>&1 || true
echo "Herdr uninstalled"
