#!/usr/bin/env bash
set -euo pipefail

FLUTTER_VERSION="3.29.3"

if [ ! -d "$HOME/flutter" ]; then
  echo "Installing Flutter $FLUTTER_VERSION..."
  git clone https://github.com/flutter/flutter.git -b "$FLUTTER_VERSION" --depth 1 "$HOME/flutter"
fi

export PATH="$HOME/flutter/bin:$PATH"

flutter --version

SUPABASE_URL_VALUE="$(printf '%s' "${SUPABASE_URL:-}" | xargs)"
SUPABASE_ANON_KEY_VALUE="$(printf '%s' "${SUPABASE_ANON_KEY:-}" | xargs)"

if [ -z "$SUPABASE_URL_VALUE" ] || [ -z "$SUPABASE_ANON_KEY_VALUE" ]; then
  echo "ERROR: SUPABASE_URL and SUPABASE_ANON_KEY must be set as Vercel environment variables."
  exit 1
fi

flutter pub get

flutter build web --release \
  --dart-define=SUPABASE_URL="$SUPABASE_URL_VALUE" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY_VALUE"
