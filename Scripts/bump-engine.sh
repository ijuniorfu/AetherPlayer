#!/usr/bin/env bash
set -euo pipefail
ENGINE_REPO="${ENGINE_REPO:-$HOME/Dev/AetherEngine}"
PROJECT_YML="project.yml"
PBXPROJ="AetherPlayer.xcodeproj/project.pbxproj"
RESOLVED="AetherPlayer.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
# Consumers pin the latest RELEASE tag, not the main tip (Vincent,
# 2026-07-15); unreleased engine commits are tested via a local
# uncommitted pin instead.
git -C "$ENGINE_REPO" fetch --tags --quiet origin
TAG=$(git -C "$ENGINE_REPO" tag --list | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -1)
SHA=$(git -C "$ENGINE_REPO" rev-parse "$TAG^{commit}")
SUBJECT=$(git -C "$ENGINE_REPO" log -1 --format=%s "$SHA")
if grep -q "$SHA" "$PROJECT_YML"; then echo "Already at release $TAG ($SHA)"; exit 0; fi

# project.yml is the SOURCE OF TRUTH: CI runs `xcodegen generate`, which
# rebuilds project.pbxproj from it, and AetherEngine is pinned there by
# exact revision. Editing the generated pbxproj / Package.resolved alone
# is undone (pbxproj by the next xcodegen, Package.resolved by the next
# resolve, which rewrites it to match the project). So bump project.yml
# first; the other two are kept in sync so local builds match without a
# regenerate.
#
# Each rewrite is scoped to the AetherEngine block (anchored on its URL)
# so Sparkle / FFmpegBuild keep their own pins. perl -0777 (slurp) lets
# .*? span lines; macOS awk has no {40} interval support.
/usr/bin/perl -0777 -pi -e "s#(superuser404notfound/AetherEngine.*?revision: )[0-9a-f]{40}#\${1}$SHA#s"   "$PROJECT_YML"
/usr/bin/perl -0777 -pi -e "s#(superuser404notfound/AetherEngine\".*?revision = )[0-9a-f]{40}#\${1}$SHA#s" "$PBXPROJ"
/usr/bin/perl -0777 -pi -e "s#(AetherEngine\".*?\"revision\" : \")[0-9a-f]{40}#\${1}$SHA#s"                "$RESOLVED"

# Resolve so SwiftPM fetches the new commit. If a freshly-pushed SHA
# refuses to stick (resolve silently downgrades to the last resolvable
# revision), the per-project mirror under DerivedData is stale: run
# `git -C <DerivedData>/SourcePackages/repositories/AetherEngine-* fetch --all`.
xcodebuild -project AetherPlayer.xcodeproj -scheme AetherPlayer -resolvePackageDependencies
git add "$PROJECT_YML" "$PBXPROJ" "$RESOLVED"
git commit -m "chore(deps): bump AetherEngine to $TAG ($SHA) -- $SUBJECT"
git push
echo "Bumped to release $TAG ($SHA)"
