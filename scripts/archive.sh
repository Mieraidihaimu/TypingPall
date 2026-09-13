#!/bin/bash
# Creates a local, signed archive. Does not upload or publish it.
set -euo pipefail
cd "$(dirname "$0")/.."
: "${DEVELOPMENT_TEAM:?Set DEVELOPMENT_TEAM to your Apple Developer team ID}"
: "${SIGNING_IDENTITY:?Set SIGNING_IDENTITY to your Developer ID Application certificate name}"
archive_path="${TYPINGPALL_ARCHIVE_PATH:-$PWD/build/TypingPall.xcarchive}"
if [[ -e "$archive_path" ]]; then
  echo "Archive already exists: $archive_path. Choose a new TYPINGPALL_ARCHIVE_PATH." >&2
  exit 1
fi
xcodebuild -project TypingPall.xcodeproj -scheme TypingPall \
  -configuration Release -destination 'generic/platform=macOS' \
  -archivePath "$archive_path" -derivedDataPath "$PWD/build/ReleaseDerivedData" \
  ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO \
  DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="$SIGNING_IDENTITY" ENABLE_HARDENED_RUNTIME=YES \
  OTHER_CODE_SIGN_FLAGS=--timestamp archive
codesign --verify --deep --strict --verbose=2 "$archive_path/Products/Applications/TypingPall.app"
echo "Signed archive: $archive_path"
