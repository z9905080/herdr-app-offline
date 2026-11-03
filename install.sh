#!/usr/bin/env bash
# Offline install of Herdr (herdr-app) + herdr-core (hc) from this repo into ~/.local (no root, no network).
# Usage: ./install.sh [--copy] [--no-core] [--deps[=<dir>]] [--dry-run]
#   default      : symlink ~/.local/bin/herdr-app to the binary inside this repo
#   --copy       : copy the app to ~/.local/share/herdr-app first (repo can be deleted afterwards)
#   --no-core    : do not install/upgrade herdr-core (hc)
#   --deps       : first install the runtime apt packages with sudo (Ubuntu 22.04 / 24.04 list).
#                  Uses local .deb files if the repo has debs-jammy-<arch>/, debs-<arch>/ or debs/,
#                  otherwise `sudo apt-get install -y <pkgs>` from the configured apt sources (e.g. an intranet mirror)
#   --deps=<dir> : install all <dir>/*.deb (downloaded as described in README) instead
#   --dry-run    : with --deps, only print what would be installed (apt-get -s, no sudo) and exit
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
MODE=link
CORE=yes
DEPS=no
DEPS_DIR=
DRY=no
for arg in "$@"; do
  case "$arg" in
    --copy) MODE=copy ;;
    --no-core) CORE=no ;;
    --deps) DEPS=yes ;;
    --deps=*) DEPS=yes; DEPS_DIR="${arg#--deps=}"
              [ -n "$DEPS_DIR" ] || { echo "--deps= needs a directory" >&2; exit 2; } ;;
    --dry-run) DRY=yes ;;
    -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
    *) echo "Unknown option: $arg" >&2; exit 2 ;;
  esac
done
[ "$DRY" = no ] || [ "$DEPS" = yes ] || { echo "--dry-run only works together with --deps" >&2; exit 2; }

[ "$(uname -s)" = Linux ] || { echo "This bundle is for Linux only" >&2; exit 1; }
case "$(uname -m)" in
  x86_64|amd64) ARCH=x86_64 ;;
  aarch64|arm64) ARCH=arm64 ;;
  *) echo "Unsupported architecture: $(uname -m)" >&2; exit 1 ;;
esac

SRC="$REPO_DIR/$ARCH"
[ -x "$SRC/herdr-app/herdr-app" ] || { echo "Missing $SRC/herdr-app/herdr-app" >&2; exit 1; }
[ -x "$SRC/herdr-core/herdr-core" ] || { echo "Missing $SRC/herdr-core/herdr-core" >&2; exit 1; }

# --- runtime packages (--deps) -------------------------------------------
# Package lists = README ("執行環境需求" / "Ubuntu 22.04").
PKGS_COMMON="libvulkan1 mesa-vulkan-drivers libxkbcommon0 libxkbcommon-x11-0 libxcb1 libxcb-xkb1
  libwayland-client0 libwayland-egl1 libegl1 libfontconfig1 pulseaudio-utils vulkan-tools"
# 22.04: newer Mesa (kisak/turtle) must be upgraded as a matched set
PKGS_JAMMY_MESA="libegl-mesa0 libgl1-mesa-dri libglx-mesa0 libgbm1 mesa-libgallium"

mesa_major() { { dpkg-query -W -f='${Version}' mesa-vulkan-drivers 2>/dev/null | sed -E 's/^[0-9]+://; s/^([0-9]+).*/\1/'; } || true; }
MESA_WARNED=no

if [ "$DEPS" = yes ]; then
  [ -r /etc/os-release ] || { echo "--deps: /etc/os-release not found; only Ubuntu/Debian are supported" >&2; exit 1; }
  OS_ID="$(. /etc/os-release; echo "${ID:-}")"
  OS_LIKE="$(. /etc/os-release; echo "${ID_LIKE:-}")"
  OS_VER="$(. /etc/os-release; echo "${VERSION_ID:-}")"
  OS_NAME="$(. /etc/os-release; echo "${PRETTY_NAME:-$OS_ID $OS_VER}")"
  OS_CODE="$(. /etc/os-release; echo "${UBUNTU_CODENAME:-${VERSION_CODENAME:-}}")"
  case " $OS_ID $OS_LIKE " in
    *" ubuntu "*|*" debian "*) ;;
    *) echo "--deps: $OS_NAME is not Ubuntu/Debian (apt). Install the packages listed in README by hand." >&2; exit 1 ;;
  esac
  command -v apt-get >/dev/null 2>&1 || { echo "--deps: apt-get not found" >&2; exit 1; }

  JAMMY=no
  if [ "$OS_CODE" = jammy ] || { [ "$OS_ID" = ubuntu ] && [ "$OS_VER" = 22.04 ]; }; then
    JAMMY=yes
  elif [ "$OS_CODE" = noble ] || { [ "$OS_ID" = ubuntu ] && [ "$OS_VER" = 24.04 ]; }; then
    :
  else
    echo "WARNING: --deps: $OS_NAME is not Ubuntu 22.04/24.04; trying the 24.04 package list." >&2
  fi

  DEB_ARCH="$(dpkg --print-architecture 2>/dev/null || echo amd64)"
  if [ -z "$DEPS_DIR" ]; then
    cands="debs-$DEB_ARCH debs"
    [ "$JAMMY" = yes ] && cands="debs-jammy-$DEB_ARCH $cands"
    for d in $cands; do
      if compgen -G "$REPO_DIR/$d/*.deb" >/dev/null; then DEPS_DIR="$REPO_DIR/$d"; break; fi
    done
  fi

  if [ "$(id -u)" = 0 ]; then
    SUDO=()
  elif [ "$DRY" = yes ]; then
    SUDO=(sudo)
  else
    command -v sudo >/dev/null 2>&1 || { echo "--deps: sudo is not installed; run as root or install the packages by hand (see README)" >&2; exit 1; }
    echo "--deps: installing system packages needs sudo"
    sudo -v || { echo "--deps: sudo is not available for $(id -un); ask an admin to install the packages in README" >&2; exit 1; }
    SUDO=(sudo)
  fi

  if [ -n "$DEPS_DIR" ]; then
    DEPS_DIR="$(cd "$DEPS_DIR" 2>/dev/null && pwd)" || { echo "--deps: directory not found" >&2; exit 1; }
    compgen -G "$DEPS_DIR/*.deb" >/dev/null || { echo "--deps: no .deb files in $DEPS_DIR" >&2; exit 1; }
    DEBS=("$DEPS_DIR"/*.deb)
    echo "--deps: $OS_NAME, installing ${#DEBS[@]} local .deb files from $DEPS_DIR"
    if [ "$DRY" = yes ]; then
      echo "+ ${SUDO[*]:+${SUDO[*]} }apt-get install -y $DEPS_DIR/*.deb"
      apt-get install -s "${DEBS[@]}" | grep -E '^(Inst|Conf|E:)|newly installed' || true
    else
      "${SUDO[@]}" apt-get install -y "${DEBS[@]}"
    fi
  else
    PKGS="$PKGS_COMMON"
    if [ "$JAMMY" = yes ]; then
      # Only ask for the Mesa set packages the configured sources actually have
      # (mesa-libgallium exists only in the newer Mesa from kisak/turtle, not in stock 22.04).
      for p in $PKGS_JAMMY_MESA; do
        cand="$(apt-cache policy "$p" 2>/dev/null || true)"
        if printf '%s\n' "$cand" | grep 'Candidate:' | grep -vq '(none)'; then
          PKGS="$PKGS $p"
        else
          echo "--deps: skipping $p (not available from your apt sources)"
        fi
      done
    fi
    PKGS="$(echo $PKGS)"
    echo "--deps: $OS_NAME, packages: $PKGS"
    if [ "$DRY" = yes ]; then
      echo "+ ${SUDO[*]:+${SUDO[*]} }apt-get install -y $PKGS"
      apt-get install -s $PKGS | grep -E '^(Inst|E:)|newly installed' || true
    else
      "${SUDO[@]}" apt-get install -y $PKGS || {
        echo "--deps: apt-get install failed. If packages were not found, run 'sudo apt-get update' first," >&2
        echo "        or download the .deb files outside the intranet and use --deps=<dir> (see README)." >&2
        exit 1; }
    fi
  fi

  if [ "$DRY" = yes ]; then
    echo "(dry run: nothing installed)"
    exit 0
  fi

  if [ "$JAMMY" = yes ]; then
    m="$(mesa_major)"
    if [ -n "$m" ] && [ "$m" -lt 24 ]; then
      MESA_WARNED=yes
      echo
      echo "WARNING: mesa-vulkan-drivers is still $(dpkg-query -W -f='${Version}' mesa-vulkan-drivers)."
      echo "         On Ubuntu 22.04 this Mesa draws a black Herdr window. Install Mesa 25 from the"
      echo "         kisak/turtle PPA (offline steps: README section \"Ubuntu 22.04\"), then rerun."
      echo
    fi
  fi
fi

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
# Ubuntu 22.04 ships Mesa 23.2.x, which draws a black window with this build (see README "Ubuntu 22.04").
if [ "$MESA_WARNED" = no ] && command -v dpkg-query >/dev/null 2>&1; then
  m="$(mesa_major)"
  if [ -n "$m" ] && [ "$m" -lt 24 ]; then
    echo
    echo "NOTE: mesa-vulkan-drivers is $(dpkg-query -W -f='${Version}' mesa-vulkan-drivers). Herdr needs a newer Mesa on this system"
    echo "      (Ubuntu 22.04: Mesa 25 from the kisak/turtle PPA). See README section \"Ubuntu 22.04\"."
  fi
fi
case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *) echo
     echo "NOTE: $BIN_DIR is not on your PATH. Add this to ~/.bashrc (or ~/.zshrc):"
     echo "  export PATH=\"\$HOME/.local/bin:\$PATH\"" ;;
esac
