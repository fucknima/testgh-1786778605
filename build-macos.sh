#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
SDK="$(xcrun --sdk iphoneos --show-sdk-path)"
xcrun --sdk iphoneos clang -target arm64-apple-ios15.0 -arch arm64 -O2 \
  -fvisibility=hidden -dynamiclib -Wl,-install_name,@rpath/MuguetCN.dylib \
  -framework Foundation -framework UIKit -lobjc \
  MuguetCN.c -o MuguetCN.dylib
file MuguetCN.dylib
xcrun --sdk iphoneos lipo -info MuguetCN.dylib
xcrun --sdk iphoneos otool -L MuguetCN.dylib
codesign --force --sign - MuguetCN.dylib
shasum -a 256 MuguetCN.dylib
