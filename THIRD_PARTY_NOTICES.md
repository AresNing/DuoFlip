# Third-party notices

## LidAngleSensor

DuoFlip's `Sources/DuoFlip/Sensor.swift` references the lid-angle HID protocol demonstrated by [Sam Gold's LidAngleSensor](https://github.com/samhenrigold/LidAngleSensor): Apple orientation sensor matching, feature report 1, and the little-endian angle field.

Upstream author: Sam Gold. Upstream license: Apache License 2.0, reproduced in [ThirdParty/LidAngleSensor/LICENSE](ThirdParty/LidAngleSensor/LICENSE). Source and license reviewed at revision `f7e4e5cb46fe13a518091ce5d47f0ec2e3fecd80`.

DuoFlip uses its own sensor wrapper, validation, polling lifecycle and error handling, and does not embed the upstream SwiftUI application or audio engines. The upstream license is included conservatively with this reference and in generated application bundles.

DuoFlip is an independent application. It is not affiliated with or endorsed by Apple or the upstream project. Original reference videos and screenshots are not distributed in this repository.
