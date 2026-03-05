#!/bin/bash
# scripts/install-deps.sh
# Installs all required tools on macOS (brew) or Linux (apt/curl)

set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
ok()   { echo -e "${GREEN}[OK]${NC}    $*"; }
skip() { echo -e "${YELLOW}[SKIP]${NC}  $* already installed"; }

OS="$(uname -s)"

install_brew_or_apt() {
  local pkg=$1
  local cmd=${2:-$1}
  if command -v "$cmd" &>/
