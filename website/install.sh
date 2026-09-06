#!/bin/sh
# ZeroInfer installer for macOS and Linux.
#
#   curl -fsSL https://zeroinfer.vercel.app/install.sh | sh
#
# Resolves the latest desktop build from GitHub Releases and installs it:
#   macOS  -> unpacks ZeroInfer.app into /Applications
#   Linux  -> drops the AppImage in ~/.local/bin + adds a desktop entry
#
# On macOS this is actually the smoothest path: a file fetched with curl carries
# no com.apple.quarantine attribute, so Gatekeeper doesn't block the (unsigned)
# app the way it does when you download the .dmg in a browser.

set -eu

REPO="ZeroAIx/ZeroInfer"
API="https://api.github.com/repos/${REPO}/releases/latest"

info() { printf '\033[36m>>\033[0m %s\n' "$1"; }
warn() { printf '\033[33m!!\033[0m %s\n' "$1"; }
die()  { printf '\033[31mxx\033[0m %s\n' "$1" >&2; exit 1; }

command -v curl >/dev/null 2>&1 || die "curl is required."

# --- Python check -------------------------------------------------------------
# ZeroInfer runs models with your own Python. The app explains this on first launch
# if it's missing, so don't hard-fail here.
python_ok() {
  for py in python3 python; do
    command -v "$py" >/dev/null 2>&1 || continue
    "$py" -c 'import sys; sys.exit(0 if sys.version_info[:2] >= (3, 10) else 1)' 2>/dev/null && return 0
  done
  return 1
}
if ! python_ok; then
  warn "Python 3.10+ was not found. ZeroInfer needs it to run models."
  case "$(uname -s)" in
    Darwin) warn "Install it with:  brew install python@3.12" ;;
    *)      warn "Install it with:  sudo apt install python3 python3-venv" ;;
  esac
  warn "Continuing - the app will walk you through it on first launch."
fi

# --- Pick the right asset -----------------------------------------------------
OS="$(uname -s)"
ARCH="$(uname -m)"

case "$OS" in
  Darwin)
    case "$ARCH" in
      arm64|aarch64) PATTERN="arm64.zip" ;;
      x86_64)        PATTERN="x64.zip" ;;
      *)             die "Unsupported macOS architecture: $ARCH" ;;
    esac
    ;;
  Linux)
    case "$ARCH" in
      x86_64|amd64) PATTERN=".AppImage" ;;
      *)            die "Unsupported Linux architecture: $ARCH (only x86_64 is built)." ;;
    esac
    ;;
  *)
    die "Unsupported OS: $OS. Windows users: irm https://zeroinfer.vercel.app/install.ps1 | iex"
    ;;
esac

info "Looking up the latest release"
JSON="$(curl -fsSL -H 'User-Agent: zeroinfer-installer' "$API")" \
  || die "Could not reach GitHub."

URL="$(printf '%s' "$JSON" \
  | grep -o '"browser_download_url"[[:space:]]*:[[:space:]]*"[^"]*"' \
  | sed 's/.*"\(https[^"]*\)".*/\1/' \
  | grep -- "$PATTERN" \
  | head -n 1)"

[ -n "$URL" ] || die "The latest release has no asset matching '$PATTERN'."

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

FILE="$TMP/$(basename "$URL")"
info "Downloading $(basename "$URL")"
curl -fL# -o "$FILE" "$URL" || die "Download failed."

# --- Install ------------------------------------------------------------------
if [ "$OS" = "Darwin" ]; then
  command -v unzip >/dev/null 2>&1 || die "unzip is required."
  info "Unpacking"
  unzip -q "$FILE" -d "$TMP/app"

  APP="$(find "$TMP/app" -maxdepth 1 -name '*.app' | head -n 1)"
  [ -n "$APP" ] || die "No .app found inside the archive."

  DEST="/Applications/ZeroInfer.app"
  info "Installing to $DEST"
  if [ -w /Applications ]; then
    rm -rf "$DEST"
    mv "$APP" "$DEST"
  else
    warn "/Applications needs admin rights - you may be prompted for your password."
    sudo rm -rf "$DEST"
    sudo mv "$APP" "$DEST"
  fi

  info "ZeroInfer installed. Starting it now."
  open -a "$DEST" || true

else
  BIN_DIR="$HOME/.local/bin"
  DEST="$BIN_DIR/ZeroInfer.AppImage"
  mkdir -p "$BIN_DIR"

  info "Installing to $DEST"
  mv "$FILE" "$DEST"
  chmod +x "$DEST"

  # A desktop entry so it shows up in the launcher like a normal app.
  APPS="$HOME/.local/share/applications"
  mkdir -p "$APPS"
  cat > "$APPS/zeroinfer.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=ZeroInfer
Comment=Run any Hugging Face model locally
Exec=$DEST
Icon=zeroinfer
Categories=Development;Science;
Terminal=false
EOF

  case ":$PATH:" in
    *":$BIN_DIR:"*) ;;
    *) warn "$BIN_DIR is not on your PATH - add it to run 'ZeroInfer.AppImage' from a shell." ;;
  esac

  # AppImages need FUSE; without it the binary exits with a cryptic error.
  if ! command -v fusermount >/dev/null 2>&1 && ! command -v fusermount3 >/dev/null 2>&1; then
    warn "FUSE was not found. If the app won't start, install it:"
    warn "  sudo apt install libfuse2       # Debian/Ubuntu"
    warn "  ...or run it with:  $DEST --appimage-extract-and-run"
  fi

  info "ZeroInfer installed. Launch it from your applications menu, or run:"
  info "  $DEST"
fi
