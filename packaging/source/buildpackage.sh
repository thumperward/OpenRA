#! /bin/bash
set -euo pipefail

cd "$(dirname "$0")"

TAG="${1:-$(git tag | tail -1)}"    # Tag to release
OUTPUTDIR="${SRCDIR}/build/windows" # Path to the final asset destination
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
