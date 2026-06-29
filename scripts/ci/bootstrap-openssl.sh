#!/usr/bin/env bash
set -euo pipefail

: "${TELEGRAM_PPC_CI_ROOT:?TELEGRAM_PPC_CI_ROOT is required}"
: "${TELEGRAM_PPC_OPENSSL_VERSION:=1.1.1w}"

src_root="$TELEGRAM_PPC_CI_ROOT/src"
archive="$src_root/openssl-${TELEGRAM_PPC_OPENSSL_VERSION}.tar.gz"
source_dir="$src_root/openssl-${TELEGRAM_PPC_OPENSSL_VERSION}"

mkdir -p "$src_root"

if [ ! -f "$archive" ]; then
  curl -fsSL "https://www.openssl.org/source/openssl-${TELEGRAM_PPC_OPENSSL_VERSION}.tar.gz" -o "$archive"
fi

if [ ! -f "$source_dir/Configure" ]; then
  tar -xf "$archive" -C "$src_root"
fi

build_one() {
  local name=$1 target=$2 cc=$3 sdk_root=$4 deployment=$5
  local prefix="$TELEGRAM_PPC_CI_ROOT/deps/$name/openssl"
  local build_dir="$TELEGRAM_PPC_CI_ROOT/build/openssl-$name"
  local legacy_cflags=()

  if [ -f "$prefix/lib/libssl.a" ] && [ -f "$prefix/lib/libcrypto.a" ]; then
    return
  fi

  rm -rf "$build_dir"
  mkdir -p "$build_dir"
  cp -a "$source_dir/." "$build_dir/"

  (
    cd "$build_dir"
    export CC="$cc"
    if [ "$deployment" = "10.4" ]; then
      legacy_cflags=(-D__DARWIN_UNIX03=0)
    fi
    ./Configure "$target" \
      no-shared \
      no-tests \
      --prefix="$prefix" \
      --openssldir="$prefix/ssl" \
      -isysroot "$sdk_root" \
      -mmacosx-version-min="$deployment" \
      "${legacy_cflags[@]}"
    make -j"${TELEGRAM_PPC_JOBS:-2}"
    make install_sw
  )
}

build_one ppc darwin-ppc-cc "$TELEGRAM_PPC_PPC_CC" "$TELEGRAM_PPC_SDK_ROOT" 10.4
build_one i386 darwin-i386-cc "$TELEGRAM_PPC_I386_CC" "$TELEGRAM_PPC_SDK_ROOT" 10.4
build_one x86_64 darwin64-x86_64-cc "$TELEGRAM_PPC_X86_64_CC" "$TELEGRAM_PPC_SDK_ROOT" 10.5
build_one arm64 darwin64-arm64-cc "$TELEGRAM_PPC_ARM64_CC" "$TELEGRAM_PPC_ARM64_SDK_ROOT" 11.0
