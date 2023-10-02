#! /bin/bash
# Copy the core engine and specified mod data to the target directory
# Used by:
#   Makefile (install target for local installs and downstream packaging)
#   Linux AppImage packaging
#   macOS packaging
#   Windows packaging
#   Mod SDK Linux AppImage packaging
#   Mod SDK macOS packaging
#   Mod SDK Windows packaging
set -euo pipefail

SRC_PATH="${1}"  # Path to the root OpenRA directory
DEST_PATH="${2}" # Path to the root of the install destination
shift 2

"${SRC_PATH}/packaging/fetch-geoip.sh"

echo "Installing engine files to ${DEST_PATH}..."

files=(
	VERSION AUTHORS COPYING
	packaging/IP2LOCATION-LITE-DB1.IPV6.BIN.ZIP
	"packaging/global mix database.dat"
)
for file in "${files[@]}"; do
	install -m644 "${SRC_PATH}/${file}" "${DEST_PATH}"
done

echo "Installing resources to ${DEST_PATH}"
cp -r "${SRC_PATH}/res/glsl" "${DEST_PATH}"

echo "Installing common mod files to ${DEST_PATH}"
install -d "${DEST_PATH}/mods"
cp -r "${SRC_PATH}/mods/common" "${DEST_PATH}/mods/"

while [ -n "${1:-}" ]; do # One or more mod ids to copy (cnc, d2k, ra)
	MOD_ID="${1}"
	if [ "${MOD_ID}" = "ra" ] || [ "${MOD_ID}" = "cnc" ] || [ "${MOD_ID}" = "d2k" ]; then
		echo "Installing mod ${MOD_ID} to ${DEST_PATH}"
		cp -r "${SRC_PATH}/mods/${MOD_ID}" "${DEST_PATH}/mods/"
		cp -r "${SRC_PATH}/mods/modcontent" "${DEST_PATH}/mods/"
	fi

	shift
done
