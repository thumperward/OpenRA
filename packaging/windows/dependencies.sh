#! /bin/bash
set -euo pipefail

echo "Checking dependencies..."

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
