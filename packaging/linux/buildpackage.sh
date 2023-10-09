#! /bin/bash
set -euo pipefail

function linux_deps() {
	command -v tar >/dev/null 2>&1 || {
		echo >&2 "Linux packaging requires tar."
		exit 1
	}
	command -v curl >/dev/null 2>&1 || command -v wget >/dev/null 2>&1 || {
		echo >&2 "Linux packaging requires curl or wget."
		exit 1
	}
	command -v appimagetool-x86_64.AppImage >/dev/null 2>&1 || {
		echo >&2 "Linux packaging requires appimagetool-x86_64.AppImage."
		exit 1
	}
}

function build_linux_appimage() {
	MOD_ID=${1}
	DISPLAY_NAME=${2}
	DISCORD_ID=${3}
	APPDIR="$(pwd)/${MOD_ID}/build/.appdir"
	APPIMAGE="OpenRA-${DISPLAY_NAME// /-})${SUFFIX}-x86_64.AppImage"

	IS_D2K="False"
	if [ "${MOD_ID}" = "d2k" ]; then
		IS_D2K="True"
	fi

	../shared/install-assemblies.sh "${SRCDIR}" "${APPDIR}/usr/lib/openra" "linux-x64" "net6" "True" "True" "${IS_D2K}"
	../shared/install-data.sh "${SRCDIR}" "${APPDIR}/usr/lib/openra" "${MOD_ID}"
	echo "${TAG}" >"${APPDIR}/usr/lib/openra/VERSION"
	../shared/set-mod-version.sh "${TAG}" "${APPDIR}/usr/lib/openra/mods/${MOD_ID}/mod.yaml" "${APPDIR}/usr/lib/openra/mods/modcontent/mod.yaml"

	# Add launcher and icons
	sed "s/{MODID}/${MOD_ID}/g" AppRun.in | sed "s/{MODNAME}/${DISPLAY_NAME}/g" >"${APPDIR}/AppRun"
	chmod 0755 "${APPDIR}/AppRun"

	mkdir -p "${APPDIR}/usr/share/applications"
	# Note that the non-discord version of the desktop file is used by the Mod SDK and must be maintained in parallel with the discord version!
	sed "s/{MODID}/${MOD_ID}/g" openra.desktop.discord.in | sed "s/{MODNAME}/${DISPLAY_NAME}/g" | sed "s/{TAG}/${TAG}/g" | sed "s/{DISCORDAPPID}/${DISCORD_ID}/g" >"${APPDIR}/usr/share/applications/openra-${MOD_ID}.desktop"
	chmod 0755 "${APPDIR}/usr/share/applications/openra-${MOD_ID}.desktop"
	cp "${APPDIR}/usr/share/applications/openra-${MOD_ID}.desktop" "${APPDIR}/openra-${MOD_ID}.desktop"

	mkdir -p "${APPDIR}/usr/share/mime/packages"
	# Note that the non-discord version of the mimeinfo file is used by the Mod SDK and must be maintained in parallel with the discord version!
	sed "s/{MODID}/${MOD_ID}/g" openra-mimeinfo.xml.discord.in | sed "s/{TAG}/${TAG}/g" | sed "s/{DISCORDAPPID}/${DISCORD_ID}/g" >"${APPDIR}/usr/share/mime/packages/openra-${MOD_ID}.xml"
	chmod 0755 "${APPDIR}/usr/share/mime/packages/openra-${MOD_ID}.xml"

	if [ -f "${ARTWORK_DIR}/${MOD_ID}_scalable.svg" ]; then
		install -Dm644 "${ARTWORK_DIR}/${MOD_ID}_scalable.svg" "${APPDIR}/usr/share/icons/hicolor/scalable/apps/openra-${MOD_ID}.svg"
	fi

	for i in 16x16 32x32 48x48 64x64 128x128 256x256 512x512 1024x1024; do
		if [ -f "${ARTWORK_DIR}/${MOD_ID}_${i}.png" ]; then
			install -Dm644 "${ARTWORK_DIR}/${MOD_ID}_${i}.png" "${APPDIR}/usr/share/icons/hicolor/${i}/apps/openra-${MOD_ID}.png"
			install -m644 "${ARTWORK_DIR}/${MOD_ID}_${i}.png" "${APPDIR}/openra-${MOD_ID}.png"
		fi
	done

	mkdir -p "${APPDIR}/usr/bin"
	sed "s/{MODID}/${MOD_ID}/g" openra.appimage.in | sed "s/{TAG}/${TAG}/g" | sed "s/{MODNAME}/${DISPLAY_NAME}/g" >"${APPDIR}/usr/bin/openra-${MOD_ID}"
	chmod 0755 "${APPDIR}/usr/bin/openra-${MOD_ID}"

	sed "s/{MODID}/${MOD_ID}/g" openra-server.appimage.in >"${APPDIR}/usr/bin/openra-${MOD_ID}-server"
	chmod 0755 "${APPDIR}/usr/bin/openra-${MOD_ID}-server"

	sed "s/{MODID}/${MOD_ID}/g" openra-utility.appimage.in >"${APPDIR}/usr/bin/openra-${MOD_ID}-utility"
	chmod 0755 "${APPDIR}/usr/bin/openra-${MOD_ID}-utility"

	install -m 0755 gtk-dialog.py "${APPDIR}/usr/bin/gtk-dialog.py"

	mkdir -p "${OUTPUTDIR}"
	# Embed update metadata if (and only if) compiled on GitHub Actions
	if [ -n "${GITHUB_REPOSITORY:-}" ]; then
		ARCH=x86_64 appimagetool-x86_64.AppImage --appimage-extract-and-run --no-appstream -u "zsync|https://master.openra.net/appimagecheck.zsync?mod=${MOD_ID}&channel=${UPDATE_CHANNEL}" "${APPDIR}" "${OUTPUTDIR}/${APPIMAGE}"
		zsyncmake -u "https://github.com/${GITHUB_REPOSITORY}/releases/download/${TAG}/${APPIMAGE}" -o "${OUTPUTDIR}/${APPIMAGE}.zsync" "${OUTPUTDIR}/${APPIMAGE}"
	else
		ARCH=x86_64 appimagetool-x86_64.AppImage --appimage-extract-and-run --no-appstream "${APPDIR}" "${OUTPUTDIR}/${APPIMAGE}"
	fi

	rm -rf "${APPDIR}"
}

cd "$(dirname "$0")"

TAG="${1:-$(git tag | tail -1)}" # Tag to release
SRCDIR="$(pwd)/../.."
OUTPUTDIR="${SRCDIR}/build/linux" # Path to the final asset destination

ARTWORK_DIR="${SRCDIR}/res/artwork"
if [[ ${TAG} == release* ]]; then
	UPDATE_CHANNEL="release"
	SUFFIX=""
elif [[ ${TAG} == playtest* ]]; then
	UPDATE_CHANNEL="playtest"
	SUFFIX="-playtest"
elif [[ ${TAG} == pkgtest* ]]; then
	UPDATE_CHANNEL="pkgtest"
	SUFFIX="-pkgtest"
else
	UPDATE_CHANNEL=""
	SUFFIX="-devel"
fi

linux_deps

build_linux_appimage "ra" "Red Alert" "699222659766026240"
build_linux_appimage "cnc" "Tiberian Dawn" "699223250181292033"
build_linux_appimage "d2k" "Dune 2000" "712711732770111550"
