#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

# This script supports 2 modes:
# 1) source tools/scripts/checkEnvironment.sh
#    -> exports variables into current shell
# 2) tools/scripts/checkEnvironment.sh
#    -> prints a summary and exits

ROOT="$(getRepoRoot)"
OS="$(detectOs)"
ARCH="$(detectArch)"

# repo layout: config/ contains nvim config
CONFIG_DIR="$ROOT/config"

# where to install portable nvim (not committed)
LOCAL_DIR="${NVIM_PREFIX:-$ROOT/.local}"
NVIM_BASE_DIR="$LOCAL_DIR/nvim"
NVIM_VERSION="${NVIM_VERSION:-v0.10.3}"
NVIM_INSTALL_DIR="$NVIM_BASE_DIR/${OS}-${ARCH}"
NVIM_BIN_DIR="$NVIM_INSTALL_DIR/bin"

# where to link nvim config
NVIM_CONFIG_LINK="${NVIM_CONFIG_LINK:-$HOME/.config/nvim}"

export NVIMCFG_REPO_ROOT="$ROOT"
export NVIMCFG_OS="$OS"
export NVIMCFG_ARCH="$ARCH"
export NVIMCFG_CONFIG_DIR="$CONFIG_DIR"
export NVIMCFG_LOCAL_DIR="$LOCAL_DIR"
export NVIMCFG_NVIM_VERSION="$NVIM_VERSION"
export NVIMCFG_NVIM_INSTALL_DIR="$NVIM_INSTALL_DIR"
export NVIMCFG_NVIM_BIN_DIR="$NVIM_BIN_DIR"
export NVIMCFG_CONFIG_LINK="$NVIM_CONFIG_LINK"

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  cat <<EOF
Environment summary:
  NVIMCFG_REPO_ROOT=$NVIMCFG_REPO_ROOT
  NVIMCFG_OS=$NVIMCFG_OS
  NVIMCFG_ARCH=$NVIMCFG_ARCH
  NVIMCFG_CONFIG_DIR=$NVIMCFG_CONFIG_DIR
  NVIMCFG_LOCAL_DIR=$NVIMCFG_LOCAL_DIR
  NVIMCFG_NVIM_VERSION=$NVIMCFG_NVIM_VERSION
  NVIMCFG_NVIM_INSTALL_DIR=$NVIMCFG_NVIM_INSTALL_DIR
  NVIMCFG_NVIM_BIN_DIR=$NVIMCFG_NVIM_BIN_DIR
  NVIMCFG_CONFIG_LINK=$NVIMCFG_CONFIG_LINK

Detected tools:
  git:   $(have git && echo yes || echo no)
  curl:  $(have curl && echo yes || echo no)
  tar:   $(have tar && echo yes || echo no)
EOF
fi

