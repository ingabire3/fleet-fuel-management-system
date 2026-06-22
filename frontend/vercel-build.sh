#!/usr/bin/env bash
# Vercel has no Flutter SDK preinstalled, so this fetches the stable channel,
# then builds the web release with prod env values baked in via --dart-define.
# Required Vercel project env vars: API_BASE_URL, SUPABASE_URL, SUPABASE_ANON_KEY.
set -euo pipefail

FLUTTER_VERSION="3.27.1"
FLUTTER_DIR="$HOME/flutter"

if [ ! -d "$FLUTTER_DIR" ]; then
  git clone --depth 1 --branch "$FLUTTER_VERSION" https://github.com/flutter/flutter.git "$FLUTTER_DIR"
fi
export PATH="$FLUTTER_DIR/bin:$PATH"

flutter config --enable-web
flutter pub get

flutter build web --release \
  --dart-define=API_BASE_URL="${API_BASE_URL:-}" \
  --dart-define=SUPABASE_URL="${SUPABASE_URL:-}" \
  --dart-define=SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY:-}"
