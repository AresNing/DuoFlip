#!/bin/zsh
set -eu
cd "${0:A:h:h}"
mkdir -p .build
stage=$(mktemp -d "$PWD/.build/stage.XXXXXX")
app="$stage/DuoFlip.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
xcrun swiftc -O -target arm64-apple-macos15.2 Sources/DuoFlip/*.swift \
    -o "$app/Contents/MacOS/DuoFlip" \
    -framework AppKit -framework IOKit -framework MetalKit -framework CoreImage \
    -framework ScreenCaptureKit -framework Carbon -framework SwiftUI
xcrun swiftc Sources/DuoFlip/DuoFlipMark.swift Brand/RenderBrand.swift -o "$stage/render-brand"
"$stage/render-brand" "$stage/brand"
mkdir -p "$stage/AppIcon.iconset"
for size in 16 32 128 256 512; do
    sips -z "$size" "$size" "$stage/brand/AppIcon.png" --out "$stage/AppIcon.iconset/icon_${size}x${size}.png" >/dev/null
    double=$((size * 2))
    sips -z "$double" "$double" "$stage/brand/AppIcon.png" --out "$stage/AppIcon.iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$stage/AppIcon.iconset" -o "$app/Contents/Resources/AppIcon.icns"
cp Packaging/Info.plist "$app/Contents/Info.plist"
cp ThirdParty/LidAngleSensor/LICENSE "$app/Contents/Resources/LidAngleSensor-LICENSE.txt"
cp THIRD_PARTY_NOTICES.md "$app/Contents/Resources/THIRD_PARTY_NOTICES.md"
if [[ -f LICENSE ]]; then cp LICENSE "$app/Contents/Resources/LICENSE.txt"; fi
identity=${LID_SIGNING_IDENTITY:--}
if [[ "$identity" == - ]]; then
    codesign --force --sign - "$app"
else
    codesign --force --options runtime --timestamp --sign "$identity" "$app"
fi
codesign --verify --deep --strict "$app"
# Keep the previous generated build so a running copy is not overwritten.
if [[ -e .build/DuoFlip.app ]]; then
    mv .build/DuoFlip.app "$stage/previous-DuoFlip.app"
fi
mv "$app" .build/DuoFlip.app
print "Built $PWD/.build/DuoFlip.app"
