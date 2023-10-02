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

BUILTDIR="$(pwd)/build"
ARTWORK_DIR="$(pwd)/../artwork/"
FAQ_URL="https://wiki.openra.net/FAQ"
if [[ ${TAG} == release* ]]; then	SUFFIX=""
elif [[ ${TAG} == playtest* ]]; then SUFFIX=" (playtest)"
else SUFFIX=" (dev)"
fi

windows_deps

for arch in "x86 x64"; do
	build_windows $arch
done
