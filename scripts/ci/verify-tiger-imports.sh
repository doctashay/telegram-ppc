#!/usr/bin/env bash
set -euo pipefail

app=${1:?Usage: verify-tiger-imports.sh APP}
: "${TELEGRAM_PPC_LIPO:=lipo}"
: "${TELEGRAM_PPC_OTOOL:=otool}"
: "${TELEGRAM_PPC_NM:=${TELEGRAM_PPC_OTOOL%otool}nm}"
command -v "$TELEGRAM_PPC_LIPO" >/dev/null
command -v "$TELEGRAM_PPC_NM" >/dev/null
test -f "$app/Contents/MacOS/Sailplane"

failed=0
while IFS= read -r binary; do
  for arch in ppc i386; do
    slice=$arch
    if ! "$TELEGRAM_PPC_LIPO" "$binary" -verify_arch "$slice" >/dev/null 2>&1; then
      if [ "$arch" != ppc ] || ! "$TELEGRAM_PPC_LIPO" "$binary" -verify_arch ppc7400 >/dev/null 2>&1; then
        continue
      fi
      slice=ppc7400
    fi
    imports=$("$TELEGRAM_PPC_NM" -arch "$slice" -u "$binary")
    # Match literal Mach-O symbol suffixes.
    # shellcheck disable=SC2016
    incompatible=$(printf '%s\n' "$imports" | grep -E '\$(UNIX2003|INODE64|1050)(\$|$)' || true)
    if [ -n "$incompatible" ]; then
      printf 'Tiger-incompatible imports in %s (%s):\n%s\n' "$binary" "$slice" "$incompatible" >&2
      failed=1
    fi
    if [[ "${TELEGRAM_PPC_SDK_ROOT:-}" == */MacOSX10.4u.sdk ]]; then
      if ! python3 "$(dirname "${BASH_SOURCE[0]}")/verify-tiger-system-imports.py" \
        "$TELEGRAM_PPC_NM" "$TELEGRAM_PPC_SDK_ROOT" "$arch" "$binary"; then
        failed=1
      fi
    fi
  done
done < <(find "$app/Contents/MacOS" "$app/Contents/Frameworks" -type f)

exit "$failed"
