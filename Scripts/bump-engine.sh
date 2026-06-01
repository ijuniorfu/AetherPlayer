#!/usr/bin/env bash
set -euo pipefail
ENGINE_REPO="${ENGINE_REPO:-$HOME/Dev/AetherEngine}"
PBXPROJ="AetherPlayer.xcodeproj/project.pbxproj"
RESOLVED="AetherPlayer.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
SHA=$(git -C "$ENGINE_REPO" rev-parse origin/main)
SUBJECT=$(git -C "$ENGINE_REPO" log -1 --format=%s origin/main)
if grep -q "$SHA" "$PBXPROJ"; then echo "Already at $SHA"; exit 0; fi

# AetherEngine is pinned by EXACT revision in the project itself
# (XCRemoteSwiftPackageReference, kind = revision). project.pbxproj is
# the source of truth; Package.resolved is downstream and gets rewritten
# back to match the project on resolve. So both must be bumped, and the
# pbxproj is the one that actually moves the pin.
#
# Both rewrites are scoped to the AetherEngine block: anchor on the
# AetherEngine URL, then the first revision after it is this pin's. A
# blanket replace would clobber FFmpegBuild / Sparkle (their own pins).
# perl -0777 (slurp) so .*? can span lines; macOS awk lacks {40}.
/usr/bin/perl -0777 -pi -e "s#(superuser404notfound/AetherEngine\".*?revision = )[0-9a-f]{40}#\${1}$SHA#s" "$PBXPROJ"
/usr/bin/perl -0777 -pi -e "s#(AetherEngine\".*?\"revision\" : \")[0-9a-f]{40}#\${1}$SHA#s" "$RESOLVED"

xcodebuild -project AetherPlayer.xcodeproj -scheme AetherPlayer -resolvePackageDependencies
git add "$PBXPROJ" "$RESOLVED"
git commit -m "chore(deps): bump AetherEngine to $SHA -- $SUBJECT"
git push
echo "Bumped to $SHA"
