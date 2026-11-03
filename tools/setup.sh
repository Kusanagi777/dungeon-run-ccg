#!/usr/bin/env bash
# Idempotent toolchain setup for Dungeon Run CCG.
#
# Installs:
#   - Godot 4.7.2 (Linux x86_64, standard build) to $GODOT_HOME, symlinked as `godot` on PATH
#   - Godot 4.7.2 export templates (optional, EXPORT_TEMPLATES=1) for Windows builds
#   - gdUnit4 into addons/gdUnit4 if it is missing
#
# Safe to re-run. Designed for the cloud dev container and CI; on Windows install Godot by hand.

set -euo pipefail

GODOT_VERSION="${GODOT_VERSION:-4.7.2}"
GODOT_TAG="${GODOT_VERSION}-stable"
GODOT_HOME="${GODOT_HOME:-$HOME/.local/share/godot/${GODOT_TAG}}"
BIN_DIR="${BIN_DIR:-$HOME/.local/bin}"
GDUNIT4_TAG="${GDUNIT4_TAG:-v6.2.3}"
EXPORT_TEMPLATES="${EXPORT_TEMPLATES:-0}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_BIN_NAME="Godot_v${GODOT_TAG}_linux.x86_64"
GODOT_URL="https://github.com/godotengine/godot/releases/download/${GODOT_TAG}/${GODOT_BIN_NAME}.zip"
TEMPLATES_URL="https://github.com/godotengine/godot/releases/download/${GODOT_TAG}/Godot_v${GODOT_TAG}_export_templates.tpz"

log() { printf '[setup] %s\n' "$*"; }

install_godot() {
  if [ -x "${GODOT_HOME}/${GODOT_BIN_NAME}" ]; then
    log "Godot ${GODOT_TAG} already present at ${GODOT_HOME}"
  else
    log "Downloading Godot ${GODOT_TAG}"
    mkdir -p "${GODOT_HOME}"
    local tmp
    tmp="$(mktemp -d)"
    curl -fsSL -o "${tmp}/godot.zip" "${GODOT_URL}"
    unzip -q -o "${tmp}/godot.zip" -d "${GODOT_HOME}"
    chmod +x "${GODOT_HOME}/${GODOT_BIN_NAME}"
    rm -rf "${tmp}"
  fi
  mkdir -p "${BIN_DIR}"
  ln -sfn "${GODOT_HOME}/${GODOT_BIN_NAME}" "${BIN_DIR}/godot"
  case ":${PATH}:" in
    *":${BIN_DIR}:"*) ;;
    *) log "NOTE: add ${BIN_DIR} to PATH (export PATH=\"${BIN_DIR}:\$PATH\")" ;;
  esac
  log "godot -> $("${BIN_DIR}/godot" --headless --version | tail -1)"
}

install_export_templates() {
  [ "${EXPORT_TEMPLATES}" = "1" ] || { log "Skipping export templates (set EXPORT_TEMPLATES=1 to install)"; return; }
  local dest="$HOME/.local/share/godot/export_templates/${GODOT_VERSION}.stable"
  if [ -f "${dest}/windows_release_x86_64.exe" ]; then
    log "Export templates already installed"
    return
  fi
  log "Downloading export templates (large)"
  local tmp
  tmp="$(mktemp -d)"
  curl -fsSL -o "${tmp}/templates.tpz" "${TEMPLATES_URL}"
  mkdir -p "${dest}"
  unzip -q -o "${tmp}/templates.tpz" -d "${tmp}"
  mv "${tmp}"/templates/* "${dest}/"
  rm -rf "${tmp}"
  log "Export templates installed to ${dest}"
}

install_gdunit4() {
  local dest="${REPO_ROOT}/addons/gdUnit4"
  if [ -f "${dest}/plugin.cfg" ]; then
    log "gdUnit4 already present"
    return
  fi
  log "Installing gdUnit4 ${GDUNIT4_TAG}"
  local tmp
  tmp="$(mktemp -d)"
  git clone --quiet --depth 1 --branch "${GDUNIT4_TAG}" https://github.com/MikeSchulze/gdUnit4.git "${tmp}/gdUnit4"
  mkdir -p "${REPO_ROOT}/addons"
  cp -r "${tmp}/gdUnit4/addons/gdUnit4" "${dest}"
  rm -rf "${tmp}"
  log "gdUnit4 installed to addons/gdUnit4"
}

install_godot
install_export_templates
install_gdunit4
log "Done."
