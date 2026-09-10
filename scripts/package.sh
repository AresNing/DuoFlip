#!/bin/zsh
set -eu
cd "${0:A:h:h}"
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Packaging/Info.plist)
deliverable="dist/DuoFlip-${version}"
for artifact in "$deliverable" "${deliverable}-arm64.dmg" "${deliverable}-arm64.zip" "${deliverable}-SHA256.txt"; do
    [[ ! -e "$artifact" ]] || { print -u2 "$artifact already exists; move the previous generated package or bump the version"; exit 1; }
done
./scripts/build.sh
stage=$(mktemp -d "$PWD/.build/package.XXXXXX")
ditto .build/DuoFlip.app "$stage/DuoFlip.app"
app="$stage/DuoFlip.app"
# Optional upload only when a Developer ID identity and a Keychain profile are supplied.
if [[ -n "${LID_NOTARY_PROFILE:-}" ]]; then
    [[ "${LID_SIGNING_IDENTITY:--}" != - ]] || { print -u2 'Developer ID signing identity required for notarization'; exit 1; }
    ditto -c -k --keepParent "$app" "$stage/notary.zip"
    xcrun notarytool submit "$stage/notary.zip" --keychain-profile "$LID_NOTARY_PROFILE" --wait
    xcrun stapler staple "$app"
    xcrun stapler validate "$app"
fi
mkdir -p "$deliverable"
ditto "$app" "$deliverable/DuoFlip.app"
cp Packaging/使用说明.txt "$deliverable/使用说明.txt"
cp Packaging/Usage.en.txt "$deliverable/Usage.en.txt"
cp THIRD_PARTY_NOTICES.md "$deliverable/THIRD_PARTY_NOTICES.md"
ln -s /Applications "$deliverable/Applications"
hdiutil create -volname "DuoFlip ${version}" -srcfolder "$deliverable" -format UDZO "${deliverable}-arm64.dmg"
hdiutil verify "${deliverable}-arm64.dmg"
ditto -c -k --keepParent "$deliverable" "${deliverable}-arm64.zip"
(cd dist; shasum -a 256 "DuoFlip-${version}-arm64.dmg" "DuoFlip-${version}-arm64.zip" > "DuoFlip-${version}-SHA256.txt")
print "Packaged $PWD/${deliverable}-arm64.dmg"
