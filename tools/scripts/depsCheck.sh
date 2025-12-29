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
  tools/scripts/depsCheck.sh [--list]

Env:
  DEPS_CONFIG=... (default: $DEPS_CONFIG)
EOF
}

source_config() {
  [[ -f "$DEPS_CONFIG" ]] || die "Deps config not found: $DEPS_CONFIG"
  # shellcheck source=/dev/null
  source "$DEPS_CONFIG"
}

build_effective_deps() {
  local -a deps=()

  for group_name in "${DEPS_ENABLED_GROUPS[@]:-}"; do
    eval "deps+=(\"\${${group_name}[@]}\")"
  done

  if [[ "$NVIMCFG_OS" == "macos" ]]; then
    deps+=("${DEPS_MACOS[@]:-}")
  elif [[ "$NVIMCFG_OS" == "linux" ]]; then
    deps+=("${DEPS_LINUX[@]:-}")
  fi

  local -A seen=()
  EFFECTIVE_DEPS=()
  local d
  for d in "${deps[@]}"; do
    [[ -n "$d" ]] || continue
    if [[ -z "${seen[$d]:-}" ]]; then
      seen[$d]=1
      EFFECTIVE_DEPS+=("$d")
    fi
  done
}

main() {
  local list_only=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --list) list_only=1; shift ;;
      -h|--help) usage; exit 0 ;;
      *) die "Unknown arg: $1" ;;
    esac
  done

  source_config
  build_effective_deps

  if [[ "$list_only" == "1" ]]; then
    printf "%s\n" "${EFFECTIVE_DEPS[@]}"
    exit 0
  fi

  local missing=0
  local d
  for d in "${EFFECTIVE_DEPS[@]}"; do
    if have "$d"; then
      echo "OK   $d -> $(command -v "$d")"
    else
      echo "MISS $d"
      missing=1
    fi
  done

  if [[ "$missing" == "0" ]]; then
    log "All dependencies are present."
  else
    warn "Some dependencies are missing."
    exit 1
  fi
}

main "$@"

