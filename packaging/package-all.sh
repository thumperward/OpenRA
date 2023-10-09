#! /bin/bash
set -euo pipefail

cd "$(dirname "$0")"
TAG="${1:-$(git tag | tail -1)}" # Tag to release

targets=$([[ "$OSTYPE" == "darwin*" ]] && echo "macos" || echo "windows_cross linux source")
for target in $targets; do
  echo "Building ${target}..."

  "./$target/buildpackage.sh" "$TAG"
done
