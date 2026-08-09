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
if grep -q "$SHA" "$PROJECT_YML"; then
    echo "Already at release $TAG ($SHA)"
    ENGINE_CURRENT=1
else
    ENGINE_CURRENT=0
fi

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
if [ "$ENGINE_CURRENT" -eq 0 ]; then
    /usr/bin/perl -0777 -pi -e "s#(superuser404notfound/AetherEngine.*?revision: )[0-9a-f]{40}#\${1}$SHA#s"   "$PROJECT_YML"
    /usr/bin/perl -0777 -pi -e "s#(superuser404notfound/AetherEngine\".*?revision = )[0-9a-f]{40}#\${1}$SHA#s" "$PBXPROJ"
    /usr/bin/perl -0777 -pi -e "s#(AetherEngine\".*?\"revision\" : \")[0-9a-f]{40}#\${1}$SHA#s"                "$RESOLVED"
fi

# Cascade transitive deps, the way Sodalite's script already does. The engine
# pins FFmpegBuild by exact commit in its own Package.resolved, but SwiftPM
# never reads a dependency's Package.resolved, only the root's, and
# -resolvePackageDependencies keeps an existing pin that still satisfies the
# version range. So an engine release that carries a new decoder arrives here
# with the OLD binaries and no error anywhere: 6.18.0 routes qtrle to
# libavcodec, FFmpegBuild 2.4.0 has no qtrle decoder, and the file fails a step
# later than before. Runs even when the engine pin is already current, since
# that is exactly the state this drifts into.
for DEP in ffmpegbuild; do
    ENGINE_DEP_SHA=$(python3 -c "
import json, sys
try:
    with open('$ENGINE_REPO/Package.resolved') as f:
        for pin in json.load(f)['pins']:
            if pin['identity'] == '$DEP':
                print(pin['state']['revision']); break
except Exception:
    pass
")
    [ -n "$ENGINE_DEP_SHA" ] || continue
    OURS=$(python3 -c "
import json
with open('$RESOLVED') as f:
    for pin in json.load(f)['pins']:
        if pin['identity'] == '$DEP':
            print(pin['state']['revision']); break
")
    if [ -n "$OURS" ] && [ "$ENGINE_DEP_SHA" != "$OURS" ]; then
        echo "  transitive bump: $DEP ${OURS:0:7} -> ${ENGINE_DEP_SHA:0:7}"
        /usr/bin/perl -pi -e "s#$OURS#$ENGINE_DEP_SHA#" "$RESOLVED"
    fi
done

# Resolve so SwiftPM fetches the new commit. If a freshly-pushed SHA
# refuses to stick (resolve silently downgrades to the last resolvable
# revision), the per-project mirror under DerivedData is stale: run
# `git -C <DerivedData>/SourcePackages/repositories/AetherEngine-* fetch --all`.
xcodebuild -project AetherPlayer.xcodeproj -scheme AetherPlayer -resolvePackageDependencies
git add "$PROJECT_YML" "$PBXPROJ" "$RESOLVED"
if git diff --cached --quiet; then
    echo "Nothing to commit; already at release $TAG ($SHA) with matching transitive pins"
    exit 0
fi
if [ "$ENGINE_CURRENT" -eq 0 ]; then
    git commit -m "chore(deps): bump AetherEngine to $TAG ($SHA) -- $SUBJECT"
else
    git commit -m "chore(deps): cascade the engine's transitive pins at AetherEngine $TAG"
fi
git push
echo "Bumped to release $TAG ($SHA)"
