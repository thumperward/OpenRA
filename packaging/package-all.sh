#! /bin/bash
set -euo pipefail

targets=$([ "$OSTYPE" == "darwin"* ] && echo "macos" || echo "windows linux source")

for target in "windows linux source"; do
  ($(dirname "$0")/$target/buildpackage.sh $1 $2)
done
