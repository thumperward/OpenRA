#! /bin/bash
set -euo pipefail

if [ $# -ne "2" ]; then
	echo "Usage: $(basename "$0") tag outputdir"
	exit 1
fi

cd "$(dirname "$0")"

TAG="$1"
OUTPUTDIR="$2"
SRCDIR="$(pwd)/../.."

(
	cd "${SRCDIR}"
	make version VERSION="${TAG}"

	mkdir -p "${OUTPUTDIR}"
	# The output from `git ls-tree` is too long to fit in a single command (overflows MAX_ARG_STRLEN)
	# so `xargs` will automatically split the input across multiple `tar` commands.
	# Use the amend flag (r) to prevent each call erasing the output from earlier calls.
	rm "${OUTPUTDIR}/OpenRA-${TAG}-source.tar" || :
	git ls-tree HEAD --name-only -r -z | xargs -0 tar vrf "${OUTPUTDIR}/OpenRA-${TAG}-source.tar"
	bzip2 "${OUTPUTDIR}/OpenRA-${TAG}-source.tar"
)
