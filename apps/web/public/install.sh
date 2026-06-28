#!/usr/bin/env bash
set -euo pipefail

APP_NAME="Tether"
REPO="Hqzdev/Tether"
INSTALL_URL="https://tetherapp.vercel.app/install.sh"
GITHUB_API="https://api.github.com/repos/${REPO}/releases/latest"
GITHUB_RELEASES="https://github.com/${REPO}/releases/latest"
YES=0
DRY_RUN=0
PREFIX="${HOME}/.local"

usage() {
  printf '%s\n' "Usage: bash <(curl -fsSL ${INSTALL_URL}) [--yes] [--dry-run] [--prefix <path>]"
}

print_step() {
  printf '\n\033[1m==> %s\033[0m\n' "$1"
}

print_ok() {
  printf '\033[32mOK\033[0m %s\n' "$1"
}

print_warn() {
  printf '\033[33mWARN\033[0m %s\n' "$1"
}

print_fail() {
  printf '\033[31mERROR\033[0m %s\n' "$1" >&2
}

run() {
  if [ "$DRY_RUN" -eq 1 ]; then
    printf 'dry-run: %s\n' "$*"
    return 0
  fi

  "$@"
}

need_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    print_fail "Missing required command: $1"
    exit 1
  fi
}

optional_command() {
  if command -v "$1" >/dev/null 2>&1; then
    print_ok "$1 found"
  else
    print_warn "$1 not found"
  fi
}

confirm() {
  if [ "$YES" -eq 1 ]; then
    return 0
  fi

  printf '%s [y/N] ' "$1"
  read -r answer
  case "$answer" in
    y|Y|yes|YES) return 0 ;;
    *) return 1 ;;
  esac
}

detect_os() {
  case "$(uname -s)" in
    Darwin) printf '%s\n' "macos" ;;
    Linux) printf '%s\n' "linux" ;;
    *) print_fail "Unsupported OS: $(uname -s)"; exit 1 ;;
  esac
}

detect_arch() {
  case "$(uname -m)" in
    arm64|aarch64) printf '%s\n' "arm64" ;;
    x86_64|amd64) printf '%s\n' "x64" ;;
    *) print_fail "Unsupported architecture: $(uname -m)"; exit 1 ;;
  esac
}

download() {
  need_command curl
  run curl -fL --retry 3 --connect-timeout 15 "$1" -o "$2"
}

latest_asset_url() {
  local pattern="$1"
  need_command curl
  curl -fsSL "$GITHUB_API" |
    sed -n 's/.*"browser_download_url": "\(.*\)".*/\1/p' |
    grep -E "$pattern" |
    head -n 1
}

ensure_prefix() {
  run mkdir -p "$PREFIX/bin" "$PREFIX/share/tether"
}

ensure_path_hint() {
  case ":${PATH}:" in
    *":${PREFIX}/bin:"*) print_ok "${PREFIX}/bin is on PATH" ;;
    *) print_warn "Add ${PREFIX}/bin to PATH to run Tether from the terminal" ;;
  esac
}

install_macos() {
  print_step "Installing Tether for macOS"
  need_command hdiutil
  need_command ditto

  local temp_dir
  local dmg_url
  temp_dir="$(mktemp -d)"
  local dmg_path="${temp_dir}/Tether.dmg"
  local mount_dir="${temp_dir}/mount"
  run mkdir -p "$mount_dir"

  dmg_url="$(latest_asset_url '\.dmg$' || true)"
  if [ -z "$dmg_url" ]; then
    rm -rf "$temp_dir"
    print_fail "The latest GitHub release does not include a macOS DMG."
    printf '%s\n' "Open ${GITHUB_RELEASES} and check whether Tether.dmg is attached." >&2
    exit 1
  fi

  download "$dmg_url" "$dmg_path"

  if [ "$DRY_RUN" -eq 0 ]; then
    hdiutil attach "$dmg_path" -mountpoint "$mount_dir" -nobrowse -quiet
    trap 'hdiutil detach "$mount_dir" -quiet >/dev/null 2>&1 || true; rm -rf "$temp_dir"' EXIT
  fi

  local source_app="${mount_dir}/Tether.app"
  local target_dir="/Applications"

  if [ ! -w "$target_dir" ]; then
    target_dir="${HOME}/Applications"
    run mkdir -p "$target_dir"
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    printf 'dry-run: install Tether.app into %s\n' "$target_dir"
    rm -rf "$temp_dir"
  else
    if [ ! -d "$source_app" ]; then
      print_fail "Tether.app was not found inside the DMG"
      exit 1
    fi

    rm -rf "${target_dir}/Tether.app"
    ditto "$source_app" "${target_dir}/Tether.app"
    hdiutil detach "$mount_dir" -quiet
    rm -rf "$temp_dir"
    trap - EXIT
  fi

  print_ok "Tether installed for macOS"
  printf '%s\n' "Open it from ${target_dir}/Tether.app"
}

install_linux_deb() {
  local deb_url="$1"
  local temp_dir
  temp_dir="$(mktemp -d)"
  local deb_path="${temp_dir}/tether.deb"

  download "$deb_url" "$deb_path"

  if command -v apt-get >/dev/null 2>&1; then
    if confirm "Install the deb package with sudo apt-get?"; then
      run sudo apt-get install -y "$deb_path"
      rm -rf "$temp_dir"
      print_ok "Tether installed from deb package"
      return 0
    fi
  fi

  if command -v dpkg >/dev/null 2>&1; then
    if confirm "Install the deb package with sudo dpkg?"; then
      run sudo dpkg -i "$deb_path"
      rm -rf "$temp_dir"
      print_ok "Tether installed from deb package"
      return 0
    fi
  fi

  rm -rf "$temp_dir"
  return 1
}

install_linux_appimage() {
  local appimage_url="$1"
  ensure_prefix

  local app_path="${PREFIX}/share/tether/Tether.AppImage"
  local bin_path="${PREFIX}/bin/tether-desktop"

  download "$appimage_url" "$app_path"
  run chmod +x "$app_path"

  if [ "$DRY_RUN" -eq 1 ]; then
    printf 'dry-run: link %s to %s\n' "$bin_path" "$app_path"
  else
    ln -sf "$app_path" "$bin_path"
  fi

  print_ok "Tether AppImage installed"
  ensure_path_hint
}

install_linux() {
  print_step "Installing Tether for Linux"

  local deb_url
  local appimage_url
  deb_url="$(latest_asset_url '\.deb$' || true)"
  appimage_url="$(latest_asset_url '\.AppImage$' || true)"

  if [ -n "$deb_url" ] && install_linux_deb "$deb_url"; then
    return 0
  fi

  if [ -n "$appimage_url" ]; then
    install_linux_appimage "$appimage_url"
    return 0
  fi

  print_fail "No Linux .deb or .AppImage asset was found in ${GITHUB_RELEASES}"
  exit 1
}

system_check() {
  print_step "Checking system"
  local os="$1"
  local arch="$2"

  printf 'OS: %s\n' "$os"
  printf 'Architecture: %s\n' "$arch"

  need_command uname
  need_command curl

  if [ "$os" = "macos" ]; then
    optional_command hdiutil
    optional_command ditto
  else
    optional_command apt-get
    optional_command dpkg
    optional_command rpm
    optional_command pacman
  fi
}

finish() {
  print_step "Done"
  printf '%s\n' "Tether is installed."
  if [ "$OS" = "linux" ]; then
    printf '%s\n' "Try: tether-desktop"
  else
    printf '%s\n' "Open Tether from Applications."
  fi
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --yes|-y) YES=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    --prefix) PREFIX="$2"; shift 2 ;;
    --help|-h) usage; exit 0 ;;
    *) print_fail "Unknown option: $1"; usage; exit 1 ;;
  esac
done

OS="$(detect_os)"
ARCH="$(detect_arch)"

system_check "$OS" "$ARCH"

case "$OS" in
  macos) install_macos ;;
  linux) install_linux ;;
esac

finish
