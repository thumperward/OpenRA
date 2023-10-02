#! /bin/bash
set -euo pipefail

if [ $# -ne "2" ]; then
	echo "Usage: $(basename "$0") tag outputdir"
	exit 1
fi

cd $(dirname "$0")
. ../functions.sh

TAG="$1"
OUTPUTDIR="$2"
SRCDIR="$(pwd)/../.."

ARTWORK_DIR="$(pwd)/../artwork/"
if [[ ${TAG} == release* ]]; then	UPDATE_CHANNEL="release"; SUFFIX=""
elif [[ ${TAG} == playtest* ]]; then UPDATE_CHANNEL="playtest"; SUFFIX="-playtest"
elif [[ ${TAG} == pkgtest* ]]; then	UPDATE_CHANNEL="pkgtest"; SUFFIX="-pkgtest"
else
	UPDATE_CHANNEL=""; SUFFIX="-devel"
fi

linux_deps

build_appimage "ra" "Red Alert" "699222659766026240"
build_appimage "cnc" "Tiberian Dawn" "699223250181292033"
build_appimage "d2k" "Dune 2000" "712711732770111550"
