#! /bin/bash
set -euo pipefail

function windows_deps() {
	command -v curl >/dev/null 2>&1 || command -v wget >/dev/null 2>&1 || {
		echo >&2 "Windows packaging requires curl or wget."
		exit 1
	}
	command -v makensis >/dev/null 2>&1 || {
		echo >&2 "Windows packaging requires makensis."
		exit 1
	}
	command -v convert >/dev/null 2>&1 || {
		echo >&2 "Windows packaging requires ImageMagick."
		exit 1
	}
	command -v python3 >/dev/null 2>&1 || {
		echo >&2 "Windows packaging requires python 3."
		exit 1
	}
	command -v wine64 >/dev/null 2>&1 || {
		echo >&2 "Windows packaging requires wine64."
		exit 1
	}
}

function make_windows_launcher() {
	# Compile and publish (using Mono) a windows launcher with the specified mod details to the target directory
	# Arguments:
	#   SRCDIR: Path to the root OpenRA directory
	#   BUILTDIR: Path to the root of the install destination (will be created if necessary)
	#   TARGETPLATFORM: Platform type (win-x86, win-x64)
	#   MOD_ID: Mod id to launch (e.g. "ra")
	#   LAUNCHER_NAME: Filename (without the .exe extension) for the launcher
	#   MOD_NAME: Human-readable mod name to show in the crash dialog (e.g. "Red Alert")
	#   ICON_PATH: Path to a windows .ico file
	#   FAQ_URL: URL to load when the "View FAQ" button is pressed in the crash dialog (e.g. https://wiki.openra.net/FAQ)
	# Used by:
	#   Windows packaging
	#   Mod SDK Windows packaging
	LAUNCHER_NAME="${1}"
	MOD_ID="${2}"
	PLATFORM="${3}"

	TAG_TYPE="${TAG%%-*}"
	TAG_VERSION="${TAG#*-}"
	BACKWARDS_TAG="${TAG_VERSION}-${TAG_TYPE}"

	convert "${ARTWORK_DIR}/${MOD_ID}_16x16.png" "${ARTWORK_DIR}/${MOD_ID}_24x24.png" "${ARTWORK_DIR}/${MOD_ID}_32x32.png" "${ARTWORK_DIR}/${MOD_ID}_48x48.png" "${ARTWORK_DIR}/${MOD_ID}_256x256.png" "${BUILTDIR}/${MOD_ID}.ico"

	rm -rf "${SRCDIR}/src/OpenRA.WindowsLauncher/obj" || :

	# See https://learn.microsoft.com/en-us/dotnet/core/tools/dotnet-publish for details.
	# Unfortunately there doesn't seem to be a way to set FileDescription and it uses the value of -p:LauncherName.
	# -p:Product sets the "Product name" field.
	# -p:InformationalVersion seems to set the "Product version" field.
	# -p:DisplayName doesn't seem to have a visible effect?
	dotnet publish "${SRCDIR}/src/OpenRA.WindowsLauncher/OpenRA.WindowsLauncher.csproj" -c Release -r "win-${PLATFORM}" -p:LauncherName="${LAUNCHER_NAME}",TargetPlatform="${PLATFORM}",ModID="${MOD_ID}",PublishDir="${BUILTDIR}",FaqUrl="${FAQ_URL}",InformationalVersion="${TAG}" --self-contained true

	# NET 6 is unable to customize the application host for windows when compiling from Linux,
	# so we must patch the properties we need in the PE header.
	# Setting the application icon requires an external tool, so is left to the calling code
	python3 "${SRCDIR}/packaging/windows/fixlauncher.py" "${BUILTDIR}/${LAUNCHER_NAME}.exe"

	# Use rcedit to patch the generated EXE with missing assembly/PortableExecutable information because .NET 6 ignores that when building on Linux.
	# Using a backwards version tag because rcedit is unable to set versions starting with a letter.

	echo "not running wine64..."

	echo wine64 "$HOME/rcedit-x64.exe" "${BUILTDIR}/${LAUNCHER_NAME}.exe" --set-product-version "${BACKWARDS_TAG}"
	echo wine64 "$HOME/rcedit-x64.exe" "${BUILTDIR}/${LAUNCHER_NAME}.exe" --set-version-string "ProductName" "OpenRA"
	echo wine64 "$HOME/rcedit-x64.exe" "${BUILTDIR}/${LAUNCHER_NAME}.exe" --set-version-string "CompanyName" "The OpenRA team"
	echo wine64 "$HOME/rcedit-x64.exe" "${BUILTDIR}/${LAUNCHER_NAME}.exe" --set-version-string "FileDescription" "${LAUNCHER_NAME} mod for OpenRA"
	echo wine64 "$HOME/rcedit-x64.exe" "${BUILTDIR}/${LAUNCHER_NAME}.exe" --set-version-string "LegalCopyright" "Copyright (c) The OpenRA Developers and Contributors"
	echo wine64 "$HOME/rcedit-x64.exe" "${BUILTDIR}/${LAUNCHER_NAME}.exe" --set-icon "${BUILTDIR}/${MOD_ID}.ico"
}

function build_windows() {
	PLATFORM="${1}"
	echo "Building core files (${PLATFORM})"
	../install-assemblies.sh "${SRCDIR}" "${BUILTDIR}" "win-${PLATFORM}" "net6" "False" "True" "True"
	../install-data.sh "${SRCDIR}" "${BUILTDIR}" "cnc" "d2k" "ra"
	echo "${TAG}" >"${BUILTDIR}/VERSION"
	../set-mod-version.sh "${TAG}" "${BUILTDIR}/mods/cnc/mod.yaml" "${BUILTDIR}/mods/d2k/mod.yaml" "${BUILTDIR}/mods/ra/mod.yaml" "${BUILTDIR}/mods/modcontent/mod.yaml"
}

if [ $# -ne "2" ]; then
	echo "Usage: $(basename "$0") tag outputdir"
	exit 1
fi

cd "$(dirname "$0")"

TAG="$1"
OUTPUTDIR="$2"
SRCDIR="$(pwd)/../.."

BUILTDIR="$(pwd)/build"
ARTWORK_DIR="$(pwd)/../artwork/"
FAQ_URL="https://wiki.openra.net/FAQ"
if [[ ${TAG} == release* ]]; then
	SUFFIX=""
elif [[ ${TAG} == playtest* ]]; then
	SUFFIX=" (playtest)"
else
	SUFFIX=" (dev)"
fi

echo "Checking dependencies..."
windows_deps

mkdir -p "${OUTPUTDIR}"
for arch in x86 x64; do
	echo "Building binaries (${arch})..."
	build_windows $arch

	echo "Building launchers (${arch})..."
	make_windows_launcher RedAlert ra ${arch}
	make_windows_launcher TiberianDawn cnc ${arch}
	make_windows_launcher Dune2000 d2k ${arch}

	echo "Building installer (${arch})..."
	pf32=$([ "${arch}" == "x86" ] && echo "true" || echo "false")
	makensis -V2 -DSRCDIR="${BUILTDIR}" -DTAG="${TAG}" -DSUFFIX="${SUFFIX}" -DOUTFILE="${OUTPUTDIR}/OpenRA-${TAG}-${arch}.exe" -DUSE_PROGRAMFILES32="${pf32}" OpenRA.nsi

	echo "Creating archive (${arch})..."
	(
		cd "${BUILTDIR}"
		zip "OpenRA-${TAG}-${arch}-winportable.zip" -r -9 ./* --quiet
		mv "OpenRA-${TAG}-${arch}-winportable.zip" "${OUTPUTDIR}"
	)

	echo "Cleaning up (${arch})..."
	rm -rf "${BUILTDIR}"
done

echo "Job completed successfully."
