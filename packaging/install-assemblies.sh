#! /bin/bash
# Compile and publish the core engine and specified mod assemblies to the target directory
# Used by:
#   Makefile (install target for local installs and downstream packaging)
#   Windows packaging
#   macOS packaging
#   Linux AppImage packaging
#   Mod SDK Windows packaging
#   Mod SDK macOS packaging
#   Mod SDK Linux AppImage packaging
set -euo pipefail

SRC_PATH="${1}"              # Path to the root OpenRA directory
DEST_PATH="${2}"             # Path to the root of the install destination (will be created if necessary)
TARGETPLATFORM="${3}"        # Platform type (win-x86, win-x64, osx-x64, osx-arm64, linux-x64, linux-arm64, unix-generic)
RUNTIME="${4}"               # Runtime type (net6, mono)
COPY_GENERIC_LAUNCHER="${5}" # If set to True the OpenRA.exe will also be copied (True, False)
COPY_CNC_DLL="${6}"          # If set to True the OpenRA.Mods.Cnc.dll will also be copied (True, False)
COPY_D2K_DLL="${7}"          # If set to True the OpenRA.Mods.D2k.dll will also be copied (True, False)

ORIG_PWD=$(pwd)
cd "${SRC_PATH}"

if [ "${RUNTIME}" = "mono" ]; then
  echo "Building assemblies..."

  rm -rf "${SRC_PATH}/OpenRA."*/obj
  rm -rf "${SRC_PATH:?}/bin"

  msbuild -verbosity:m -nologo -t:Build -restore \
    -p:Configuration=Release -p:TargetPlatform="${TARGETPLATFORM}"

  if [ "${TARGETPLATFORM}" = "unix-generic" ]; then
    ./configure-system-libraries.sh
  fi

  if [ "${COPY_GENERIC_LAUNCHER}" != "True" ]; then
    rm "${SRC_PATH}/bin/OpenRA.dll"
  fi
  if [ "${COPY_CNC_DLL}" != "True" ]; then
    rm "${SRC_PATH}/bin/OpenRA.Mods.Cnc.dll"
  fi
  if [ "${COPY_D2K_DLL}" != "True" ]; then
    rm "${SRC_PATH}/bin/OpenRA.Mods.D2k.dll"
  fi

  cd "${ORIG_PWD}"
  echo "Installing engine to ${DEST_PATH}"
  install -d "${DEST_PATH}"

  for LIB in "${SRC_PATH}/bin/"*.dll "${SRC_PATH}/bin/"*.dll.config; do
    install -m644 "${LIB}" "${DEST_PATH}"
  done

  case "${TARGETPLATFORM}" in
  "linux-x64" | "linux-arm64")
    for LIB in "${SRC_PATH}/bin/"*.so; do
      install -m755 "${LIB}" "${DEST_PATH}"
    done
    ;;
  "osx-x64" | "osx-arm64")
    for LIB in "${SRC_PATH}/bin/"*.dylib; do
      install -m755 "${LIB}" "${DEST_PATH}"
    done
    ;;
  esac

else
  echo "Publishing binaries..."

  dotnet publish -c Release \
    -p:TargetPlatform="${TARGETPLATFORM}" \
    -p:CopyGenericLauncher="${COPY_GENERIC_LAUNCHER}" \
    -p:CopyCncDll="${COPY_CNC_DLL}" \
    -p:CopyD2kDll="${COPY_D2K_DLL}" \
    -r "${TARGETPLATFORM}" \
    -p:PublishDir="${DEST_PATH}" \
    --self-contained true
fi
cd "${ORIG_PWD}"
