#!/bin/bash
# Vercel install step: fetch the pinned Flutter SDK and resolve packages.
set -e

# Vercel's build sandbox trips git's "dubious ownership" check inside the
# Flutter SDK (the tool runs git on its own dir on first run).
git config --global --add safe.directory '*'

# Pin the exact stable release used locally (see .deploy/build.sh).
curl -fsSL https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.47.1-stable.tar.xz | tar -xJ -C /vercel

/vercel/flutter/bin/flutter config --no-analytics
/vercel/flutter/bin/flutter pub get
