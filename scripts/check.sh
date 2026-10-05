#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
defaults delete com.mier.TypingPall 2>/dev/null || true
defaults write com.mier.TypingPall NSQuitAlwaysKeepsWindows -bool false
defaults write com.mier.TypingPall ApplePersistenceIgnoreState -bool true
rm -rf ~/Library/Saved\ Application\ State/com.mier.TypingPall.savedState 2>/dev/null || true
derived_data="${TYPINGPALL_DERIVED_DATA:-$PWD/build/DerivedData}"
xcodebuild -project TypingPall.xcodeproj -scheme TypingPall \
  -destination 'platform=macOS' -derivedDataPath "$derived_data" \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_ALLOWED=YES test "$@"
xcodebuild -project TypingPall.xcodeproj -scheme TypingPall \
  -configuration Release -destination 'generic/platform=macOS' \
  -derivedDataPath "$derived_data" ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO \
  CODE_SIGNING_ALLOWED=NO build
