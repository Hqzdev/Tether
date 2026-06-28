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

install_cli_shim() {
  print_step "Installing tether CLI"
  ensure_prefix

  local cli_path="${PREFIX}/bin/tether"

  if [ "$DRY_RUN" -eq 1 ]; then
    printf 'dry-run: install tether CLI to %s\n' "$cli_path"
    ensure_path_hint
    return 0
  fi

  cat > "$cli_path" <<'SHIM'
#!/usr/bin/env bash
set -euo pipefail

APP_NAME="Tether"
REPO="Hqzdev/Tether"
GITHUB_API="https://api.github.com/repos/${REPO}/releases/latest"
GITHUB_RELEASES="https://github.com/${REPO}/releases/latest"
PREFIX="${HOME}/.local"

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

usage() {
  cat <<'HELP'
Tether CLI

Commands:
  tether help              Show this help
  tether version           Show installed app version and latest release
  tether doctor            Check app, CLI, release asset, and PATH
  tether open              Open the desktop app
  tether update            Close the app if needed, install the latest release, then reopen it
  tether uninstall         Remove the app and CLI, keep local traces and settings
  tether uninstall --purge Remove the app, CLI, traces, caches, and local settings

Install:
  curl -fsSL https://tetherapp.vercel.app/install.sh | bash
HELP
}

need_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    print_fail "Missing required command: $1"
    exit 1
  fi
}

detect_os() {
  case "$(uname -s)" in
    Darwin) printf '%s\n' "macos" ;;
    Linux) printf '%s\n' "linux" ;;
    *) print_fail "Unsupported OS: $(uname -s)"; exit 1 ;;
  esac
}

latest_tag() {
  need_command curl
  curl -fsSL "$GITHUB_API" |
    sed -n 's/.*"tag_name": "\(.*\)".*/\1/p' |
    head -n 1
}

latest_asset_url() {
  local pattern="$1"
  need_command curl
  curl -fsSL "$GITHUB_API" |
    sed -n 's/.*"browser_download_url": "\(.*\)".*/\1/p' |
    grep -E "$pattern" |
    head -n 1
}

macos_app_path() {
  if [ -d "/Applications/Tether.app" ]; then
    printf '%s\n' "/Applications/Tether.app"
  elif [ -d "${HOME}/Applications/Tether.app" ]; then
    printf '%s\n' "${HOME}/Applications/Tether.app"
  else
    return 1
  fi
}

linux_app_path() {
  if [ -x "${PREFIX}/share/tether/Tether.AppImage" ]; then
    printf '%s\n' "${PREFIX}/share/tether/Tether.AppImage"
  elif command -v tether-desktop >/dev/null 2>&1; then
    command -v tether-desktop
  else
    return 1
  fi
}

app_path() {
  case "$(detect_os)" in
    macos) macos_app_path ;;
    linux) linux_app_path ;;
  esac
}

is_macos_running() {
  pgrep -x Tether >/dev/null 2>&1
}

close_macos_app() {
  if ! is_macos_running; then
    return 0
  fi

  print_step "Closing Tether"
  osascript -e 'tell application "Tether" to quit' >/dev/null 2>&1 || true

  for _ in 1 2 3 4 5 6 7 8 9 10; do
    if ! is_macos_running; then
      print_ok "Tether closed"
      return 0
    fi
    sleep 1
  done

  pkill -x Tether >/dev/null 2>&1 || true
  print_warn "Tether was force-closed"
}

open_app() {
  case "$(detect_os)" in
    macos)
      local path
      path="$(macos_app_path)" || {
        print_fail "Tether.app is not installed"
        exit 1
      }
      open "$path"
      ;;
    linux)
      local path
      path="$(linux_app_path)" || {
        print_fail "Tether is not installed"
        exit 1
      }
      nohup "$path" >/dev/null 2>&1 &
      ;;
  esac
}

notify_update_success() {
  case "$(detect_os)" in
    macos)
      if command -v osascript >/dev/null 2>&1; then
        osascript -e 'display notification "Tether was updated successfully." with title "Tether updated"' >/dev/null 2>&1 || true
      fi
      ;;
    linux)
      if command -v notify-send >/dev/null 2>&1; then
        notify-send "Tether updated" "Tether was updated successfully." >/dev/null 2>&1 || true
      fi
      ;;
  esac
}

download() {
  need_command curl
  curl -fL --retry 3 --connect-timeout 15 "$1" -o "$2"
}

install_macos_latest() {
  need_command hdiutil
  need_command ditto

  local dmg_url
  dmg_url="$(latest_asset_url '\.dmg$' || true)"
  if [ -z "$dmg_url" ]; then
    print_fail "The latest GitHub release does not include a macOS DMG."
    printf '%s\n' "Open ${GITHUB_RELEASES} and check whether Tether.dmg is attached." >&2
    exit 1
  fi

  local temp_dir
  temp_dir="$(mktemp -d)"
  local dmg_path="${temp_dir}/Tether.dmg"
  local mount_dir="${temp_dir}/mount"
  mkdir -p "$mount_dir"

  download "$dmg_url" "$dmg_path"
  hdiutil attach "$dmg_path" -mountpoint "$mount_dir" -nobrowse -quiet
  trap 'hdiutil detach "$mount_dir" -quiet >/dev/null 2>&1 || true; rm -rf "$temp_dir"' EXIT

  local target_dir="/Applications"
  if [ ! -w "$target_dir" ]; then
    target_dir="${HOME}/Applications"
    mkdir -p "$target_dir"
  fi

  if [ ! -d "${mount_dir}/Tether.app" ]; then
    print_fail "Tether.app was not found inside the DMG"
    exit 1
  fi

  rm -rf "${target_dir}/Tether.app"
  ditto "${mount_dir}/Tether.app" "${target_dir}/Tether.app"
  hdiutil detach "$mount_dir" -quiet
  rm -rf "$temp_dir"
  trap - EXIT
  print_ok "Tether updated at ${target_dir}/Tether.app"
}

install_linux_latest() {
  mkdir -p "${PREFIX}/bin" "${PREFIX}/share/tether"

  local appimage_url
  appimage_url="$(latest_asset_url '\.AppImage$' || true)"
  if [ -z "$appimage_url" ]; then
    print_fail "The latest GitHub release does not include a Linux AppImage."
    printf '%s\n' "Open ${GITHUB_RELEASES} and check release assets." >&2
    exit 1
  fi

  local app_path="${PREFIX}/share/tether/Tether.AppImage"
  download "$appimage_url" "$app_path"
  chmod +x "$app_path"
  ln -sf "$app_path" "${PREFIX}/bin/tether-desktop"
  print_ok "Tether updated at ${app_path}"
}

update_app() {
  local os
  local reopen=0
  os="$(detect_os)"

  case "$os" in
    macos)
      if is_macos_running; then
        reopen=1
      fi
      close_macos_app
      print_step "Updating Tether"
      install_macos_latest
      ;;
    linux)
      print_step "Updating Tether"
      install_linux_latest
      ;;
  esac

  if [ "$reopen" -eq 1 ]; then
    open_app
  fi

  notify_update_success
}

installed_version() {
  case "$(detect_os)" in
    macos)
      local path
      path="$(macos_app_path)" || {
        printf '%s\n' "not installed"
        return 0
      }
      defaults read "${path}/Contents/Info" CFBundleShortVersionString 2>/dev/null || printf '%s\n' "unknown"
      ;;
    linux)
      linux_app_path >/dev/null 2>&1 && printf '%s\n' "installed" || printf '%s\n' "not installed"
      ;;
  esac
}

doctor() {
  print_step "Tether doctor"
  printf 'OS: %s\n' "$(detect_os)"
  printf 'CLI: %s\n' "$0"
  printf 'App: %s\n' "$(app_path 2>/dev/null || printf '%s' "not installed")"
  printf 'Installed: %s\n' "$(installed_version)"
  printf 'Latest: %s\n' "$(latest_tag || printf '%s' "unknown")"
  case ":${PATH}:" in
    *":$(dirname "$0"):"*) print_ok "$(dirname "$0") is on PATH" ;;
    *) print_warn "$(dirname "$0") is not on PATH" ;;
  esac
  case "$(detect_os)" in
    macos)
      latest_asset_url '\.dmg$' >/dev/null && print_ok "macOS DMG exists in latest release" || print_warn "macOS DMG missing in latest release"
      ;;
    linux)
      latest_asset_url '\.AppImage$' >/dev/null && print_ok "Linux AppImage exists in latest release" || print_warn "Linux AppImage missing in latest release"
      ;;
  esac
}

uninstall_app() {
  local purge=0
  if [ "${1:-}" = "--purge" ]; then
    purge=1
  fi

  case "$(detect_os)" in
    macos)
      close_macos_app
      rm -rf "/Applications/Tether.app" "${HOME}/Applications/Tether.app"
      ;;
    linux)
      rm -f "${PREFIX}/bin/tether-desktop"
      rm -f "${PREFIX}/share/tether/Tether.AppImage"
      ;;
  esac

  if [ "$purge" -eq 1 ]; then
    rm -rf \
      "${HOME}/Library/Application Support/Tether" \
      "${HOME}/Library/Caches/Tether" \
      "${HOME}/.local/share/tether" \
      "${HOME}/.cache/tether" \
      "${HOME}/.config/tether"
    print_warn "Local Tether data was removed"
  else
    print_warn "Local traces and settings were kept. Use tether uninstall --purge to remove them."
  fi

  rm -f "$0"
  print_ok "Tether uninstalled"
}

case "${1:-help}" in
  help|--help|-h) usage ;;
  version)
    printf 'Installed: %s\n' "$(installed_version)"
    printf 'Latest: %s\n' "$(latest_tag || printf '%s' "unknown")"
    ;;
  doctor) doctor ;;
  open) open_app ;;
  update) update_app ;;
  uninstall) uninstall_app "${2:-}" ;;
  *)
    print_fail "Unknown command: $1"
    usage
    exit 1
    ;;
esac
SHIM

  chmod +x "$cli_path"
  print_ok "tether CLI installed at ${cli_path}"
  ensure_path_hint
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
  install_cli_shim
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
      install_cli_shim
      return 0
    fi
  fi

  if command -v dpkg >/dev/null 2>&1; then
    if confirm "Install the deb package with sudo dpkg?"; then
      run sudo dpkg -i "$deb_path"
      rm -rf "$temp_dir"
      print_ok "Tether installed from deb package"
      install_cli_shim
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
  install_cli_shim
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
  printf '%s\n' "Try: tether help"
  printf '%s\n' "Update later with: tether update"
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
