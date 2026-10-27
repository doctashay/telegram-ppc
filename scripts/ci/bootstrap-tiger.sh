#!/usr/bin/env bash
set -euo pipefail

arch=${1:?Usage: bootstrap-tiger.sh ppc|i386 OUTPUT_DIRECTORY}
tiger_root=${2:?An output directory is required}
repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
case "$arch" in
  ppc) triple=powerpc-apple-darwin9; openssl_target=darwin-ppc-cc; cpu_flags='-mcpu=powerpc -mno-altivec' ;;
  i386) triple=i686-apple-darwin9; openssl_target=darwin-i386-cc; cpu_flags='-msse2 -mfpmath=sse' ;;
  *) echo "unsupported Tiger architecture: $arch" >&2; exit 2 ;;
esac
mkdir -p "$tiger_root"
tiger_root=$(cd "$tiger_root" && pwd)
upper=$(printf '%s' "$arch" | tr '[:lower:]' '[:upper:]')
prefix="TELEGRAM_PPC_$upper"
signature=$(cat "$repo_root/scripts/ci/bootstrap-tiger.sh" \
  "$repo_root/scripts/ci/fetch-tiger-sources.py" "$repo_root/scripts/ci/patches/"*.diff \
  "$repo_root/scripts/build-ffmpeg-static.sh" | sha256sum | cut -d' ' -f1)
if [ -f "$tiger_root/build-id" ] && [ "$(cat "$tiger_root/build-id")" != "$signature" ]; then
  echo "Tiger build inputs changed; use a fresh output directory: $tiger_root" >&2
  exit 1
fi

write_environment() {
  local startup_flags=
  if [ "$arch" = ppc ]; then
    startup_flags=" -DCMAKE_EXE_LINKER_FLAGS=-L$tiger_root/deps/startfiles"
  fi
  {
    printf 'export TELEGRAM_PPC_SDK_ROOT=%q\n' "$tiger_root/src/MacOSX10.4u.sdk"
    printf 'export %s_FFMPEG_ROOT=%q\n' "$prefix" "$tiger_root/deps/ffmpeg"
    printf 'export %s_CURL_ROOT=%q\n' "$prefix" "$tiger_root/deps/curl"
    printf 'export %s_OPENSSL_ROOT=%q\n' "$prefix" "$tiger_root/deps/openssl"
    printf 'export %s_ZLIB_ROOT=%q\n' "$prefix" "$tiger_root/deps/zlib"
    printf 'export %s_TDLIB_LIBRARY=%q\n' "$prefix" "$tiger_root/deps/tdlib/lib/libtdjson.dylib"
    printf 'export %s_BUNDLE_LIBS=""\n' "$prefix"
    printf 'export TELEGRAM_PPC_CMAKE_ARGS=%q\n' "${TELEGRAM_PPC_CMAKE_ARGS:-} -DTELEGRAM_PPC_STATIC_CXX_RUNTIME_ROOT=$tiger_root/deps/runtime$startup_flags"
  } > "$tiger_root/environment.sh"
}

if [ -f "$tiger_root/complete" ] && [ -f "$tiger_root/deps/tdlib/lib/libtdjson.dylib" ]; then
  write_environment
  exit 0
fi
command -v patch >/dev/null
command -v gperf >/dev/null
printf '%s\n' "$signature" > "$tiger_root/build-id"
mkdir -p "$tiger_root/build" "$tiger_root/deps"
python3 "$repo_root/scripts/ci/fetch-tiger-sources.py" "$tiger_root"

# shellcheck source=/dev/null
. /opt/darwin-legacy-cross/bin/darwin-legacy-cross-env
export DARWIN_LEGACY_SDK_ROOT="$tiger_root/src/MacOSX10.4u.sdk"
export TELEGRAM_PPC_SDK_ROOT="$DARWIN_LEGACY_SDK_ROOT"
cc_var="DARWIN_${upper}_CC"
cxx_var="DARWIN_${upper}_CXX"
export CC="${!cc_var}" CXX="${!cxx_var}"
tool_arch=$arch
[ "$arch" != ppc ] || tool_arch=powerpc
export AR="$DARWIN_CCTOOLS_ROOT/bin/$tool_arch-apple-darwin9-ar"
export RANLIB="$DARWIN_CCTOOLS_ROOT/bin/$tool_arch-apple-darwin9-ranlib"
export CFLAGS="-O2 -isysroot $DARWIN_LEGACY_SDK_ROOT -mmacosx-version-min=10.4 -D__DARWIN_UNIX03=0 -D_DARWIN_NO_64_BIT_INODE=1 $cpu_flags"
export CXXFLAGS="$CFLAGS"
export LDFLAGS="-isysroot $DARWIN_LEGACY_SDK_ROOT -mmacosx-version-min=10.4 -static-libgcc"
jobs=${TELEGRAM_PPC_JOBS:-2}
gcc_source="$tiger_root/src/gcc-14-branch-gcc-14.2-darwin-r2"

if [ "$arch" = ppc ]; then
  mkdir -p "$tiger_root/deps/startfiles"
  if [ ! -f "$tiger_root/deps/startfiles/crt1.o" ]; then
    csu="$tiger_root/src/Csu-Csu-58"
    for source in start.s crt.c dyld.s; do
      language=c
      [[ "$source" != *.s ]] || language=assembler-with-cpp
      # shellcheck disable=SC2086
      "$CC" $CFLAGS -Os -dynamic -DCRT1 '-D__private_extern__=__attribute__((visibility("hidden")))' \
        -x "$language" -c "$csu/$source" -o "$tiger_root/deps/startfiles/$source.o"
    done
    "$CC" -mmacosx-version-min=10.4 -r -nostdlib -Wl,-keep_private_externs \
      "$tiger_root/deps/startfiles/"{start.s,crt.c,dyld.s}.o -o "$tiger_root/deps/startfiles/crt1.o"
  fi
  export LDFLAGS="$LDFLAGS -L$tiger_root/deps/startfiles"
fi

if [ ! -f "$tiger_root/deps/runtime/lib/libstdc++.a" ]; then
  echo "Building Tiger $arch C++ runtime"
  mkdir -p "$tiger_root/build/runtime" "$tiger_root/build/libgcc"
  ln -sf "$gcc_source/libgcc/gthr-posix.h" "$tiger_root/build/libgcc/gthr-default.h"
  (
    cd "$tiger_root/build/runtime"
    "$gcc_source/libstdc++-v3/configure" --build=x86_64-pc-linux-gnu --host="$triple" --target="$triple" \
      --prefix="$tiger_root/deps/runtime" --disable-shared --enable-static --with-pic --disable-multilib \
      --disable-nls --disable-libstdcxx-pch --enable-libstdcxx-threads
    make -j"$jobs"
    make install
  ) > "$tiger_root/build/runtime.log" 2>&1
fi

if [ ! -f "$tiger_root/deps/zlib/lib/libz.a" ]; then
  echo "Building Tiger $arch zlib"
  (
    cd "$tiger_root/src/zlib-1.3.1"
    ./configure --static --prefix="$tiger_root/deps/zlib"
    make -j"$jobs"
    make install
  ) > "$tiger_root/build/zlib.log" 2>&1
fi
if [ ! -f "$tiger_root/deps/openssl/lib/libssl.a" ]; then
  echo "Building Tiger $arch OpenSSL"
  (
    cd "$tiger_root/src/openssl-1.1.1w"
    # OpenSSL's Configure expects individual compiler arguments.
    # shellcheck disable=SC2086
    ./Configure "$openssl_target" no-shared no-tests no-async --prefix="$tiger_root/deps/openssl" \
      --openssldir="$tiger_root/deps/openssl/ssl" -DOPENSSL_NO_APPLE_CRYPTO_RANDOM $CFLAGS
    make -j"$jobs"
    make install_sw
  ) > "$tiger_root/build/openssl.log" 2>&1
fi
if [ ! -f "$tiger_root/deps/curl/lib/libcurl.a" ]; then
  echo "Building Tiger $arch curl"
  (
    cd "$tiger_root/src/curl-8.13.0"
    ./configure --host="$triple" --prefix="$tiger_root/deps/curl" --disable-shared --enable-static \
      --with-openssl="$tiger_root/deps/openssl" --with-zlib="$tiger_root/deps/zlib" \
      --without-libpsl --without-libidn2 --without-brotli --without-zstd --without-nghttp2 \
      --disable-ldap --disable-ldaps --disable-rtsp --disable-dict --disable-telnet --disable-tftp \
      --disable-pop3 --disable-imap --disable-smtp --disable-gopher --disable-smb --without-secure-transport
    make -j"$jobs"
    make install
  ) > "$tiger_root/build/curl.log" 2>&1
fi
if [ ! -f "$tiger_root/deps/ffmpeg/lib/libavcodec.a" ]; then
  echo "Building Tiger $arch FFmpeg"
  (
    # shellcheck source=/dev/null
    . "$repo_root/scripts/ci/use-darwin-legacy-cross-env.sh"
    export TELEGRAM_PPC_BUILD_ROOT="$tiger_root/build"
    export TELEGRAM_PPC_FFMPEG_SOURCE="$tiger_root/src/ffmpeg-8.0"
    export TELEGRAM_PPC_FFMPEG_HOST_CC='/usr/bin/gcc -B/usr/bin/'
    export "${prefix}_STATIC_FFMPEG_ROOT=$tiger_root/deps/ffmpeg"
    export "${prefix}_STATIC_FFMPEG_EXTRA_CFLAGS=-D__DARWIN_UNIX03=0 -D_DARWIN_NO_64_BIT_INODE=1 $cpu_flags"
    bash "$repo_root/scripts/ci/write-build-config.sh" "$tiger_root/build/ffmpeg-config.sh"
    {
      printf 'export TELEGRAM_PPC_FFMPEG_SOURCE=%q\n' "$TELEGRAM_PPC_FFMPEG_SOURCE"
      printf 'export TELEGRAM_PPC_FFMPEG_HOST_CC=%q\n' "$TELEGRAM_PPC_FFMPEG_HOST_CC"
      printf 'export %s_STATIC_FFMPEG_ROOT=%q\n' "$prefix" "$tiger_root/deps/ffmpeg"
      printf 'export %s_STATIC_FFMPEG_EXTRA_CFLAGS=%q\n' "$prefix" "-D__DARWIN_UNIX03=0 -D_DARWIN_NO_64_BIT_INODE=1 $cpu_flags"
      printf 'export %s_STATIC_FFMPEG_EXTRA_LDFLAGS=%q\n' "$prefix" "$LDFLAGS"
    } >> "$tiger_root/build/ffmpeg-config.sh"
    bash "$repo_root/scripts/build-ffmpeg-static.sh" --config "$tiger_root/build/ffmpeg-config.sh" --arch "$arch"
  ) > "$tiger_root/build/ffmpeg.log" 2>&1
fi

td_source="$tiger_root/src/td-a8f21f5230172634becc1739050ef23ecd6ea291"
if [ ! -f "$td_source/.patched" ]; then
  if [ "$arch" = ppc ]; then
    patch -d "$td_source" -p0 < "$repo_root/scripts/ci/patches/tdlib-ppc-bigendian.diff"
  fi
  patch -d "$td_source" -p0 < "$repo_root/scripts/ci/patches/tdlib-legacy-darwin-clocks.diff"
  touch "$td_source/.patched"
fi
if [ ! -f "$td_source/.generated" ]; then
  echo 'Generating TDLib sources'
  native_env=(env CC=/usr/bin/gcc CXX=/usr/bin/g++ CFLAGS= CXXFLAGS= LDFLAGS= PATH=/usr/bin:/bin)
  {
    "${native_env[@]}" cmake -S "$td_source" -B "$tiger_root/build/td-native" -DTD_GENERATE_SOURCE_FILES=ON -DCMAKE_BUILD_TYPE=Release
    "${native_env[@]}" cmake --build "$tiger_root/build/td-native" --target prepare_cross_compiling -- -j"$jobs"
  } > "$tiger_root/build/td-native.log" 2>&1
  touch "$td_source/.generated"
fi
echo "Building Tiger $arch TDLib"
link_flags="$LDFLAGS -B$tiger_root/deps/runtime/lib/ -static-libstdc++ -static-libgcc"
cmake -S "$td_source" -B "$tiger_root/build/td" -DCMAKE_SYSTEM_NAME=Darwin \
  -DCMAKE_C_COMPILER="$CC" -DCMAKE_CXX_COMPILER="$CXX" \
  -DCMAKE_OSX_SYSROOT="$DARWIN_LEGACY_SDK_ROOT" -DCMAKE_OSX_DEPLOYMENT_TARGET=10.4 \
  -DCMAKE_OSX_ARCHITECTURES="$arch" -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_C_FLAGS="$CFLAGS" -DCMAKE_CXX_FLAGS="$CXXFLAGS" \
  -DCMAKE_SHARED_LINKER_FLAGS="$link_flags" -DCMAKE_EXE_LINKER_FLAGS="$link_flags" \
  -DZLIB_LIBRARY="$tiger_root/deps/zlib/lib/libz.a" -DZLIB_INCLUDE_DIR="$tiger_root/deps/zlib/include" \
  -DOPENSSL_SSL_LIBRARY="$tiger_root/deps/openssl/lib/libssl.a" \
  -DOPENSSL_CRYPTO_LIBRARY="$tiger_root/deps/openssl/lib/libcrypto.a" \
  -DOPENSSL_INCLUDE_DIR="$tiger_root/deps/openssl/include" -DOPENSSL_USE_STATIC_LIBS=TRUE \
  -DATOMICS_FOUND=TRUE -DATOMICS_LIBRARIES="$DARWIN_LEGACY_CROSS_DEPS_ROOT/libatomic-$arch/lib/libatomic.a" \
  -DTD_ENABLE_LTO=OFF -DTD_ENABLE_JNI=OFF -DTD_ENABLE_DOTNET=OFF > "$tiger_root/build/td-configure.log" 2>&1
cmake --build "$tiger_root/build/td" --target tdjson -- -j"$jobs" > "$tiger_root/build/td.log" 2>&1
mkdir -p "$tiger_root/deps/tdlib/lib"
cp -L "$tiger_root/build/td/libtdjson.dylib" "$tiger_root/deps/tdlib/lib/libtdjson.dylib"
write_environment
touch "$tiger_root/complete"
echo "Tiger $arch dependencies ready: $tiger_root/environment.sh"
