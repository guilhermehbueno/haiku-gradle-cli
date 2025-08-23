#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# --- Configuration ---
INSTALL_DIR="${HOME}/.haiku-gradle-cli"
BIN_DIR="${HOME}/.local/bin"
REPO_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
VERSION_FILE="${REPO_ROOT}/VERSION"

# --- Colors and Logging ---
C_RESET='\033[0m'
C_RED='\033[0;31m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[0;33m'
C_BLUE='\033[0;34m'

log() {
  echo -e "${C_BLUE}==>${C_RESET} ${1}"
}

warn() {
  echo -e "${C_YELLOW}WARN:${C_RESET} ${1}" >&2
}

die() {
  echo -e "${C_RED}ERROR:${C_RESET} ${1}" >&2
  exit 1
}

# --- Main Logic ---
main() {
  log "Starting haiku-gradle-cli installation..."

  if [[ ! -f "$VERSION_FILE" ]]; then
    die "VERSION file not found in repository root. Cannot proceed."
  fi
  local version
  version=$(cat "$VERSION_FILE")
  log "Found version ${version}."

  log "Creating installation directories..."
  mkdir -p "${INSTALL_DIR}"
  mkdir -p "${BIN_DIR}"

  log "Copying application files to ${INSTALL_DIR}..."
  # Use cp to be more portable than rsync.
  # Ensure the destination directory exists and is clean.
  rm -rf "${INSTALL_DIR}/templates"
  mkdir -p "${INSTALL_DIR}/templates"
  cp -r "${REPO_ROOT}/templates/"* "${INSTALL_DIR}/templates/"
  cp "${REPO_ROOT}/main.sh" "${INSTALL_DIR}/main.sh"
  cp "${REPO_ROOT}/VERSION" "${INSTALL_DIR}/VERSION"

  log "Making main script executable..."
  chmod +x "${INSTALL_DIR}/main.sh"

  log "Creating symlink at ${BIN_DIR}/haiku-gradle..."
  ln -sf "${INSTALL_DIR}/main.sh" "${BIN_DIR}/haiku-gradle"

  log "${C_GREEN}Installation complete!${C_RESET}"
  echo
  log "The 'haiku-gradle' command is now available at:"
  echo "  ${BIN_DIR}/haiku-gradle"
  echo
  log "Please ensure '${BIN_DIR}' is in your PATH."
  echo "You can check by running: 'echo \$PATH'"
  echo "If it's not, add the following to your shell profile (~/.bashrc, ~/.zshrc, etc.):"
  echo "  export PATH=\"${BIN_DIR}:\$PATH\""
  echo
  log "You can verify the installation by running:"
  echo "  haiku-gradle info"
}

# --- Run ---
main "$@"
