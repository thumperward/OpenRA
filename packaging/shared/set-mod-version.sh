#! /bin/bash
# Write a version string to a list of specified mod.yamls
# Arguments:
#   VERSION: OpenRA version string
#   MOD_YAML_PATH [MOD_YAML_PATH...]: One or more mod.yaml files to update
# Used by:
#   Makefile (install target for local installs and downstream packaging)
#   Linux AppImage packaging
#   macOS packaging
#   Windows packaging
#   Mod SDK Linux AppImage packaging
#   Mod SDK macOS packaging
#   Mod SDK Windows packaging
set -euo pipefail

VERSION="${1}"
shift
while [ -n "${1:-}" ]; do
  MOD_YAML_PATH="${1}"
  awk -v v="${VERSION}" '{sub("Version:.*$", "Version: " v); print $0}' "${MOD_YAML_PATH}" >"${MOD_YAML_PATH}.tmp"
  awk -v v="${VERSION}" '{sub("/[^/]*: User$", "/"v ": User"); print $0}' "${MOD_YAML_PATH}.tmp" >"${MOD_YAML_PATH}"
  rm "${MOD_YAML_PATH}.tmp"
  shift
done
