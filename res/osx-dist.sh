#!/usr/bin/env bash

echo $MACOS_CODESIGN_IDENTITY
cargo install flutter_rust_bridge_codegen --version 1.80.1 --features uuid
cd flutter; flutter pub get; cd -
~/.cargo/bin/flutter_rust_bridge_codegen --rust-input ./src/flutter_ffi.rs --dart-output ./flutter/lib/generated_bridge.dart --c-output ./flutter/macos/Runner/bridge_generated.h
./build.py --flutter
rm "sfait-remote-assistant-$VERSION-universal.dmg"
# security find-identity -v
codesign --force --options runtime -s $MACOS_CODESIGN_IDENTITY --deep --strict "./flutter/build/macos/Build/Products/Release/SFAIT Remote Assistant.app" -vvv
create-dmg --icon "SFAIT Remote Assistant.app" 200 190 --hide-extension "SFAIT Remote Assistant.app" --window-size 800 400 --app-drop-link 600 185 "sfait-remote-assistant-$VERSION-universal.dmg" "./flutter/build/macos/Build/Products/Release/SFAIT Remote Assistant.app"
codesign --force --options runtime -s $MACOS_CODESIGN_IDENTITY --deep --strict "sfait-remote-assistant-$VERSION-universal.dmg" -vvv
# notarize the sfait-remote-assistant-${{ env.VERSION }}-universal.dmg
rcodesign notary-submit --api-key-path ~/.p12/api-key.json  --staple "sfait-remote-assistant-$VERSION-universal.dmg"
