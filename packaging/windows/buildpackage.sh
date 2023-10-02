#! /bin/bash
set -euo pipefail

function build() {
	echo "Building binaries (${ARCH})..."

	echo "${TAG}" >"${BUILTDIR}/VERSION"
	# Set parameter 5 to False to disable generation of OpenRA.exe
	../install-assemblies.sh "${SRCDIR}" "${BUILTDIR}" "win-${ARCH}" "net6" "True" "True" "True"
}

function configure_mods() {
	echo "Configuring mods (${ARCH})..."

	../install-data.sh "${SRCDIR}" "${BUILTDIR}" "cnc" "d2k" "ra"
	../set-mod-version.sh "${TAG}" \
		"${BUILTDIR}/mods/cnc/mod.yaml" \
		"${BUILTDIR}/mods/d2k/mod.yaml" \
		"${BUILTDIR}/mods/ra/mod.yaml" \
		"${BUILTDIR}/mods/modcontent/mod.yaml"
}

function build_launcher() {
	# Compile and publish a windows launcher with the specified mod details to
	# the target directory.
	# Arguments:
	#   MOD_ID:
	#   LAUNCHER_NAME:
	#   FAQ_URL:
	# Used by:
	#   Windows packaging
	#   Mod SDK Windows packaging
	LAUNCHER_NAME="${1}" # Filename (without the .exe extension) for the launcher
	MOD_ID="${2}"        # Mod id to launch (e.g. "ra")
	# URL to load when the "View FAQ" button is pressed in the crash dialog
	FAQ_URL="https://wiki.openra.net/FAQ"
	TAG_TYPE="${TAG%%-*}"
	TAG_VERSION="${TAG#*-}"
	BACKWARDS_TAG="${TAG_VERSION}-${TAG_TYPE}"
	ARTWORK_DIR="$(pwd)/../artwork/"

	echo "Building launcher for ${LAUNCHER_NAME} (${ARCH})..."

	convert \
		"${ARTWORK_DIR}/${MOD_ID}_16x16.png" \
		"${ARTWORK_DIR}/${MOD_ID}_24x24.png" \
		"${ARTWORK_DIR}/${MOD_ID}_32x32.png" \
		"${ARTWORK_DIR}/${MOD_ID}_48x48.png" \
		"${ARTWORK_DIR}/${MOD_ID}_256x256.png" \
		"${BUILTDIR}/${MOD_ID}.ico"

	rm -rf "${SRCDIR}/src/OpenRA.WindowsLauncher/obj" || :

	# See https://learn.microsoft.com/en-us/dotnet/core/tools/dotnet-publish for
	# details. Unfortunately there doesn't seem to be a way to set
	# FileDescription and it uses the value of -p:LauncherName.
	# -p:Product sets the "Product name" field.
	# -p:InformationalVersion seems to set the "Product version" field.
	# -p:DisplayName doesn't seem to have a visible effect?
	dotnet publish \
		"${SRCDIR}/src/OpenRA.WindowsLauncher/OpenRA.WindowsLauncher.csproj" \
		-c Release -r "win-${ARCH}" \
		-p:LauncherName="${LAUNCHER_NAME}",TargetPlatform="${ARCH}",ModID="${MOD_ID}",PublishDir="${BUILTDIR}",FaqUrl="${FAQ_URL}",InformationalVersion="${TAG}" \
		--self-contained true

	# NET 6 is unable to customize the application host for windows when
	# compiling from Linux, so we must patch the properties we need in the PE
	# header. Setting the application icon requires an external tool, so is left
	# to the calling code.
	./fixlauncher.py "${BUILTDIR}/${LAUNCHER_NAME}.exe"

	# Use rcedit to patch the generated EXE with missing assembly /
	# PortableExecutable information because .NET 6 ignores that when building on
	# Linux. Using a backwards version tag because rcedit is unable to set
	# versions starting with a letter.
	echo wine64 "$HOME/rcedit-x64.exe" "${BUILTDIR}/${LAUNCHER_NAME}.exe" --set-product-version "${BACKWARDS_TAG}"
	echo wine64 "$HOME/rcedit-x64.exe" "${BUILTDIR}/${LAUNCHER_NAME}.exe" --set-version-string "ProductName" "OpenRA"
	echo wine64 "$HOME/rcedit-x64.exe" "${BUILTDIR}/${LAUNCHER_NAME}.exe" --set-version-string "CompanyName" "The OpenRA team"
	echo wine64 "$HOME/rcedit-x64.exe" "${BUILTDIR}/${LAUNCHER_NAME}.exe" --set-version-string "FileDescription" "${LAUNCHER_NAME} mod for OpenRA"
	echo wine64 "$HOME/rcedit-x64.exe" "${BUILTDIR}/${LAUNCHER_NAME}.exe" --set-version-string "LegalCopyright" "Copyright (c) The OpenRA Developers and Contributors"
	echo wine64 "$HOME/rcedit-x64.exe" "${BUILTDIR}/${LAUNCHER_NAME}.exe" --set-icon "${BUILTDIR}/${MOD_ID}.ico"
}

function build_installer() {
	if [[ ${TAG} == "release*" ]]; then
		SUFFIX=""
	elif [[ ${TAG} == "playtest*" ]]; then
		SUFFIX=" (playtest)"
	else
		SUFFIX=" (dev)"
	fi
	pf32=$([ "${ARCH}" == "x86" ] && echo "true" || echo "false")

	echo "Building installer (${ARCH})..."

	makensis -V2 -DSRCDIR="${BUILTDIR}" -DTAG="${TAG}" -DSUFFIX="${SUFFIX}" -DOUTFILE="${OUTPUTDIR}/OpenRA-${TAG}-${ARCH}.exe" -DUSE_PROGRAMFILES32="${pf32}" OpenRA.nsi
}

function create_archive() {
	echo "Creating archive (${ARCH})..."
	(
		cd "${BUILTDIR}"
		zip "OpenRA-${TAG}-${ARCH}-winportable.zip" -r -9 ./* --quiet
		mv "OpenRA-${TAG}-${ARCH}-winportable.zip" "${OUTPUTDIR}"
	)
}

function clean() {
	echo "Cleaning up (${ARCH})..."
	rm -rf "${BUILTDIR}"
}

cd "$(dirname "$0")"

TAG="${1:-$(git tag | tail -1)}"    # Tag to release
ARCH="${2:-x64}"                    # Platform type (x86, x64)
SRCDIR="$(pwd)/../.."               # Path to the root OpenRA directory
OUTPUTDIR="${SRCDIR}/build/windows" # Path to the final asset destination
BUILTDIR="$(pwd)/build"             # Path to the temporary build directory

mkdir -p "${OUTPUTDIR}"

./dependencies.sh

build

configure_mods

build_launcher RedAlert ra
build_launcher TiberianDawn cnc
build_launcher Dune2000 d2k

build_installer

create_archive

# clean

echo "Job completed successfully."
