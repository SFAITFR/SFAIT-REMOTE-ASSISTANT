#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

source "${SCRIPT_DIR}/sfait-build-env.sh"

cd "${PROJECT_DIR}"
MACOSX_DEPLOYMENT_TARGET=10.14 cargo build --features flutter --release

cd "${PROJECT_DIR}/flutter"
flutter pub get
flutter build macos --release
