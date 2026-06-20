#!/usr/bin/env bash
set -euo pipefail

: "${TELEGRAM_PPC_CI_ROOT:?TELEGRAM_PPC_CI_ROOT is required}"
: "${TELEGRAM_PPC_DARWIN_XTOOLS_REV:=linux-xtools-0-7-0r0}"

src_root="$TELEGRAM_PPC_CI_ROOT/src"
xtools_src="$src_root/darwin-xtools"
build_dir="$TELEGRAM_PPC_CI_ROOT/build/darwin-xtools-ppc"
prefix="$TELEGRAM_PPC_CI_ROOT/linux-ppc-darwin9-xtools"
bin_dir="$TELEGRAM_PPC_CI_ROOT/bin"

mkdir -p "$src_root" "$build_dir" "$bin_dir"

if [ ! -d "$xtools_src/.git" ]; then
  git clone --depth 1 --branch "$TELEGRAM_PPC_DARWIN_XTOOLS_REV" https://github.com/iains/darwin-xtools.git "$xtools_src"
fi

real_ld="$prefix/bin/powerpc-apple-darwin9-ld"
fallback_ld="$prefix/bin/ld"

if [ ! -x "$real_ld" ] && [ ! -x "$fallback_ld" ]; then
  cmake -S "$xtools_src" -B "$build_dir" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$prefix" \
    -DCMAKE_C_FLAGS="-U_FORTIFY_SOURCE" \
    -DCMAKE_CXX_FLAGS="-U_FORTIFY_SOURCE" \
    -DCCTOOLS_EFITOOLS=OFF \
    -DCCTOOLS_LD_CLASSIC=NO
  cmake --build "$build_dir" --target install -- -j"${TELEGRAM_PPC_JOBS:-2}"
fi

if [ ! -x "$real_ld" ] && [ -x "$fallback_ld" ]; then
  real_ld="$fallback_ld"
fi

if [ ! -x "$real_ld" ]; then
  echo "Expected PPC Darwin linker was not installed at $prefix/bin/ld" >&2
  find "$prefix" -maxdepth 3 -type f -o -type l >&2
  exit 1
fi

cat > "$bin_dir/powerpc-apple-darwin9-ld" <<EOF
#!/usr/bin/env bash
set -e
real_ld='$real_ld'
if [ "\$#" -eq 1 ] && { [ "\$1" = "-v" ] || [ "\$1" = "--version" ]; }; then
  "\$real_ld" "\$@" || true
  exit 0
fi
exec "\$real_ld" "\$@"
EOF
chmod +x "$bin_dir/powerpc-apple-darwin9-ld"

if ! "$bin_dir/powerpc-apple-darwin9-ld" -v >/dev/null 2>&1; then
  echo "PPC Darwin linker wrapper is not executable" >&2
  ldd "$real_ld" >&2 || true
  exit 1
fi

echo "TELEGRAM_PPC_PPC_LD=$bin_dir/powerpc-apple-darwin9-ld" >> "$GITHUB_ENV"
