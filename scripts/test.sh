#!/bin/zsh
set -eu
cd "${0:A:h:h}"
[[ $# == 0 || ( $# == 1 && "$1" == --native ) ]] || { print -u2 'Usage: scripts/test.sh [--native]'; exit 1; }
mkdir -p .build/tests
xcrun swiftc Sources/DuoFlip/Effect.swift Sources/DuoFlip/DesktopPolicy.swift Tests/CoreCheck.swift \
    -o .build/tests/core-check -framework AppKit -framework MetalKit -framework CoreImage
.build/tests/core-check
xcrun swiftc Sources/DuoFlip/MeetingProtection.swift Tests/MeetingProtectionCheck.swift -o .build/tests/meeting-check
.build/tests/meeting-check
if [[ "${1:-}" == --native ]]; then
    xcrun swiftc Sources/DuoFlip/Effect.swift Tests/FirstFrameCheck.swift \
        -o .build/tests/first-frame-check -framework AppKit -framework MetalKit -framework CoreImage
    .build/tests/first-frame-check
fi
