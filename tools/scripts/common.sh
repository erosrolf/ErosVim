#!/usr/bin/env bash
set -euo pipefail

# ---------- logging ----------
log()  { printf "\033[1;32m==>\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m[warn]\033[0m %s\n" "$*"; }
die()  { printf "\033[1;31m[err]\033[0m %s\n" "$*" >&2; exit 1; }

have() { command -v "$1" >/dev/null 2>&1; }

# ---------- repo paths ----------
# Expected layout: repo/tools/scripts/common.sh
getRepoRoot() {
  cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd
}

# ---------- platform ----------
detectOs() {
  if [[ "${OSTYPE:-}" == "darwin"* ]]; then
    echo "macos"
  elif [[ -f /etc/os-release ]]; then
    echo "linux"
  else
    echo "unknown"
  fi
}

detectArch() {
  local arch
  arch="$(uname -m)"
  case "$arch" in
    x86_64|amd64) echo "x86_64" ;;
    arm64|aarch64) echo "arm64" ;;
    *) echo "$arch" ;;
  esac
}

