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

macos_deps

import_certificates
build_macos
build_macos_images
sign_macos_images
convert_macos_images
