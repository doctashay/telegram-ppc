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

verify_ppc_tdlib_patch() {
  local tdlib="$frameworks/libtdjson.dylib"
  local tmpdir slice

  "$TELEGRAM_PPC_LIPO" "$tdlib" -verify_arch ppc >/dev/null 2>&1 ||
    "$TELEGRAM_PPC_LIPO" "$tdlib" -verify_arch ppc7400 >/dev/null 2>&1 ||
    return 0

  tmpdir="$(mktemp -d "${TMPDIR:-/tmp}/sailplane-tdlib-verify.XXXXXX")"
  slice="$tmpdir/libtdjson-ppc.dylib"
  if "$TELEGRAM_PPC_LIPO" -info "$tdlib" 2>/dev/null | grep -q "Non-fat"; then
    slice="$tdlib"
  else
    "$TELEGRAM_PPC_LIPO" "$tdlib" -thin ppc -output "$slice" 2>/dev/null ||
      "$TELEGRAM_PPC_LIPO" "$tdlib" -thin ppc7400 -output "$slice"
  fi

  if LC_ALL=C grep -a -q "TDLib requires little-endian platform" "$slice"; then
    rm -rf "$tmpdir"
    echo "PPC libtdjson.dylib contains upstream little-endian abort; use the PPCPorts big-endian patch" >&2
    exit 1
  fi

  rm -rf "$tmpdir"
}

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

bad_bundled_loads="$(
  {
    printf '%s\n' "$binary"
    find "$frameworks" -maxdepth 1 -type f -name "*.dylib"
  } | while read -r target; do
    "$TELEGRAM_PPC_OTOOL" -L "$target" 2>/dev/null | awk '/^[[:space:]]/ {print $1}' | while read -r load; do
      [ -n "$load" ] || continue
      name="$(basename "$load")"
      [ -e "$frameworks/$name" ] || continue
      case "$load" in
        @executable_path/*|@loader_path/*|@rpath/*) continue ;;
      esac
      printf '%s -> %s\n' "$target" "$load"
    done
  done | sort -u
)"

if [ -n "$bad_bundled_loads" ]; then
  echo "release app references bundled libraries through non-bundle load paths:" >&2
  echo "$bad_bundled_loads" >&2
  exit 1
fi

verify_ppc_tdlib_patch

echo "verified $app"
