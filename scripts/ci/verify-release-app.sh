#!/usr/bin/env bash
set -euo pipefail

app="${1:-dist/Sailplane.app}"

if [ ! -d "$app" ]; then
  echo "app bundle does not exist: $app" >&2
  exit 1
fi

binary="$app/Contents/MacOS/Sailplane"
frameworks="$app/Contents/Frameworks"
plist="$app/Contents/Info.plist"

for path in "$binary" "$frameworks/libtdjson.dylib" "$plist"; do
  if [ ! -e "$path" ]; then
    echo "release app is missing $path" >&2
    exit 1
  fi
done

: "${TELEGRAM_PPC_LIPO:=lipo}"
: "${TELEGRAM_PPC_OTOOL:=otool}"
: "${TELEGRAM_PPC_FORBIDDEN_LOAD_PATH_PATTERN:=/opt/local|/home/|/mnt/|/tmp/}"

"$TELEGRAM_PPC_LIPO" "$binary" -verify_arch ppc i386 x86_64 arm64

bad_loads="$(
  {
    printf '%s\n' "$binary"
    find "$frameworks" -maxdepth 1 -type f -name "*.dylib"
  } | while read -r target; do
    "$TELEGRAM_PPC_OTOOL" -L "$target" 2>/dev/null | awk '/^[[:space:]]/ {print $1}' | grep -E "$TELEGRAM_PPC_FORBIDDEN_LOAD_PATH_PATTERN" || true
  done | sort -u
)"

if [ -n "$bad_loads" ]; then
  echo "release app contains non-relocatable load commands:" >&2
  echo "$bad_loads" >&2
  exit 1
fi

echo "verified $app"
