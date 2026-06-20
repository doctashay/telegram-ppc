#!/usr/bin/env bash
set -euo pipefail

: "${TELEGRAM_PPC_CI_ROOT:?TELEGRAM_PPC_CI_ROOT is required}"
: "${TELEGRAM_PPC_ZLIB_VERSION:=1.3.1}"

src_root="$TELEGRAM_PPC_CI_ROOT/src"
archive="$src_root/zlib-${TELEGRAM_PPC_ZLIB_VERSION}.tar.gz"
source_dir="$src_root/zlib-${TELEGRAM_PPC_ZLIB_VERSION}"

mkdir -p "$src_root"

if [ ! -f "$archive" ]; then
  curl -fsSL "https://zlib.net/zlib-${TELEGRAM_PPC_ZLIB_VERSION}.tar.gz" -o "$archive"
fi

if [ ! -f "$source_dir/configure" ]; then
  tar -xf "$archive" -C "$src_root"
fi

build_one() {
  local name=$1 cc=$2 deployment=$3
  local prefix="$TELEGRAM_PPC_CI_ROOT/deps/$name/zlib"
  local build_dir="$TELEGRAM_PPC_CI_ROOT/build/zlib-$name"

  if [ -f "$prefix/lib/libz.a" ]; then
    return
  fi

  rm -rf "$build_dir"
  mkdir -p "$build_dir"
  cp -a "$source_dir/." "$build_dir/"

  (
    cd "$build_dir"
    export CC="$cc"
    export CFLAGS="-isysroot $TELEGRAM_PPC_SDK_ROOT -mmacosx-version-min=$deployment"
    ./configure --static --prefix="$prefix"
    make -j"${TELEGRAM_PPC_JOBS:-2}"
    make install
  )
}

build_one ppc "$TELEGRAM_PPC_PPC_CC" 10.4
build_one i386 "$TELEGRAM_PPC_I386_CC" 10.4
build_one x86_64 "$TELEGRAM_PPC_X86_64_CC" 10.5
