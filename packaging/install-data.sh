#! /bin/bash
# Copy the core engine and specified mod data to the target directory
# Arguments:
#   SRC_PATH: Path to the root OpenRA directory
#   DEST_PATH: Path to the root of the install destination (will be created if necessary)
#   MOD [MOD...]: One or more mod ids to copy (cnc, d2k, ra)
# Used by:
#   Makefile (install target for local installs and downstream packaging)
#   Linux AppImage packaging
#   macOS packaging
#   Windows packaging
#   Mod SDK Linux AppImage packaging
#   Mod SDK macOS packaging
#   Mod SDK Windows packaging
set -euo pipefail

SRC_PATH="${1}"
DEST_PATH="${2}"
shift 2

"${SRC_PATH}/packaging/fetch-geoip.sh"

echo "Installing engine files to ${DEST_PATH}"
for FILE in VERSION AUTHORS COPYING packaging/IP2LOCATION-LITE-DB1.IPV6.BIN.ZIP "packaging/global mix database.dat"; do
	install -m644 "${SRC_PATH}/${FILE}" "${DEST_PATH}"
done

cp -r "${SRC_PATH}/glsl" "${DEST_PATH}"

echo "Installing common mod files to ${DEST_PATH}"
install -d "${DEST_PATH}/mods"
cp -r "${SRC_PATH}/mods/common" "${DEST_PATH}/mods/"

while [ -n "${1:-}" ]; do
	MOD_ID="${1}"
	if [ "${MOD_ID}" = "ra" ] || [ "${MOD_ID}" = "cnc" ] || [ "${MOD_ID}" = "d2k" ]; then
		echo "Installing mod ${MOD_ID} to ${DEST_PATH}"
		cp -r "${SRC_PATH}/mods/${MOD_ID}" "${DEST_PATH}/mods/"
		cp -r "${SRC_PATH}/mods/modcontent" "${DEST_PATH}/mods/"
	fi

	shift
done
