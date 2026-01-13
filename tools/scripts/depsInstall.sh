#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"
# shellcheck source=checkEnvironment.sh
source "$SCRIPT_DIR/checkEnvironment.sh"

DEPS_CONFIG="${DEPS_CONFIG:-$NVIMCFG_REPO_ROOT/tools/deps/deps.conf.sh}"

usage() {
  cat <<EOF
Usage:
  tools/scripts/depsInstall.sh

Installs missing deps via:
  - macOS: brew
  - Linux: apt (best-effort)

Env:
  DEPS_CONFIG=... (default: $DEPS_CONFIG)
EOF
}

need_cmds=(git curl tar)

ensure_prereqs() {
  local c
  for c in "${need_cmds[@]}"; do
    have "$c" || die "Required command missing: $c"
  done
}

ensure_brew() {
  if have brew; then return 0; fi
  die "brew not found. Install Homebrew first."
}

ensure_apt() {
  have apt-get || die "apt-get not found. This installer currently supports Debian/Ubuntu."
}

get_missing_commands() {
  # Use depsCheck to compute effective list; parse MISS lines.
  local out
  out="$("$SCRIPT_DIR/depsCheck.sh" 2>/dev/null || true)"
  echo "$out" | awk '/^MISS /{print $2}'
}

install_macos() {
  ensure_brew

  # command->brew package mapping
  local -A map=(
    [rg]="ripgrep"
    [fd]="fd"
    [python3]="python"
    [node]="node"
    [cc]="llvm"     # optional; macOS already has clang via Xcode CLT; see below
    [make]="make"
    [vscode-json-language-server]="vscode-langservers-extracted"
  )

  local -a pkgs=()
  local cmd pkg
  while read -r cmd; do
    [[ -n "$cmd" ]] || continue
    pkg="${map[$cmd]:-}"
    if [[ -n "$pkg" ]]; then
      pkgs+=("$pkg")
    else
      warn "No brew mapping for command: $cmd (install manually)"
    fi
  done < <(get_missing_commands)

  # On macOS, "cc" usually comes from Xcode Command Line Tools
  # If cc is missing, better hint xcode-select than brew llvm.
  if ! have cc; then
    warn "C compiler not found. Install Xcode Command Line Tools:"
    echo "  xcode-select --install"
  fi

  if [[ ${#pkgs[@]} -eq 0 ]]; then
    log "Nothing to install via brew."
    return 0
  fi

  # uniq
  mapfile -t pkgs < <(printf "%s\n" "${pkgs[@]}" | awk '!seen[$0]++')
  log "Installing via brew: ${pkgs[*]}"
  brew install "${pkgs[@]}"
}

install_linux_apt() {
  ensure_apt

  local -A map=(
    [rg]="ripgrep"
    [fd]="fd-find"
    [python3]="python3"
    [node]="nodejs"
    [make]="make"
    [cc]="build-essential"
    [vscode-json-language-server]="node-vscode-langservers-extracted"
  )

  local -a pkgs=()
  local cmd pkg
  while read -r cmd; do
    [[ -n "$cmd" ]] || continue
    pkg="${map[$cmd]:-}"
    if [[ -n "$pkg" ]]; then
      pkgs+=("$pkg")
    else
      warn "No apt mapping for command: $cmd (install manually)"
    fi
  done < <(get_missing_commands)

  if [[ ${#pkgs[@]} -eq 0 ]]; then
    log "Nothing to install via apt."
    return 0
  fi

  mapfile -t pkgs < <(printf "%s\n" "${pkgs[@]}" | awk '!seen[$0]++')
  log "Installing via apt: ${pkgs[*]}"
  sudo apt-get update
  sudo apt-get install -y "${pkgs[@]}"

  # optional: fd alias note
  if ! have fd && have fdfind; then
    warn "On Debian/Ubuntu 'fd' command is 'fdfind'. You may want a symlink:"
    echo "  mkdir -p ~/.local/bin && ln -sf \$(command -v fdfind) ~/.local/bin/fd"
  fi
}

main() {
  ensure_prereqs

  # load config sanity
  [[ -f "$DEPS_CONFIG" ]] || die "Deps config not found: $DEPS_CONFIG"

  # If nothing missing, exit quickly
  if "$SCRIPT_DIR/depsCheck.sh" >/dev/null 2>&1; then
    log "All dependencies are already installed."
    exit 0
  fi

  case "$NVIMCFG_OS" in
    macos) install_macos ;;
    linux) install_linux_apt ;;
    *) die "Unsupported OS: $NVIMCFG_OS" ;;
  esac

  echo
  log "Re-checking..."
  "$SCRIPT_DIR/depsCheck.sh" || true
}

main "$@"

