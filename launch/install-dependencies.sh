#! /bin/bash
set -euo pipefail

curl -SOL https://packages.microsoft.com/config/debian/11/packages-microsoft-prod.deb &&
  sudo dpkg -i packages-microsoft-prod.deb &&
  rm packages-microsoft-prod.deb &&
  sudo apt-get update &&
  sudo apt-get install -y --no-install-recommends \
    dotnet-sdk-6.0 \
    make
