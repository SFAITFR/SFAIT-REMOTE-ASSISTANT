#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

source "${SCRIPT_DIR}/sfait-build-env.sh"

# SFAIT edition (see src/brand.rs): "client" (default, incoming connections only)
# or "technician" (full app). Set SFAIT_EDITION=technician to build the technician one.
EDITION="${SFAIT_EDITION:-client}"
case "${EDITION}" in
  client)
    APP_DISPLAY_NAME="SFAIT Remote Assistant"
    CARGO_FEATURES="flutter"
    DMG_PREFIX="SFAIT-Remote-Assistant"
    DERIVED_DATA_PREFIX="macos"
    # The client Apple Silicon app is built by `flutter build macos`.
    ARM64_XCODE_ARCH=""
    ;;
  technician)
    APP_DISPLAY_NAME="SFAIT Remote Assistant Technician"
    CARGO_FEATURES="flutter,technician"
    DMG_PREFIX="SFAIT-Remote-Assistant-Technician"
    DERIVED_DATA_PREFIX="macos-technician"
    # `flutter build macos` cannot pass SFAIT_EDITION to Xcode, so use xcodebuild.
    ARM64_XCODE_ARCH="arm64"
    ;;
  *)
    echo "Unknown SFAIT_EDITION: ${EDITION} (expected client or technician)" >&2
    exit 1
    ;;
esac

APP_NAME="${APP_DISPLAY_NAME}.app"
APP_PATH="${PROJECT_DIR}/flutter/build/macos/Build/Products/Release/${APP_NAME}"
TS="$(date +%Y%m%d-%H%M%S)"
OUT_DIR="${SFAIT_EXPORT_DIR}/${DMG_PREFIX}-macOS-${TS}"
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
  MACOSX_DEPLOYMENT_TARGET=10.14 cargo build --target "${cargo_target}" --features "${CARGO_FEATURES}" --release
  cp "${dylib_path}" "${PROJECT_DIR}/target/release/liblibrustdesk.dylib"

  cd "${PROJECT_DIR}/flutter"
  flutter pub get
  local app_path="${APP_PATH}"
  if [ -n "${xcode_arch}" ]; then
    local derived_data="${PROJECT_DIR}/flutter/build/${DERIVED_DATA_PREFIX}-${label}"
    cd "${PROJECT_DIR}/flutter/macos"
    xcodebuild \
      -workspace Runner.xcworkspace \
      -scheme Runner \
      -configuration Release \
      -destination "platform=macOS,arch=${xcode_arch}" \
      -derivedDataPath "${derived_data}" \
      ARCHS="${xcode_arch}" \
      ONLY_ACTIVE_ARCH=NO \
      SFAIT_EDITION="${EDITION}" \
      build
    app_path="${derived_data}/Build/Products/Release/${APP_NAME}"
  else
    flutter build macos --release
  fi

  # The launchd daemon runs Contents/MacOS/service: ship the one built for this
  # architecture, then re-sign the bundle (ad-hoc) so its signature stays valid.
  cp -f "${PROJECT_DIR}/target/${cargo_target}/release/service" "${app_path}/Contents/MacOS/service"
  codesign --force --sign - "${app_path}/Contents/MacOS/service"
  codesign --force --sign - --preserve-metadata=entitlements,requirements,flags,runtime "${app_path}"
  codesign --verify --deep --strict "${app_path}"
  echo "${EDITION} ${label}: $(lipo -archs "${app_path}/Contents/MacOS/${APP_DISPLAY_NAME}") / service $(lipo -archs "${app_path}/Contents/MacOS/service") / dylib $(lipo -archs "${app_path}/Contents/Frameworks/liblibrustdesk.dylib")"

  local stage_dir="${TMP_ROOT}/${label}"
  mkdir -p "${stage_dir}"
  ditto "${app_path}" "${stage_dir}/${APP_NAME}"

  hdiutil create \
    -volname "${APP_DISPLAY_NAME}" \
    -srcfolder "${stage_dir}" \
    -ov \
    -format UDZO \
    "${OUT_DIR}/${dmg_name}"
}

# Same Flutter SDK fixes as RustDesk's own builds (.github/workflows/flutter-build.yml).
patch_flutter_sdk() {
  local binding="${FLUTTER_ROOT}/packages/flutter/lib/src/scheduler/binding.dart"
  [ -f "${binding}" ] || { echo "Missing ${binding}" >&2; exit 1; }
  # https://github.com/flutter/flutter/issues/133533: on macOS a desktop_multi_window
  # sub-window (the remote session) stops drawing after switching to another app and back.
  if grep -qE '^[[:space:]]*_setFramesEnabledState\(false\);' "${binding}"; then
    sed -i '' -E 's/^([[:space:]]*)_setFramesEnabledState\(false\);/\1\/\/_setFramesEnabledState(false);/' "${binding}"
    echo "Flutter SDK: workaround #133533 applied now"
  else
    echo "Flutter SDK: workaround #133533 already applied"
  fi
  grep -n '_setFramesEnabledState(false);' "${binding}"

  local dropdown="${PROJECT_DIR}/.github/patches/flutter_3.24.4_dropdown_menu_enableFilter.diff"
  if git -C "${FLUTTER_ROOT}" apply --check "${dropdown}" 2>/dev/null; then
    git -C "${FLUTTER_ROOT}" apply "${dropdown}"
    echo "Flutter SDK: dropdown_menu enableFilter patch applied now"
  elif git -C "${FLUTTER_ROOT}" apply -R --check "${dropdown}" 2>/dev/null; then
    echo "Flutter SDK: dropdown_menu enableFilter patch already applied"
  else
    echo "Flutter SDK: dropdown_menu enableFilter patch does not apply, skipped"
  fi
}

patch_flutter_sdk
mkdir -p "${OUT_DIR}"

make_dmg \
  "apple-silicon" \
  "aarch64-apple-darwin" \
  "${PROJECT_DIR}/target/aarch64-apple-darwin/release/liblibrustdesk.dylib" \
  "${DMG_PREFIX}-macOS-Apple-Silicon.dmg" \
  "${ARM64_XCODE_ARCH}"

make_dmg \
  "intel" \
  "x86_64-apple-darwin" \
  "${PROJECT_DIR}/target/x86_64-apple-darwin/release/liblibrustdesk.dylib" \
  "${DMG_PREFIX}-macOS-Intel.dmg" \
  "x86_64"

echo "${OUT_DIR}"
