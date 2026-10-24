#!/usr/bin/env bash

set -euo pipefail

if [ -n "${BASH_SOURCE:-}" ]; then
  SCRIPT_PATH="${BASH_SOURCE[0]}"
else
  SCRIPT_PATH="$0"
fi

SCRIPT_DIR="$(cd "$(dirname "${SCRIPT_PATH}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
SFAIT_ROOT="$(cd "${PROJECT_DIR}/.." && pwd)"
SFAIT_BUILD_TOOLS="${SFAIT_ROOT}/SFAIT-build-tools"
SFAIT_DEV_TOOLS="${SFAIT_BUILD_TOOLS}/SFAIT-dev-tools"

export SFAIT_ROOT
export SFAIT_BUILD_TOOLS
export SFAIT_DEV_TOOLS
export SFAIT_PROJECT_DIR="${PROJECT_DIR}"

export VCPKG_ROOT="${SFAIT_DEV_TOOLS}/vcpkg"
export VCPKG_INSTALLED_ROOT="${VCPKG_ROOT}/installed"
export CARGO_TARGET_DIR="${SFAIT_BUILD_TOOLS}/SFAIT-build-target"

export FLUTTER_ROOT="${SFAIT_DEV_TOOLS}/flutter-3.24.5-arm64/flutter"
export NASM_ROOT="${SFAIT_DEV_TOOLS}/nasm-2.16.03/nasm-2.16.03"

export SFAIT_EXPORT_DIR="${PROJECT_DIR}/builds"

if [ -d "/Applications/Xcode.app/Contents/Developer" ]; then
  export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
fi

export PATH="${HOME}/.gem/ruby/2.6.0/bin:${FLUTTER_ROOT}/bin:${NASM_ROOT}:${VCPKG_ROOT}:${SFAIT_DEV_TOOLS}/bin:${HOME}/.cargo/bin:${PATH}"

for required_path in \
  "${FLUTTER_ROOT}/bin/flutter" \
  "${VCPKG_ROOT}/vcpkg" \
  "${NASM_ROOT}/nasm" \
  "${HOME}/.gem/ruby/2.6.0/bin/pod" \
  "${CARGO_TARGET_DIR}"
do
  if [ ! -e "${required_path}" ]; then
    echo "Missing build dependency: ${required_path}" >&2
    return 1 2>/dev/null || exit 1
  fi
done
