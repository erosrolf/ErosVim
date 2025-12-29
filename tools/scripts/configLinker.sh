#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"
# shellcheck source=checkEnvironment.sh
source "$SCRIPT_DIR/checkEnvironment.sh"

usage() {
  cat <<EOF
Usage:
  tools/scripts/linkNvimConfig.sh add
  tools/scripts/linkNvimConfig.sh remove
  tools/scripts/linkNvimConfig.sh status

Link:
  $NVIMCFG_CONFIG_LINK  ->  $NVIMCFG_CONFIG_DIR
EOF
}

link_path() { echo "$NVIMCFG_CONFIG_LINK"; }
target_path() { echo "$NVIMCFG_CONFIG_DIR"; }

add_link() {
  local link target backup
  link="$(link_path)"
  target="$(target_path)"

  [[ -d "$target" ]] || die "Config directory not found: $target"
  mkdir -p "$(dirname "$link")"

  if [[ -L "$link" ]]; then
    local cur
    cur="$(readlink "$link")"
    if [[ "$cur" == "$target" ]]; then
      log "Symlink already correct: $link -> $target"
      return 0
    fi
    warn "Replacing existing symlink: $link -> $cur"
    rm -f "$link"
  elif [[ -e "$link" ]]; then
    backup="$link.backup.$(date +%Y%m%d%H%M%S)"
    warn "$link exists and is not a symlink. Backing up to: $backup"
    mv "$link" "$backup"
  fi

  ln -s "$target" "$link"
  log "Linked: $link -> $target"
}

remove_link() {
  local link target
  link="$(link_path)"
  target="$(target_path)"

  if [[ ! -e "$link" ]]; then
    warn "Nothing to remove: $link does not exist"
    return 0
  fi

  if [[ -L "$link" ]]; then
    local cur
    cur="$(readlink "$link")"
    if [[ "$cur" == "$target" ]]; then
      rm -f "$link"
      log "Removed symlink: $link"
      return 0
    fi
    warn "Refusing to remove: $link is a symlink but points to $cur (not our target)"
    return 0
  fi

  warn "Refusing to remove: $link exists but is not a symlink"
}

status_link() {
  local link target
  link="$(link_path)"
  target="$(target_path)"

  if [[ -L "$link" ]]; then
    local cur
    cur="$(readlink "$link")"
    if [[ "$cur" == "$target" ]]; then
      echo "OK   $link -> $cur"
    else
      echo "WARN $link -> $cur (expected -> $target)"
    fi
  elif [[ -e "$link" ]]; then
    echo "WARN $link exists but is not a symlink"
  else
    echo "NO   $link (not present)"
  fi
}

main() {
  local action="${1:-}"
  case "$action" in
    add) add_link ;;
    remove) remove_link ;;
    status) status_link ;;
    -h|--help|"") usage; exit 0 ;;
    *) die "Unknown action: $action" ;;
  esac
}

main "$@"

