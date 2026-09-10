#!/bin/zsh
set -eu
cd "${0:A:h:h}"
mkdir -p .build/demo docs/assets
xcrun swiftc Sources/DuoFlip/Effect.swift Sources/DuoFlip/DesktopPolicy.swift \
    Sources/DuoFlip/DuoFlipMark.swift scripts/demo/RenderDemo.swift \
    -o .build/demo/render-demo -framework AppKit -framework MetalKit \
    -framework CoreImage -framework AVFoundation -framework ImageIO
.build/demo/render-demo docs/assets

