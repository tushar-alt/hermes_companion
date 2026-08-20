#!/bin/bash
# Vercel build step: compile the Flutter web release into build/web.
# Each build gets a unique build id (git sha) + incrementing build number:
#  - build_id.json lets the running app detect a newly deployed version
#  - the build number flows into version.json, which the bootstrap uses as
#    the main.dart.js cache-buster (so refreshes always fetch the new bundle)
set -e

export PATH=/vercel/flutter/bin:$PATH

SHA=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
BN=$(git rev-list --count HEAD 2>/dev/null || date +%s)

flutter build web --release --dart-define=BUILD_ID="$SHA" --build-number="$BN"

printf '{"build_id":"%s","build_number":"%s"}\n' "$SHA" "$BN" > build/web/build_id.json
