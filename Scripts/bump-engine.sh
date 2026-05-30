#!/usr/bin/env bash
set -euo pipefail
ENGINE_REPO="${ENGINE_REPO:-$HOME/Dev/AetherEngine}"
RESOLVED="AetherPlayer.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
SHA=$(git -C "$ENGINE_REPO" rev-parse origin/main)
SUBJECT=$(git -C "$ENGINE_REPO" log -1 --format=%s origin/main)
if grep -q "$SHA" "$RESOLVED"; then echo "Already at $SHA"; exit 0; fi
/usr/bin/sed -i '' -E "s/(\"revision\" : \")[0-9a-f]{40}(\")/\1$SHA\2/" "$RESOLVED"
xcodebuild -project AetherPlayer.xcodeproj -scheme AetherPlayer -resolvePackageDependencies
git add "$RESOLVED"
git commit -m "chore(deps): bump AetherEngine to $SHA -- $SUBJECT"
git push
echo "Bumped to $SHA"
