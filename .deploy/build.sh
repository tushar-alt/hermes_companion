#!/bin/bash
# Vercel build step: compile the Flutter web release into build/web.
set -e

export PATH=/vercel/flutter/bin:$PATH
flutter build web --release
