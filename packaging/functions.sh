#!/bin/sh
# Helper functions for packaging and installing OpenRA
set -euo pipefail

function install_assemblies() (
	# Compile and publish the core engine and specified mod assemblies to the target directory
	# Arguments:
	#   SRC_PATH: Path to the root OpenRA directory
	#   DEST_PATH: Path to the root of the install destination (will be created if necessary)
	#   TARGETPLATFORM: Platform type (win-x86, win-x64, osx-x64, osx-arm64, linux-x64, linux-arm64, unix-generic)
	#   RUNTIME: Runtime type (net6, mono)
	#   COPY_GENERIC_LAUNCHER: If set to True the OpenRA.exe will also be copied (True, False)
	#   COPY_CNC_DLL: If set to True the OpenRA.Mods.Cnc.dll will also be copied (True, False)
	#   COPY_D2K_DLL: If set to True the OpenRA.Mods.D2k.dll will also be copied (True, False)
	# Used by:
	#   Makefile (install target for local installs and downstream packaging)
	#   Windows packaging
	#   macOS packaging
	#   Linux AppImage packaging
	#   Mod SDK Windows packaging
	#   Mod SDK macOS packaging
	#   Mod SDK Linux AppImage packaging
	SRC_PATH="${1}"
	DEST_PATH="${2}"
	TARGETPLATFORM="${3}"
	RUNTIME="${4}"
	COPY_GENERIC_LAUNCHER="${5}"
	COPY_CNC_DLL="${6}"
	COPY_D2K_DLL="${7}"

	ORIG_PWD=$(pwd)
	cd "${SRC_PATH}"

	if [ "${RUNTIME}" = "mono" ]; then
		echo "Building assemblies"
		rm -rf "${SRC_PATH}/OpenRA."*/obj || :
		rm -rf "${SRC_PATH:?}/bin" || :

		msbuild -verbosity:m -nologo -t:Build -restore -p:Configuration=Release -p:TargetPlatform="${TARGETPLATFORM}"
		if [ "${TARGETPLATFORM}" = "unix-generic" ]; then
			./configure-system-libraries.sh
		fi

		if [ "${COPY_GENERIC_LAUNCHER}" != "True" ]; then
			rm "${SRC_PATH}/bin/OpenRA.dll"
		fi

		if [ "${COPY_CNC_DLL}" != "True" ]; then
			rm "${SRC_PATH}/bin/OpenRA.Mods.Cnc.dll"
		fi

		if [ "${COPY_D2K_DLL}" != "True" ]; then
			rm "${SRC_PATH}/bin/OpenRA.Mods.D2k.dll"
		fi

		cd "${ORIG_PWD}"

		echo "Installing engine to ${DEST_PATH}"
		install -d "${DEST_PATH}"

		for LIB in "${SRC_PATH}/bin/"*.dll "${SRC_PATH}/bin/"*.dll.config; do
			install -m644 "${LIB}" "${DEST_PATH}"
		done

		if [ "${TARGETPLATFORM}" = "linux-x64" ] || [ "${TARGETPLATFORM}" = "linux-arm64" ]; then
			for LIB in "${SRC_PATH}/bin/"*.so; do
				install -m755 "${LIB}" "${DEST_PATH}"
			done
		fi

		if [ "${TARGETPLATFORM}" = "osx-x64" ] || [ "${TARGETPLATFORM}" = "osx-arm64" ]; then
			for LIB in "${SRC_PATH}/bin/"*.dylib; do
				install -m755 "${LIB}" "${DEST_PATH}"
			done
		fi
	else
		dotnet publish -c Release -p:TargetPlatform="${TARGETPLATFORM}" -p:CopyGenericLauncher="${COPY_GENERIC_LAUNCHER}" -p:CopyCncDll="${COPY_CNC_DLL}" -p:CopyD2kDll="${COPY_D2K_DLL}" -r "${TARGETPLATFORM}" -p:PublishDir="${DEST_PATH}" --self-contained true
	fi
	cd "${ORIG_PWD}"
)

function install_data() (
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

	SRC_PATH="${1}"
	DEST_PATH="${2}"
	shift 2

	"${SRC_PATH}"/fetch-geoip.sh

	echo "Installing engine files to ${DEST_PATH}"
	for FILE in VERSION AUTHORS COPYING IP2LOCATION-LITE-DB1.IPV6.BIN.ZIP "global mix database.dat"; do
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
)

install_windows_launcher() (
	# Compile and publish (using Mono) a windows launcher with the specified mod details to the target directory
	# Arguments:
	#   SRC_PATH: Path to the root OpenRA directory
	#   DEST_PATH: Path to the root of the install destination (will be created if necessary)
	#   TARGETPLATFORM: Platform type (win-x86, win-x64)
	#   MOD_ID: Mod id to launch (e.g. "ra")
	#   LAUNCHER_NAME: Filename (without the .exe extension) for the launcher
	#   MOD_NAME: Human-readable mod name to show in the crash dialog (e.g. "Red Alert")
	#   ICON_PATH: Path to a windows .ico file
	#   FAQ_URL: URL to load when the "View FAQ" button is pressed in the crash dialog (e.g. https://wiki.openra.net/FAQ)
	# Used by:
	#   Windows packaging
	#   Mod SDK Windows packaging
	SRC_PATH="${1}"
	DEST_PATH="${2}"
	TARGETPLATFORM="${3}"
	MOD_ID="${4}"
	LAUNCHER_NAME="${5}"
	MOD_NAME="${6}"
	FAQ_URL="${7}"
	VERSION="${8}"

	rm -rf "${SRC_PATH}/OpenRA.WindowsLauncher/obj" || :

	# See https://learn.microsoft.com/en-us/dotnet/core/tools/dotnet-publish for details.
	# Unfortunately there doesn't seem to be a way to set FileDescription and it uses the value of -p:LauncherName.
	# -p:Product sets the "Product name" field.
	# -p:InformationalVersion seems to set the "Product version" field.
	# -p:DisplayName doesn't seem to have a visible effect?
	dotnet publish "${SRC_PATH}/OpenRA.WindowsLauncher/OpenRA.WindowsLauncher.csproj" -c Release -r "${TARGETPLATFORM}" -p:LauncherName="${LAUNCHER_NAME}",TargetPlatform="${TARGETPLATFORM}",ModID="${MOD_ID}",PublishDir="${DEST_PATH}",FaqUrl="${FAQ_URL}",InformationalVersion="${VERSION}" --self-contained true

	# NET 6 is unable to customize the application host for windows when compiling from Linux,
	# so we must patch the properties we need in the PE header.
	# Setting the application icon requires an external tool, so is left to the calling code
	python3 "${SRC_PATH}/packaging/windows/fixlauncher.py" "${DEST_PATH}/${LAUNCHER_NAME}.exe"
)

function set_engine_version() (
	# Write a version string to the engine VERSION file
	# Arguments:
	#   VERSION: OpenRA version string
	#   DEST_PATH: Path to the root of the install destination
	# Used by:
	#   Makefile (install target for local installs and downstream packaging)
	#   Linux AppImage packaging
	#   macOS packaging
	#   Windows packaging
	#   Mod SDK Linux AppImage packaging
	#   Mod SDK macOS packaging
	#   Mod SDK Windows packaging
	VERSION="${1}"
	DEST_PATH="${2}"
	echo "${VERSION}" > "${DEST_PATH}/VERSION"
)

function set_mod_version() (
	# Write a version string to a list of specified mod.yamls
	# Arguments:
	#   VERSION: OpenRA version string
	#   MOD_YAML_PATH [MOD_YAML_PATH...]: One or more mod.yaml files to update
	# Used by:
	#   Makefile (install target for local installs and downstream packaging)
	#   Linux AppImage packaging
	#   macOS packaging
	#   Windows packaging
	#   Mod SDK Linux AppImage packaging
	#   Mod SDK macOS packaging
	#   Mod SDK Windows packaging
	VERSION="${1}"
	shift
	while [ -n "${1:-}" ]; do
		MOD_YAML_PATH="${1}"
		awk -v v="${VERSION}" '{sub("Version:.*$", "Version: " v); print $0}' "${MOD_YAML_PATH}" > "${MOD_YAML_PATH}.tmp"
		awk -v v="${VERSION}" '{sub("/[^/]*: User$", "/"v ": User"); print $0}' "${MOD_YAML_PATH}.tmp" > "${MOD_YAML_PATH}"
		rm "${MOD_YAML_PATH}.tmp"
		shift
	done
)

function install_linux_shortcuts() (
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
			sed -e 's/{DEBUG}/--debug/' -e "s|{GAME_INSTALL_DIR}|${OPENRA_PATH}|" -e "s|{BIN_DIR}|${BIN_PATH}|" -e "s/{MODID}/${MOD_ID}/g" -e "s/{TAG}/${VERSION}/g" -e "s/{MODNAME}/${MOD_NAME}/g" "${SRC_PATH}/packaging/linux/openra.in" > "${SRC_PATH}/packaging/linux/openra-${MOD_ID}"
			sed -e 's/{DEBUG}/--debug/' -e "s|{GAME_INSTALL_DIR}|${OPENRA_PATH}|" -e "s/{MODID}/${MOD_ID}/g" "${SRC_PATH}/packaging/linux/openra-server.in" > "${SRC_PATH}/packaging/linux/openra-${MOD_ID}-server"
			install -m755 "${SRC_PATH}/packaging/linux/openra-${MOD_ID}" "${BUILD_PATH}/${BIN_PATH}"
			install -m755 "${SRC_PATH}/packaging/linux/openra-${MOD_ID}-server" "${BUILD_PATH}/${BIN_PATH}"
			rm "${SRC_PATH}/packaging/linux/openra-${MOD_ID}" "${SRC_PATH}/packaging/linux/openra-${MOD_ID}-server"

			# desktop files
			install -d "${BUILD_PATH}${SHARE_PATH}/applications"
			sed -e "s/{MODID}/${MOD_ID}/g" -e "s/{MODNAME}/${MOD_NAME}/g" -e "s/{TAG}/${VERSION}/g" "${SRC_PATH}/packaging/linux/openra.desktop.in" > "${SRC_PATH}/packaging/linux/openra-${MOD_ID}.desktop"
			install -m644 "${SRC_PATH}/packaging/linux/openra-${MOD_ID}.desktop" "${BUILD_PATH}${SHARE_PATH}/applications"
			rm "${SRC_PATH}/packaging/linux/openra-${MOD_ID}.desktop"

			# icons
			for SIZE in 16x16 32x32 48x48 64x64 128x128; do
				install -d "${BUILD_PATH}${SHARE_PATH}/icons/hicolor/${SIZE}/apps"
				install -m644 "${SRC_PATH}/packaging/artwork/${MOD_ID}_${SIZE}.png" "${BUILD_PATH}${SHARE_PATH}/icons/hicolor/${SIZE}/apps/openra-${MOD_ID}.png"
			done

			if [ "${MOD_ID}" = "ra" ] || [ "${MOD_ID}" = "cnc" ]; then
				install -d "${BUILD_PATH}${SHARE_PATH}/icons/hicolor/scalable/apps"
				install -m644 "${SRC_PATH}/packaging/artwork/${MOD_ID}_scalable.svg" "${BUILD_PATH}${SHARE_PATH}/icons/hicolor/scalable/apps/openra-${MOD_ID}.svg"
			fi

			# MIME info
			install -d "${BUILD_PATH}${SHARE_PATH}/mime/packages"
			sed -e "s/{MODID}/${MOD_ID}/g" -e "s/{TAG}/${VERSION}/g" "${SRC_PATH}/packaging/linux/openra-mimeinfo.xml.in" > "${SRC_PATH}/packaging/linux/openra-${MOD_ID}.xml"
			install -m644 "${SRC_PATH}/packaging/linux/openra-${MOD_ID}.xml" "${BUILD_PATH}${SHARE_PATH}/mime/packages/openra-${MOD_ID}.xml"
			rm "${SRC_PATH}/packaging/linux/openra-${MOD_ID}.xml"
		fi

		shift
	done
)

function install_linux_appdata() (
	# Copy AppStream metadata to the target directory
	# Arguments:
	#   SRC_PATH: Path to the root OpenRA directory
	#   BUILD_PATH: Path to packaging filesystem root (e.g. /tmp/openra-build/ or "" for a local install)
	#   SHARE_PATH: Parent path to the appdata directory (e.g. /usr/local/share)
	#   MOD [MOD...]: One or more mod ids to copy (cnc, d2k, ra)
	# Used by:
	#   Makefile (install-linux-appdata target for local installs and downstream packaging)
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

		sed -e "s/{MODID}/${MOD_ID}/g" -e "s/{MOD_NAME}/${MOD_NAME}/g" -e "s/{SCREENSHOT_RA}/${SCREENSHOT_RA}/g" -e "s/{SCREENSHOT_CNC}/${SCREENSHOT_CNC}/g" -e "s/{SCREENSHOT_D2K}/${SCREENSHOT_D2K}/g" "${SRC_PATH}/packaging/linux/openra.metainfo.xml.in" > "${SRC_PATH}/packaging/linux/openra-${MOD_ID}.metainfo.xml"
		install -m644 "${SRC_PATH}/packaging/linux/openra-${MOD_ID}.metainfo.xml" "${BUILD_PATH}${SHARE_PATH}/metainfo"
		rm "${SRC_PATH}/packaging/linux/openra-${MOD_ID}.metainfo.xml"

		shift
	done
)

function windows_deps() {
	command -v curl >/dev/null 2>&1 || command -v wget > /dev/null 2>&1 || { echo >&2 "Windows packaging requires curl or wget."; exit 1; }
	command -v makensis >/dev/null 2>&1 || { echo >&2 "Windows packaging requires makensis."; exit 1; }
	command -v convert >/dev/null 2>&1 || { echo >&2 "Windows packaging requires ImageMagick."; exit 1; }
	command -v python3 >/dev/null 2>&1 || { echo >&2 "Windows packaging requires python 3."; exit 1; }
	command -v wine64 >/dev/null 2>&1 || { echo >&2 "Windows packaging requires wine64."; exit 1; }

	# if command -v curl >/dev/null 2>&1; then
	# 	curl -s -L -O https://github.com/electron/rcedit/releases/download/v1.1.1/rcedit-x64.exe
	# else
	# 	wget -cq https://github.com/electron/rcedit/releases/download/v1.1.1/rcedit-x64.exe
	# fi
}

function makelauncher()
{
	LAUNCHER_NAME="${1}"
	DISPLAY_NAME="${2}"
	MOD_ID="${3}"
	PLATFORM="${4}"

	TAG_TYPE="${TAG%%-*}"
	TAG_VERSION="${TAG#*-}"
	BACKWARDS_TAG="${TAG_VERSION}-${TAG_TYPE}"

	convert "${ARTWORK_DIR}/${MOD_ID}_16x16.png" "${ARTWORK_DIR}/${MOD_ID}_24x24.png" "${ARTWORK_DIR}/${MOD_ID}_32x32.png" "${ARTWORK_DIR}/${MOD_ID}_48x48.png" "${ARTWORK_DIR}/${MOD_ID}_256x256.png" "${BUILTDIR}/${MOD_ID}.ico"
	install_windows_launcher "${SRCDIR}" "${BUILTDIR}" "win-${PLATFORM}" "${MOD_ID}" "${LAUNCHER_NAME}" "${DISPLAY_NAME}" "${FAQ_URL}" "${TAG}"

	# Use rcedit to patch the generated EXE with missing assembly/PortableExecutable information because .NET 6 ignores that when building on Linux.
	# Using a backwards version tag because rcedit is unable to set versions starting with a letter.

	echo "not running wine64..."

	# wine64 $HOME/rcedit-x64.exe "${BUILTDIR}/${LAUNCHER_NAME}.exe" --set-product-version "${BACKWARDS_TAG}"
	# wine64 $HOME/rcedit-x64.exe "${BUILTDIR}/${LAUNCHER_NAME}.exe" --set-version-string "ProductName" "OpenRA"
	# wine64 $HOME/rcedit-x64.exe "${BUILTDIR}/${LAUNCHER_NAME}.exe" --set-version-string "CompanyName" "The OpenRA team"
	# wine64 $HOME/rcedit-x64.exe "${BUILTDIR}/${LAUNCHER_NAME}.exe" --set-version-string "FileDescription" "${LAUNCHER_NAME} mod for OpenRA"
	# wine64 $HOME/rcedit-x64.exe "${BUILTDIR}/${LAUNCHER_NAME}.exe" --set-version-string "LegalCopyright" "Copyright (c) The OpenRA Developers and Contributors"
	# wine64 $HOME/rcedit-x64.exe "${BUILTDIR}/${LAUNCHER_NAME}.exe" --set-icon "${BUILTDIR}/${MOD_ID}.ico"
}

function build_windows()
{
	PLATFORM="${1}"

	echo "Building core files (${PLATFORM})"
	USE_PROGRAMFILES32=$([ "${PLATFORM}" == "x86" ] && echo "-DUSE_PROGRAMFILES32=true" || echo "")

	install_assemblies "${SRCDIR}" "${BUILTDIR}" "win-${PLATFORM}" "net6" "False" "True" "True"
	install_data "${SRCDIR}" "${BUILTDIR}" "cnc" "d2k" "ra"
	set_engine_version "${TAG}" "${BUILTDIR}"
	set_mod_version "${TAG}" "${BUILTDIR}/mods/cnc/mod.yaml" "${BUILTDIR}/mods/d2k/mod.yaml" "${BUILTDIR}/mods/ra/mod.yaml"  "${BUILTDIR}/mods/modcontent/mod.yaml"

	echo "Compiling Windows launchers (${PLATFORM})"
	makelauncher "RedAlert" "Red Alert" "ra" "${PLATFORM}"
	makelauncher "TiberianDawn" "Tiberian Dawn" "cnc" "${PLATFORM}"
	makelauncher "Dune2000" "Dune 2000" "d2k" "${PLATFORM}"

	echo "Not building Windows setup.exe ($1)"
	mkdir -p "${OUTPUTDIR}"
	# makensis -V2 -DSRCDIR="${BUILTDIR}" -DTAG="${TAG}" -DSUFFIX="${SUFFIX}" -DOUTFILE="${OUTPUTDIR}/OpenRA-${TAG}-${PLATFORM}.exe" ${USE_PROGRAMFILES32} OpenRA.nsi

	echo "Packaging zip archive ($1)"
	(
		cd "${BUILTDIR}"
		zip "OpenRA-${TAG}-${PLATFORM}-winportable.zip" -r -9 ./* --quiet
		mkdir -p "${OUTPUTDIR}"
		mv "OpenRA-${TAG}-${PLATFORM}-winportable.zip" "${OUTPUTDIR}"
	)
	rm -rf "${BUILTDIR}"
}

function modify_plist() {
	sed "s|${1}|${2}|g" "${3}" > "${3}.tmp" && mv "${3}.tmp" "${3}"
}

function build_app() {
	# Copies the game files and sets metadata
	TEMPLATE_DIR="${1}"
	LAUNCHER_DIR="${2}"
	MOD_ID="${3}"
	MOD_NAME="${4}"
	DISCORD_APPID="${5}"

	LAUNCHER_CONTENTS_DIR="${LAUNCHER_DIR}/Contents"
	LAUNCHER_RESOURCES_DIR="${LAUNCHER_CONTENTS_DIR}/Resources"

	cp -r "${TEMPLATE_DIR}" "${LAUNCHER_DIR}"

	IS_D2K="False"
	if [ "${MOD_ID}" = "d2k" ]; then
		IS_D2K="True"
	fi

	# Install engine and mod files
	install_assemblies "${SRCDIR}" "${LAUNCHER_CONTENTS_DIR}/MacOS/x86_64" "osx-x64" "net6" "True" "True" "${IS_D2K}"
	install_assemblies "${SRCDIR}" "${LAUNCHER_CONTENTS_DIR}/MacOS/arm64" "osx-arm64" "net6" "True" "True" "${IS_D2K}"
	install_assemblies "${SRCDIR}" "${LAUNCHER_CONTENTS_DIR}/MacOS/mono" "osx-x64" "mono" "True" "True" "${IS_D2K}"

	install_data "${SRCDIR}" "${LAUNCHER_RESOURCES_DIR}" "${MOD_ID}"
	set_engine_version "${TAG}" "${LAUNCHER_RESOURCES_DIR}"
	set_mod_version "${TAG}" "${LAUNCHER_RESOURCES_DIR}/mods/${MOD_ID}/mod.yaml" "${LAUNCHER_RESOURCES_DIR}/mods/modcontent/mod.yaml"

	# Assemble multi-resolution icon
	mkdir "${MOD_ID}.iconset"
	cp "${ARTWORK_DIR}/${MOD_ID}_16x16.png" "${MOD_ID}.iconset/icon_16x16.png"
	cp "${ARTWORK_DIR}/${MOD_ID}_32x32.png" "${MOD_ID}.iconset/icon_16x16@2.png"
	cp "${ARTWORK_DIR}/${MOD_ID}_32x32.png" "${MOD_ID}.iconset/icon_32x32.png"
	cp "${ARTWORK_DIR}/${MOD_ID}_64x64.png" "${MOD_ID}.iconset/icon_32x32@2x.png"
	cp "${ARTWORK_DIR}/${MOD_ID}_128x128.png" "${MOD_ID}.iconset/icon_128x128.png"
	cp "${ARTWORK_DIR}/${MOD_ID}_256x256.png" "${MOD_ID}.iconset/icon_128x128@2x.png"
	cp "${ARTWORK_DIR}/${MOD_ID}_256x256.png" "${MOD_ID}.iconset/icon_256x256.png"
	cp "${ARTWORK_DIR}/${MOD_ID}_512x512.png" "${MOD_ID}.iconset/icon_256x256@2x.png"
	cp "${ARTWORK_DIR}/${MOD_ID}_1024x1024.png" "${MOD_ID}.iconset/icon_512x512@2x.png"
	iconutil --convert icns "${MOD_ID}.iconset" -o "${LAUNCHER_RESOURCES_DIR}/${MOD_ID}.icns"
	rm -rf "${MOD_ID}.iconset"

	# Set launcher metadata
	modify_plist "{MOD_ID}" "${MOD_ID}" "${LAUNCHER_CONTENTS_DIR}/Info.plist"
	modify_plist "{MOD_NAME}" "${MOD_NAME}" "${LAUNCHER_CONTENTS_DIR}/Info.plist"
	modify_plist "{JOIN_SERVER_URL_SCHEME}" "openra-${MOD_ID}-${TAG}" "${LAUNCHER_CONTENTS_DIR}/Info.plist"
	modify_plist "{DISCORD_URL_SCHEME}" "discord-${DISCORD_APPID}" "${LAUNCHER_CONTENTS_DIR}/Info.plist"

	# Sign binaries with developer certificate
	if [ -n "${MACOS_DEVELOPER_IDENTITY}" ]; then
		codesign --sign "${MACOS_DEVELOPER_IDENTITY}" --timestamp --options runtime -f --entitlements entitlements.plist --deep "${LAUNCHER_DIR}"
	fi
}

function macos_deps() {
	if [[ "${OSTYPE}" != "darwin"* ]]; then
		echo >&2 "macOS packaging requires a macOS host"
		exit 1
	fi

	command -v clang >/dev/null 2>&1 || { echo >&2 "macOS packaging requires clang."; exit 1; }
}

function import_certificates() {
	# Import code signing certificate
	if [ -n "${MACOS_DEVELOPER_CERTIFICATE_BASE64}" ] && [ -n "${MACOS_DEVELOPER_CERTIFICATE_PASSWORD}" ] && [ -n "${MACOS_DEVELOPER_IDENTITY}" ]; then
		echo "Importing signing certificate"
		echo "${MACOS_DEVELOPER_CERTIFICATE_BASE64}" | base64 --decode > build.p12
		security create-keychain -p build build.keychain
		security default-keychain -s build.keychain
		security unlock-keychain -p build build.keychain
		security import build.p12 -k build.keychain -P "${MACOS_DEVELOPER_CERTIFICATE_PASSWORD}" -T /usr/bin/codesign >/dev/null 2>&1
		security set-key-partition-list -S apple-tool:,apple: -s -k build build.keychain >/dev/null 2>&1
		rm -fr build.p12
	fi
}

function linux_deps() {
	command -v tar >/dev/null 2>&1 || { echo >&2 "Linux packaging requires tar."; exit 1; }
	command -v curl >/dev/null 2>&1 || command -v wget > /dev/null 2>&1 || { echo >&2 "Linux packaging requires curl or wget."; exit 1; }
	command -v appimagetool-x86_64.AppImage >/dev/null 2>&1 || { echo >&2 "Linux packaging requires appimagetool-x86_64.AppImage."; exit 1; }
}

function build_appimage() {
	MOD_ID=${1}
	DISPLAY_NAME=${2}
	DISCORD_ID=${3}
	APPDIR="$(pwd)/${MOD_ID}.appdir"
	APPIMAGE="OpenRA-$(echo "${DISPLAY_NAME}" | sed 's/ /-/g')${SUFFIX}-x86_64.AppImage"

	IS_D2K="False"
	if [ "${MOD_ID}" = "d2k" ]; then
		IS_D2K="True"
	fi

	install_assemblies "${SRCDIR}" "${APPDIR}/usr/lib/openra" "linux-x64" "net6" "True" "True" "${IS_D2K}"
	install_data "${SRCDIR}" "${APPDIR}/usr/lib/openra" "${MOD_ID}"
	set_engine_version "${TAG}" "${APPDIR}/usr/lib/openra"
	set_mod_version "${TAG}" "${APPDIR}/usr/lib/openra/mods/${MOD_ID}/mod.yaml" "${APPDIR}/usr/lib/openra/mods/modcontent/mod.yaml"

	# Add launcher and icons
	sed "s/{MODID}/${MOD_ID}/g" AppRun.in | sed "s/{MODNAME}/${DISPLAY_NAME}/g" > "${APPDIR}/AppRun"
	chmod 0755 "${APPDIR}/AppRun"

	mkdir -p "${APPDIR}/usr/share/applications"
	# Note that the non-discord version of the desktop file is used by the Mod SDK and must be maintained in parallel with the discord version!
	sed "s/{MODID}/${MOD_ID}/g" openra.desktop.discord.in | sed "s/{MODNAME}/${DISPLAY_NAME}/g" | sed "s/{TAG}/${TAG}/g" | sed "s/{DISCORDAPPID}/${DISCORD_ID}/g" > "${APPDIR}/usr/share/applications/openra-${MOD_ID}.desktop"
	chmod 0755 "${APPDIR}/usr/share/applications/openra-${MOD_ID}.desktop"
	cp "${APPDIR}/usr/share/applications/openra-${MOD_ID}.desktop" "${APPDIR}/openra-${MOD_ID}.desktop"

	mkdir -p "${APPDIR}/usr/share/mime/packages"
	# Note that the non-discord version of the mimeinfo file is used by the Mod SDK and must be maintained in parallel with the discord version!
	sed "s/{MODID}/${MOD_ID}/g" openra-mimeinfo.xml.discord.in | sed "s/{TAG}/${TAG}/g" | sed "s/{DISCORDAPPID}/${DISCORD_ID}/g" > "${APPDIR}/usr/share/mime/packages/openra-${MOD_ID}.xml"
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
	sed "s/{MODID}/${MOD_ID}/g" openra.appimage.in | sed "s/{TAG}/${TAG}/g" | sed "s/{MODNAME}/${DISPLAY_NAME}/g" > "${APPDIR}/usr/bin/openra-${MOD_ID}"
	chmod 0755 "${APPDIR}/usr/bin/openra-${MOD_ID}"

	sed "s/{MODID}/${MOD_ID}/g" openra-server.appimage.in > "${APPDIR}/usr/bin/openra-${MOD_ID}-server"
	chmod 0755 "${APPDIR}/usr/bin/openra-${MOD_ID}-server"

	sed "s/{MODID}/${MOD_ID}/g" openra-utility.appimage.in > "${APPDIR}/usr/bin/openra-${MOD_ID}-utility"
	chmod 0755 "${APPDIR}/usr/bin/openra-${MOD_ID}-utility"

	install -m 0755 gtk-dialog.py "${APPDIR}/usr/bin/gtk-dialog.py"

	mkdir -p "${OUTPUTDIR}"
	# Embed update metadata if (and only if) compiled on GitHub Actions
	if [ -n "${GITHUB_REPOSITORY}" ]; then
		ARCH=x86_64 ./appimagetool-x86_64.AppImage --no-appstream -u "zsync|https://master.openra.net/appimagecheck.zsync?mod=${MOD_ID}&channel=${UPDATE_CHANNEL}" "${APPDIR}" "${OUTPUTDIR}/${APPIMAGE}"
		zsyncmake -u "https://github.com/${GITHUB_REPOSITORY}/releases/download/${TAG}/${APPIMAGE}" -o "${OUTPUTDIR}/${APPIMAGE}.zsync" "${OUTPUTDIR}/${APPIMAGE}"
	else
		ARCH=x86_64 ./appimagetool-x86_64.AppImage --no-appstream "${APPDIR}" "${OUTPUTDIR}/${APPIMAGE}"
	fi

	rm -rf "${APPDIR}"
}

function build_macos() {
	echo "Building launchers"

	# Prepare generic template for the mods to duplicate and customize
	TEMPLATE_DIR="${BUILTDIR}/template.app"
	mkdir -p "${TEMPLATE_DIR}/Contents/Resources"
	mkdir -p "${TEMPLATE_DIR}/Contents/MacOS/mono"
	mkdir -p "${TEMPLATE_DIR}/Contents/MacOS/x86_64"
	mkdir -p "${TEMPLATE_DIR}/Contents/MacOS/arm64"

	echo "APPL????" > "${TEMPLATE_DIR}/Contents/PkgInfo"
	cp Info.plist.in "${TEMPLATE_DIR}/Contents/Info.plist"
	modify_plist "{DEV_VERSION}" "${TAG}" "${TEMPLATE_DIR}/Contents/Info.plist"
	modify_plist "{FAQ_URL}" "http://wiki.openra.net/FAQ" "${TEMPLATE_DIR}/Contents/Info.plist"
	modify_plist "{MINIMUM_SYSTEM_VERSION}" "10.11" "${TEMPLATE_DIR}/Contents/Info.plist"

	# Compile universal (x86_64 + arm64) arch-specific apphosts
	clang apphost.c -o "${TEMPLATE_DIR}/Contents/MacOS/apphost-x86_64" -framework AppKit -target x86_64-apple-macos10.15
	clang apphost.c -o "${TEMPLATE_DIR}/Contents/MacOS/apphost-arm64" -framework AppKit -target arm64-apple-macos10.15
	clang apphost-mono.c -o "${TEMPLATE_DIR}/Contents/MacOS/apphost-mono" -framework AppKit -target x86_64-apple-macos10.11
	clang checkmono.c -o "${TEMPLATE_DIR}/Contents/MacOS/checkmono" -framework AppKit -target x86_64-apple-macos10.11

	# Compile universal (x86_64 + arm64) Launcher
	clang launcher.m -o "${TEMPLATE_DIR}/Contents/MacOS/Launcher-x86_64" -framework AppKit -target x86_64-apple-macos10.11
	clang launcher.m -o "${TEMPLATE_DIR}/Contents/MacOS/Launcher-arm64" -framework AppKit -target arm64-apple-macos10.15
	lipo -create -output "${TEMPLATE_DIR}/Contents/MacOS/Launcher" "${TEMPLATE_DIR}/Contents/MacOS/Launcher-x86_64" "${TEMPLATE_DIR}/Contents/MacOS/Launcher-arm64"
	rm "${TEMPLATE_DIR}/Contents/MacOS/Launcher-x86_64" "${TEMPLATE_DIR}/Contents/MacOS/Launcher-arm64"

	# Compile universal (x86_64 + arm64) Utility
	clang utility.m -o "${TEMPLATE_DIR}/Contents/MacOS/Utility-x86_64" -framework AppKit -target x86_64-apple-macos10.11
	clang utility.m -o "${TEMPLATE_DIR}/Contents/MacOS/Utility-arm64" -framework AppKit -target arm64-apple-macos10.15
	lipo -create -output "${TEMPLATE_DIR}/Contents/MacOS/Utility" "${TEMPLATE_DIR}/Contents/MacOS/Utility-x86_64" "${TEMPLATE_DIR}/Contents/MacOS/Utility-arm64"
	rm "${TEMPLATE_DIR}/Contents/MacOS/Utility-x86_64" "${TEMPLATE_DIR}/Contents/MacOS/Utility-arm64"

	build_app "${TEMPLATE_DIR}" "${BUILTDIR}/OpenRA - Red Alert.app" "ra" "Red Alert" "699222659766026240"
	build_app "${TEMPLATE_DIR}" "${BUILTDIR}/OpenRA - Tiberian Dawn.app" "cnc" "Tiberian Dawn" "699223250181292033"
	build_app "${TEMPLATE_DIR}" "${BUILTDIR}/OpenRA - Dune 2000.app" "d2k" "Dune 2000" "712711732770111550"

	rm -rf "${TEMPLATE_DIR}"
}

function build_macos_images() {
	echo "Packaging disk image"
	hdiutil create "build.dmg" -format UDRW -volname "OpenRA" -fs HFS+ -srcfolder build
	DMG_DEVICE=$(hdiutil attach -readwrite -noverify -noautoopen "build.dmg" | egrep '^/dev/' | sed 1q | awk '{print $1}')
	sleep 2

	# Background image is created from source svg in artsrc repository
	mkdir "/Volumes/OpenRA/.background/"
	tiffutil -cathidpicheck "${ARTWORK_DIR}/macos-background.png" "${ARTWORK_DIR}/macos-background-2x.png" -out "/Volumes/OpenRA/.background/background.tiff"

	cp "${BUILTDIR}/OpenRA - Red Alert.app/Contents/Resources/ra.icns" "/Volumes/OpenRA/.VolumeIcon.icns"

	echo '
		tell application "Finder"
			tell disk "'OpenRA'"
						open
						set current view of container window to icon view
						set toolbar visible of container window to false
						set statusbar visible of container window to false
						set the bounds of container window to {400, 100, 1040, 580}
						set theViewOptions to the icon view options of container window
						set arrangement of theViewOptions to not arranged
						set icon size of theViewOptions to 72
						set background picture of theViewOptions to file ".background:background.tiff"
						make new alias file at container window to POSIX file "/Applications" with properties {name:"Applications"}
						set position of item "'OpenRA - Tiberian Dawn.app'" of container window to {160, 106}
						set position of item "'OpenRA - Red Alert.app'" of container window to {320, 106}
						set position of item "'OpenRA - Dune 2000.app'" of container window to {480, 106}
						set position of item "Applications" of container window to {320, 298}
						set position of item ".background" of container window to {160, 298}
						set position of item ".fseventsd" of container window to {160, 298}
						set position of item ".VolumeIcon.icns" of container window to {160, 298}
						update without registering applications
						delay 5
						close
			end tell
		end tell
	' | osascript

	# HACK: Copy the volume icon again - something in the previous step seems to delete it...?
	cp "${BUILTDIR}/OpenRA - Red Alert.app/Contents/Resources/ra.icns" "/Volumes/OpenRA/.VolumeIcon.icns"
	SetFile -c icnC "/Volumes/OpenRA/.VolumeIcon.icns"
	SetFile -a C "/Volumes/OpenRA"

	# Replace duplicate .NET runtime files with hard links to improve compression
	for MOD in "Red Alert" "Tiberian Dawn"; do
		for p in "x86_64" "arm64" "mono"; do
			for f in "/Volumes/OpenRA/OpenRA - ${MOD}.app/Contents/MacOS/${p}"/*; do
				g="/Volumes/OpenRA/OpenRA - Dune 2000.app/Contents/MacOS/${p}/"$(basename "${f}")
				hashf=$(shasum "${f}" | awk '{ print $1 }') || :
				hashg=$(shasum "${g}" | awk '{ print $1 }') || :
				if [ -n "${hashf}" ] && [ "${hashf}" = "${hashg}" ]; then
					echo "Deduplicating ${f}"
					rm "${f}"
					ln "${g}" "${f}"
				fi
			done
		done
	done

	for MOD in "Red Alert" "Tiberian Dawn" "Dune 2000"; do
		for p in "arm64" "mono"; do
			for f in "/Volumes/OpenRA/OpenRA - ${MOD}.app/Contents/MacOS/x86_64"/*; do
				g="/Volumes/OpenRA/OpenRA - ${MOD}.app/Contents/MacOS/${p}/"$(basename "${f}")
				if [ -e "${g}" ]; then
					hashf=$(shasum "${f}" | awk '{ print $1 }') || :
					hashg=$(shasum "${g}" | awk '{ print $1 }') || :
					if [ -n "${hashf}" ] && [ "${hashf}" = "${hashg}" ]; then
						echo "Deduplicating ${f}"
						rm "${f}"
						ln "${g}" "${f}"
					fi
				fi
			done
		done
	done

	chmod -Rf go-w /Volumes/OpenRA
	sync
	sync

	hdiutil detach "${DMG_DEVICE}"
	rm -rf "${BUILTDIR}"
}

function sign_macos_images() {
	# The application bundles will be signed if the following environment variables are defined:
	#   MACOS_DEVELOPER_IDENTITY: The alphanumeric identifier listed in the certificate name ("Developer ID Application: <your name> (<identity>)")
	#                             or as Team ID in your Apple Developer account Membership Details.
	# If the identity is not already in the default keychain, specify the following environment variables to import it:
	#   MACOS_DEVELOPER_CERTIFICATE_BASE64: base64 content of the exported .p12 developer ID certificate.
	#                                       Generate using `base64 certificate.p12 | pbcopy`
	#   MACOS_DEVELOPER_CERTIFICATE_PASSWORD: password to unlock the MACOS_DEVELOPER_CERTIFICATE_BASE64 certificate
	#
	# The applicaton bundles will be notarized if the following environment variables are defined:
	#   MACOS_DEVELOPER_USERNAME: Email address for the developer account
	#   MACOS_DEVELOPER_PASSWORD: App-specific password for the developer account

	if [ -n "${MACOS_DEVELOPER_CERTIFICATE_BASE64}" ] && [ -n "${MACOS_DEVELOPER_CERTIFICATE_PASSWORD}" ] && [ -n "${MACOS_DEVELOPER_IDENTITY}" ]; then
		security delete-keychain build.keychain
	fi

	if [ -n "${MACOS_DEVELOPER_USERNAME}" ] && [ -n "${MACOS_DEVELOPER_PASSWORD}" ] && [ -n "${MACOS_DEVELOPER_IDENTITY}" ]; then
		echo "Submitting build for notarization"

		# Reset xcode search path to fix xcrun not finding altool
		sudo xcode-select -r

		# Create a temporary read-only dmg for submission (notarization service rejects read/write images)
		hdiutil convert "build.dmg" -format ULFO -ov -o "build-notarization.dmg"

		xcrun notarytool submit "build-notarization.dmg" --wait --apple-id "${MACOS_DEVELOPER_USERNAME}" --password "${MACOS_DEVELOPER_PASSWORD}" --team-id "${MACOS_DEVELOPER_IDENTITY}"

		rm "build-notarization.dmg"

		echo "Stapling tickets"
		DMG_DEVICE=$(hdiutil attach -readwrite -noverify -noautoopen "build.dmg" | egrep '^/dev/' | sed 1q | awk '{print $1}')
		sleep 2

		xcrun stapler staple "/Volumes/OpenRA/OpenRA - Red Alert.app"
		xcrun stapler staple "/Volumes/OpenRA/OpenRA - Tiberian Dawn.app"
		xcrun stapler staple "/Volumes/OpenRA/OpenRA - Dune 2000.app"

		sync
		sync

		hdiutil detach "${DMG_DEVICE}"
	fi
}

function convert_macos_images() {
	mkdir -p "${OUTPUTDIR}"
	hdiutil convert "build.dmg" -format ULFO -ov -o "${OUTPUTDIR}/OpenRA-${TAG}.dmg"
	rm "build.dmg"
}
