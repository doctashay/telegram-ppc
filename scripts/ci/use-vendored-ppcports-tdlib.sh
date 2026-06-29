#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
vendor_dir="${TELEGRAM_PPC_PPCPORTS_TDLIB_DIR:-$repo_root/scripts/ci/vendor/ppcports-tdlib-ppc/lib}"

tdlib="$vendor_dir/libtdjson.dylib"
bundle_libs=(
  "$vendor_dir/libMacportsLegacySupport.dylib"
  "$vendor_dir/libssl.3.dylib"
  "$vendor_dir/libcrypto.3.dylib"
  "$vendor_dir/libz.1.dylib"
  "$vendor_dir/libatomic.1.dylib"
  "$vendor_dir/libstdc++.6.dylib"
  "$vendor_dir/libgcc_s.1.1.dylib"
  "$vendor_dir/libiconv.2.dylib"
)

require_file() {
  local path=$1
  if [ ! -f "$path" ]; then
    echo "missing vendored PPCPorts TDLib file: $path" >&2
    exit 1
  fi
}

join_semicolon() {
  local result="" item
  for item in "$@"; do
    if [ -z "$result" ]; then
      result="$item"
    else
      result="$result;$item"
    fi
  done
  printf '%s\n' "$result"
}

require_file "$tdlib"
for lib in "${bundle_libs[@]}"; do
  require_file "$lib"
done

if LC_ALL=C grep -a -q "TDLib requires little-endian platform" "$tdlib"; then
  echo "vendored PPCPorts TDLib contains upstream little-endian abort" >&2
  exit 1
fi

vendored_bundle_libs="$(join_semicolon "${bundle_libs[@]}")"

export TELEGRAM_PPC_PPC_TDLIB_LIBRARY="$tdlib"
if [ -n "${TELEGRAM_PPC_PPC_BUNDLE_LIBS:-}" ]; then
  export TELEGRAM_PPC_PPC_BUNDLE_LIBS="$vendored_bundle_libs;$TELEGRAM_PPC_PPC_BUNDLE_LIBS"
else
  export TELEGRAM_PPC_PPC_BUNDLE_LIBS="$vendored_bundle_libs"
fi
