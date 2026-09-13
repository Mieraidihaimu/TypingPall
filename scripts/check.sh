#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
derived_data="${TYPINGPALL_DERIVED_DATA:-$PWD/build/DerivedData}"
xcodebuild -project TypingPall.xcodeproj -scheme TypingPall \
  -destination 'platform=macOS' -derivedDataPath "$derived_data" \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_ALLOWED=YES test "$@"
xcodebuild -project TypingPall.xcodeproj -scheme TypingPall \
  -configuration Release -destination 'generic/platform=macOS' \
  -derivedDataPath "$derived_data" ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO \
  CODE_SIGNING_ALLOWED=NO build
