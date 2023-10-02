#! /bin/bash
set -euo pipefail

targets=$([[ "$OSTYPE" == "darwin*" ]] && echo "macos" || echo "windows_cross linux source")

for target in $targets; do
  ("$(dirname "$0")/$target/buildpackage.sh" "$1" "$2")
done
