#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"
# shellcheck source=checkEnvironment.sh
source "$SCRIPT_DIR/checkEnvironment.sh"

usage() {
  cat <<EOF
Usage: installPortableNvim.sh [--latest] [--version vX.Y.Z]

Options:
  --latest           Install latest stable Neovim release (from GitHub API)
  --version <tag>    Install specific version tag, e.g. v0.11.5
EOF
}

getLatestReleaseTag() {
  have curl || die "curl is required"
  # GitHub API: latest release tag_name
  curl -fsSL "https://api.github.com/repos/neovim/neovim/releases/latest" \
    | sed -n 's/.*"tag_name":[[:space:]]*"\([^"]*\)".*/\1/p' \
    | head -n 1
}

downloadAndExtractTarGz() {
  local url="$1"
  local target_dir="$2"
  local tmp
  tmp="$(mktemp -d)"

  have curl || die "curl is required"
  have tar  || die "tar is required"

  log "Downloading archive..."
  curl -fL --progress-bar \
    --retry 3 --retry-delay 1 \
    --connect-timeout 10 --max-time 600 \
    "$url" -o "$tmp/nvim.tar.gz" || die "Download failed: $url"

  rm -rf "$target_dir"
  mkdir -p "$target_dir"

  log "Extracting..."
  tar -xzf "$tmp/nvim.tar.gz" -C "$target_dir" --strip-components=1

  rm -rf "$tmp"
}

main() {
  local force_latest=0
  local force_version=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --latest) force_latest=1; shift ;;
      --version) force_version="$2"; shift 2 ;;
      -h|--help) usage; exit 0 ;;
      *) die "Unknown arg: $1" ;;
    esac
  done

  [[ "$NVIMCFG_OS" != "unknown" ]] || die "Unsupported OS"

  if [[ -n "$force_version" ]]; then
    NVIMCFG_NVIM_VERSION="$force_version"
  elif [[ "$force_latest" == "1" ]]; then
    local latest
    latest="$(getLatestReleaseTag)"
    [[ -n "$latest" ]] || die "Failed to resolve latest release tag"
    NVIMCFG_NVIM_VERSION="$latest"
  fi

  log "Neovim version: $NVIMCFG_NVIM_VERSION"

  mkdir -p "$(dirname "$NVIMCFG_NVIM_INSTALL_DIR")"

  case "$NVIMCFG_OS" in
    linux)
      local asset="nvim-linux64.tar.gz"
      if [[ "$NVIMCFG_ARCH" == "arm64" ]]; then
        asset="nvim-linux-arm64.tar.gz"
      fi
      local url="https://github.com/neovim/neovim/releases/download/${NVIMCFG_NVIM_VERSION}/${asset}"
      downloadAndExtractTarGz "$url" "$NVIMCFG_NVIM_INSTALL_DIR"
      ;;
    macos)
      local candidates=()
      if [[ "$NVIMCFG_ARCH" == "arm64" ]]; then
        candidates+=("nvim-macos-arm64.tar.gz")
      else
        candidates+=("nvim-macos-x86_64.tar.gz")
      fi
      candidates+=("nvim-macos.tar.gz")

      local ok=0
      for asset in "${candidates[@]}"; do
        local url="https://github.com/neovim/neovim/releases/download/${NVIMCFG_NVIM_VERSION}/${asset}"
        log "Trying: $asset"
          if curl -fsSIL --connect-timeout 5 --max-time 15 "$url" >/dev/null 2>&1; then
          downloadAndExtractTarGz "$url" "$NVIMCFG_NVIM_INSTALL_DIR"
          ok=1
          break
        fi
        warn "Not found: $asset"
      done
      [[ "$ok" == "1" ]] || die "Could not find a macOS asset for ${NVIMCFG_NVIM_VERSION}"
      ;;
  esac

  [[ -x "$NVIMCFG_NVIM_BIN_DIR/nvim" ]] || die "nvim binary not found: $NVIMCFG_NVIM_BIN_DIR/nvim"

  log "Installed: $("$NVIMCFG_NVIM_BIN_DIR/nvim" --version | head -n 1)"
  log "Location:  $NVIMCFG_NVIM_INSTALL_DIR"
  echo "$NVIMCFG_NVIM_INSTALL_DIR"
}

main "$@"

