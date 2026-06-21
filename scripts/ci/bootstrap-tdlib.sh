#!/usr/bin/env bash
set -euo pipefail

: "${TELEGRAM_PPC_CI_ROOT:?TELEGRAM_PPC_CI_ROOT is required}"
: "${TELEGRAM_PPC_TDLIB_VERSION:=v1.8.65}"

src_root="$TELEGRAM_PPC_CI_ROOT/src"
td_src="$src_root/td"

mkdir -p "$src_root"

if [ ! -d "$td_src/.git" ]; then
  git clone --depth 1 --branch "$TELEGRAM_PPC_TDLIB_VERSION" https://github.com/tdlib/td.git "$td_src"
fi

build_one() {
  local name=$1 arch=$2 cc=$3 cxx=$4 sdk_root=$5 deployment=$6
  local build_dir="$TELEGRAM_PPC_CI_ROOT/build/tdlib-$name"
  local install_dir="$TELEGRAM_PPC_CI_ROOT/deps/$name/tdlib"
  local zlib_root="$TELEGRAM_PPC_CI_ROOT/deps/$name/zlib"
  local openssl_root="$TELEGRAM_PPC_CI_ROOT/deps/$name/openssl"

  if [ -f "$install_dir/lib/libtdjson.dylib" ]; then
    return
  fi

  cmake -S "$td_src" -B "$build_dir" -G "Unix Makefiles" \
    -DCMAKE_SYSTEM_NAME=Darwin \
    -DCMAKE_C_COMPILER="$cc" \
    -DCMAKE_CXX_COMPILER="$cxx" \
    -DCMAKE_OSX_SYSROOT="$sdk_root" \
    -DCMAKE_OSX_DEPLOYMENT_TARGET="$deployment" \
    -DCMAKE_OSX_ARCHITECTURES="$arch" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$install_dir" \
    -DZLIB_ROOT="$zlib_root" \
    -DZLIB_LIBRARY="$zlib_root/lib/libz.a" \
    -DZLIB_INCLUDE_DIR="$zlib_root/include" \
    -DOPENSSL_ROOT_DIR="$openssl_root" \
    -DOPENSSL_USE_STATIC_LIBS=TRUE \
    -DOPENSSL_SSL_LIBRARY="$openssl_root/lib/libssl.a" \
    -DOPENSSL_CRYPTO_LIBRARY="$openssl_root/lib/libcrypto.a" \
    -DOPENSSL_INCLUDE_DIR="$openssl_root/include" \
    -DTD_ENABLE_DOTNET=OFF \
    -DTD_ENABLE_JNI=OFF \
    -DTD_ENABLE_LTO=OFF \
    -DTD_ENABLE_TESTS=OFF

  cmake --build "$build_dir" --target tdjson -- -j"${TELEGRAM_PPC_JOBS:-2}"
  cmake --install "$build_dir"
}

build_one ppc ppc "$TELEGRAM_PPC_PPC_CC" "$TELEGRAM_PPC_PPC_CXX" "$TELEGRAM_PPC_SDK_ROOT" 10.4
build_one i386 i386 "$TELEGRAM_PPC_I386_CC" "$TELEGRAM_PPC_I386_CXX" "$TELEGRAM_PPC_SDK_ROOT" 10.4
build_one x86_64 x86_64 "$TELEGRAM_PPC_X86_64_CC" "$TELEGRAM_PPC_X86_64_CXX" "$TELEGRAM_PPC_SDK_ROOT" 10.5
build_one arm64 arm64 "$TELEGRAM_PPC_ARM64_CC" "$TELEGRAM_PPC_ARM64_CXX" "$TELEGRAM_PPC_ARM64_SDK_ROOT" 11.0

{
  echo "TELEGRAM_PPC_PPC_TDLIB_LIBRARY=$TELEGRAM_PPC_CI_ROOT/deps/ppc/tdlib/lib/libtdjson.dylib"
  echo "TELEGRAM_PPC_I386_TDLIB_LIBRARY=$TELEGRAM_PPC_CI_ROOT/deps/i386/tdlib/lib/libtdjson.dylib"
  echo "TELEGRAM_PPC_X86_64_TDLIB_LIBRARY=$TELEGRAM_PPC_CI_ROOT/deps/x86_64/tdlib/lib/libtdjson.dylib"
  echo "TELEGRAM_PPC_ARM64_TDLIB_LIBRARY=$TELEGRAM_PPC_CI_ROOT/deps/arm64/tdlib/lib/libtdjson.dylib"
} >> "$GITHUB_ENV"
