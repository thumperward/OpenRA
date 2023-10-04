#! /bin/bash
# Copy AppStream metadata to the target directory
# Arguments:
#   SRC_PATH: Path to the root OpenRA directory
#   BUILD_PATH: Path to packaging filesystem root (e.g. /tmp/openra-build/ or "" for a local install)
#   SHARE_PATH: Parent path to the appdata directory (e.g. /usr/local/share)
#   MOD [MOD...]: One or more mod ids to copy (cnc, d2k, ra)
# Used by:
#   Makefile (install-linux-appdata target for local installs and downstream packaging)
set -euo pipefail

SRC_PATH="${1}"
BUILD_PATH="${2}"
SHARE_PATH="${3}"
shift 3
while [ -n "${1}" ]; do
  MOD_ID="${1}"
  SCREENSHOT_CNC=
  SCREENSHOT_D2K=
  SCREENSHOT_RA=
  if [ "${MOD_ID}" = "ra" ] || [ "${MOD_ID}" = "cnc" ] || [ "${MOD_ID}" = "d2k" ]; then
    if [ "${MOD_ID}" = "cnc" ]; then
      MOD_NAME="Tiberian Dawn"
      SCREENSHOT_CNC=" type=\"default\""
    fi

    if [ "${MOD_ID}" = "d2k" ]; then
      MOD_NAME="Dune 2000"
      SCREENSHOT_D2K=" type=\"default\""
    fi

    if [ "${MOD_ID}" = "ra" ]; then
      MOD_NAME="Red Alert"
      SCREENSHOT_RA=" type=\"default\""
    fi
  fi

  install -d "${BUILD_PATH}${SHARE_PATH}/metainfo"

  sed -e "s/{MODID}/${MOD_ID}/g" -e "s/{MOD_NAME}/${MOD_NAME}/g" -e "s/{SCREENSHOT_RA}/${SCREENSHOT_RA}/g" -e "s/{SCREENSHOT_CNC}/${SCREENSHOT_CNC}/g" -e "s/{SCREENSHOT_D2K}/${SCREENSHOT_D2K}/g" "${SRC_PATH}/packaging/linux/openra.metainfo.xml.in" >"${SRC_PATH}/packaging/linux/openra-${MOD_ID}.metainfo.xml"
  install -m644 "${SRC_PATH}/packaging/linux/openra-${MOD_ID}.metainfo.xml" "${BUILD_PATH}${SHARE_PATH}/metainfo"
  rm "${SRC_PATH}/packaging/linux/openra-${MOD_ID}.metainfo.xml"

  shift
done
