#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

source "${SCRIPT_DIR}/sfait-build-env.sh"

APP_NAME="SFAIT Remote Assistant.app"
APP_PATH="${PROJECT_DIR}/flutter/build/macos/Build/Products/Release/${APP_NAME}"
TS="$(date +%Y%m%d-%H%M%S)"
OUT_DIR="${SFAIT_EXPORT_DIR}/SFAIT-Remote-Assistant-macOS-${TS}"
TMP_ROOT="$(mktemp -d)"

cleanup() {
  rm -rf "${TMP_ROOT}"
}
trap cleanup EXIT

make_dmg() {
  local label="$1"
  local cargo_target="$2"
  local dylib_path="$3"
  local dmg_name="$4"
  local xcode_arch="${5:-}"

  cd "${PROJECT_DIR}"
  MACOSX_DEPLOYMENT_TARGET=10.14 cargo build --target "${cargo_target}" --features flutter --release
  cp "${dylib_path}" "${PROJECT_DIR}/target/release/liblibrustdesk.dylib"

  cd "${PROJECT_DIR}/flutter"
  flutter pub get
  if [ -n "${xcode_arch}" ]; then
    cd "${PROJECT_DIR}/flutter/macos"
    xcodebuild \
      -workspace Runner.xcworkspace \
      -scheme Runner \
      -configuration Release \
      -destination "platform=macOS" \
      ARCHS="${xcode_arch}" \
      ONLY_ACTIVE_ARCH=NO \
      build
  else
    flutter build macos --release
  fi

  local stage_dir="${TMP_ROOT}/${label}"
  mkdir -p "${stage_dir}"
  ditto "${APP_PATH}" "${stage_dir}/${APP_NAME}"

  hdiutil create \
    -volname "SFAIT Remote Assistant" \
    -srcfolder "${stage_dir}" \
    -ov \
    -format UDZO \
    "${OUT_DIR}/${dmg_name}"
}

mkdir -p "${OUT_DIR}"

make_dmg \
  "apple-silicon" \
  "aarch64-apple-darwin" \
  "${PROJECT_DIR}/target/aarch64-apple-darwin/release/liblibrustdesk.dylib" \
  "SFAIT-Remote-Assistant-macOS-Apple-Silicon.dmg"

make_dmg \
  "intel" \
  "x86_64-apple-darwin" \
  "${PROJECT_DIR}/target/x86_64-apple-darwin/release/liblibrustdesk.dylib" \
  "SFAIT-Remote-Assistant-macOS-Intel.dmg" \
  "x86_64"

echo "${OUT_DIR}"
