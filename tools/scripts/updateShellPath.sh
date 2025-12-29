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
  tools/scripts/updateShellPath.sh add [--zshrc|--bashrc|--both]
  tools/scripts/updateShellPath.sh remove [--zshrc|--bashrc|--both]
  tools/scripts/updateShellPath.sh status [--zshrc|--bashrc|--both]

What it does:
  Adds/removes a managed PATH block pointing to:
    $NVIMCFG_NVIM_BIN_DIR

Notes:
  - Changes are applied to shell rc files (persisted).
  - After "add/remove" run: source ~/.zshrc  (or restart terminal).
EOF
}

pick_targets() {
  local mode="${1:-auto}"

  ZSHRC="$HOME/.zshrc"
  BASHRC="$HOME/.bashrc"

  TARGETS=()
  case "$mode" in
    --zshrc) TARGETS+=("$ZSHRC") ;;
    --bashrc) TARGETS+=("$BASHRC") ;;
    --both) TARGETS+=("$ZSHRC" "$BASHRC") ;;
    auto|"")
      # reasonable default: if zsh exists or $SHELL is zsh -> zshrc, else bashrc
      if [[ "${SHELL:-}" == */zsh ]] || [[ -n "${ZSH_VERSION:-}" ]]; then
        TARGETS+=("$ZSHRC")
      elif [[ "${SHELL:-}" == */bash ]] || [[ -n "${BASH_VERSION:-}" ]]; then
        TARGETS+=("$BASHRC")
      else
        # fallback: touch both, but prefer zshrc
        TARGETS+=("$ZSHRC")
      fi
      ;;
    *)
      die "Unknown target mode: $mode"
      ;;
  esac
}

block_begin="# >>> ErosVim:portable-nvim PATH >>>"
block_end="# <<< ErosVim:portable-nvim PATH <<<"

render_block() {
  cat <<EOF
$block_begin
# Added by ErosVim tools/scripts/updateShellPath.sh
# Neovim binary directory inside repo:
export PATH="$NVIMCFG_NVIM_BIN_DIR:\$PATH"
$block_end
EOF
}

ensure_file_exists() {
  local file="$1"
  if [[ ! -e "$file" ]]; then
    log "Creating $file"
    : > "$file"
  fi
}

has_block() {
  local file="$1"
  grep -Fq "$block_begin" "$file" && grep -Fq "$block_end" "$file"
}

remove_block() {
  local file="$1"
  if ! has_block "$file"; then
    warn "No managed block found in $file"
    return 0
  fi

  # Use perl for reliable multiline removal on macOS/Linux
  perl -0777 -i -pe "s/\Q$block_begin\E.*?\Q$block_end\E\n?//sg" "$file"
  log "Removed PATH block from $file"
}

add_block() {
  local file="$1"
  ensure_file_exists "$file"

  if has_block "$file"; then
    warn "Managed block already exists in $file (updating it)"
    remove_block "$file"
  fi

  # Append with a preceding newline if file not empty and doesn't end with newline
  if [[ -s "$file" ]]; then
    printf "\n" >> "$file"
  fi
  render_block >> "$file"
  log "Added PATH block to $file"
}

status_file() {
  local file="$1"
  if [[ -e "$file" ]]; then
    if has_block "$file"; then
      echo "OK   $file  (managed PATH block present)"
    else
      echo "NO   $file  (no managed PATH block)"
    fi
  else
    echo "N/A  $file  (file does not exist)"
  fi
}

main() {
  local action="${1:-}"
  shift || true

  local target_mode="auto"
  if [[ "${1:-}" == --zshrc || "${1:-}" == --bashrc || "${1:-}" == --both ]]; then
    target_mode="$1"
    shift || true
  fi

  case "$action" in
    add|remove|status) ;;
    -h|--help|"") usage; exit 0 ;;
    *) die "Unknown action: $action" ;;
  esac

  # sanity
  [[ -d "$NVIMCFG_NVIM_BIN_DIR" ]] || warn "Bin dir doesn't exist yet: $NVIMCFG_NVIM_BIN_DIR"
  have perl || die "perl is required (present by default on macOS and most Linux)"

  pick_targets "$target_mode"

  for f in "${TARGETS[@]}"; do
    case "$action" in
      add) add_block "$f" ;;
      remove) remove_block "$f" ;;
      status) status_file "$f" ;;
    esac
  done

  if [[ "$action" == "add" || "$action" == "remove" ]]; then
    echo
    echo "Apply changes:"
    echo "  source ~/.zshrc   # or restart terminal"
    echo
    echo "Expected nvim path:"
    echo "  $NVIMCFG_NVIM_BIN_DIR/nvim"
  fi
}

main "$@"

