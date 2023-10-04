#! /bin/bash
# Copy launch wrappers, application icons, desktop, and MIME files to the target directory
# Arguments:
#   SRC_PATH: Path to the root OpenRA directory
#   BUILD_PATH: Path to packaging filesystem root (e.g. /tmp/openra-build/ or "" for a local install)
#   OPENRA_PATH: Path to the OpenRA installation (e.g. /usr/local/lib/openra)
#   BIN_PATH: Path to install wrapper scripts (e.g. /usr/local/bin)
#   SHARE_PATH: Parent path to the icons and applications directory (e.g. /usr/local/share)
#   VERSION: OpenRA version string
#   MOD [MOD...]: One or more mod ids to copy (cnc, d2k, ra)
# Used by:
#   Makefile (install-linux-shortcuts target for local installs and downstream packaging)
set -euo pipefail

SRC_PATH="${1}"
BUILD_PATH="${2}"
OPENRA_PATH="${3}"
BIN_PATH="${4}"
SHARE_PATH="${5}"
VERSION="${6}"
shift 6

while [ -n "${1}" ]; do
  MOD_ID="${1}"
  if [ "${MOD_ID}" = "ra" ] || [ "${MOD_ID}" = "cnc" ] || [ "${MOD_ID}" = "d2k" ]; then
    if [ "${MOD_ID}" = "cnc" ]; then
      MOD_NAME="Tiberian Dawn"
    fi

    if [ "${MOD_ID}" = "d2k" ]; then
      MOD_NAME="Dune 2000"
    fi

    if [ "${MOD_ID}" = "ra" ]; then
      MOD_NAME="Red Alert"
    fi

    # wrapper scripts
    install -d "${BUILD_PATH}/${BIN_PATH}"
    sed -e 's/{DEBUG}/--debug/' -e "s|{GAME_INSTALL_DIR}|${OPENRA_PATH}|" -e "s|{BIN_DIR}|${BIN_PATH}|" -e "s/{MODID}/${MOD_ID}/g" -e "s/{TAG}/${VERSION}/g" -e "s/{MODNAME}/${MOD_NAME}/g" "${SRC_PATH}/packaging/linux/openra.in" >"${SRC_PATH}/packaging/linux/openra-${MOD_ID}"
    sed -e 's/{DEBUG}/--debug/' -e "s|{GAME_INSTALL_DIR}|${OPENRA_PATH}|" -e "s/{MODID}/${MOD_ID}/g" "${SRC_PATH}/packaging/linux/openra-server.in" >"${SRC_PATH}/packaging/linux/openra-${MOD_ID}-server"
    install -m755 "${SRC_PATH}/packaging/linux/openra-${MOD_ID}" "${BUILD_PATH}/${BIN_PATH}"
    install -m755 "${SRC_PATH}/packaging/linux/openra-${MOD_ID}-server" "${BUILD_PATH}/${BIN_PATH}"
    rm "${SRC_PATH}/packaging/linux/openra-${MOD_ID}" "${SRC_PATH}/packaging/linux/openra-${MOD_ID}-server"

    # desktop files
    install -d "${BUILD_PATH}${SHARE_PATH}/applications"
    sed -e "s/{MODID}/${MOD_ID}/g" -e "s/{MODNAME}/${MOD_NAME}/g" -e "s/{TAG}/${VERSION}/g" "${SRC_PATH}/packaging/linux/openra.desktop.in" >"${SRC_PATH}/packaging/linux/openra-${MOD_ID}.desktop"
    install -m644 "${SRC_PATH}/packaging/linux/openra-${MOD_ID}.desktop" "${BUILD_PATH}${SHARE_PATH}/applications"
    rm "${SRC_PATH}/packaging/linux/openra-${MOD_ID}.desktop"

    # icons
    for SIZE in 16x16 32x32 48x48 64x64 128x128; do
      install -d "${BUILD_PATH}${SHARE_PATH}/icons/hicolor/${SIZE}/apps"
      install -m644 "${SRC_PATH}/res/artwork/${MOD_ID}_${SIZE}.png" "${BUILD_PATH}${SHARE_PATH}/icons/hicolor/${SIZE}/apps/openra-${MOD_ID}.png"
    done

    if [ "${MOD_ID}" = "ra" ] || [ "${MOD_ID}" = "cnc" ]; then
      install -d "${BUILD_PATH}${SHARE_PATH}/icons/hicolor/scalable/apps"
      install -m644 "${SRC_PATH}/res/artwork/${MOD_ID}_scalable.svg" "${BUILD_PATH}${SHARE_PATH}/icons/hicolor/scalable/apps/openra-${MOD_ID}.svg"
    fi

    # MIME info
    install -d "${BUILD_PATH}${SHARE_PATH}/mime/packages"
    sed -e "s/{MODID}/${MOD_ID}/g" -e "s/{TAG}/${VERSION}/g" "${SRC_PATH}/packaging/linux/openra-mimeinfo.xml.in" >"${SRC_PATH}/packaging/linux/openra-${MOD_ID}.xml"
    install -m644 "${SRC_PATH}/packaging/linux/openra-${MOD_ID}.xml" "${BUILD_PATH}${SHARE_PATH}/mime/packages/openra-${MOD_ID}.xml"
    rm "${SRC_PATH}/packaging/linux/openra-${MOD_ID}.xml"
  fi

  shift
done
