#!/usr/bin/env bash
set -euo pipefail

: "${TELEGRAM_PPC_CI_ROOT:?TELEGRAM_PPC_CI_ROOT is required}"
: "${TELEGRAM_PPC_GCC14_REV:=gcc-14-2-darwin}"

src_root="$TELEGRAM_PPC_CI_ROOT/src"
gcc_src="$src_root/gcc-14-branch"
gcc_build_root="$TELEGRAM_PPC_CI_ROOT/build"
bin_dir="$TELEGRAM_PPC_CI_ROOT/bin"

mkdir -p "$src_root" "$gcc_build_root" "$bin_dir"

if [ ! -d "$gcc_src/.git" ]; then
  git clone --depth 1 --branch "$TELEGRAM_PPC_GCC14_REV" https://github.com/iains/gcc-14-branch.git "$gcc_src"
fi

if [ ! -d "$gcc_src/gmp" ]; then
  (
    cd "$gcc_src"
    ./contrib/download_prerequisites
  )
fi

export PATH="$bin_dir:$PATH"

build_one() {
  local target=$1
  local as_path=$2
  local ld_path=$3
  local prefix="$TELEGRAM_PPC_CI_ROOT/gcc/$target"
  local build_dir="$gcc_build_root/gcc-$target"

  if [ -x "$prefix/bin/$target-g++" ]; then
    return
  fi

  if [ ! -x "$as_path" ]; then
    echo "Assembler for $target is not executable: $as_path" >&2
    exit 1
  fi
  if [ ! -x "$ld_path" ]; then
    echo "Linker for $target is not executable: $ld_path" >&2
    exit 1
  fi

  mkdir -p "$prefix" "$build_dir"
  (
    cd "$build_dir"
    "$gcc_src/configure" \
      --target="$target" \
      --prefix="$prefix" \
      --with-sysroot="$TELEGRAM_PPC_SDK_ROOT" \
      --enable-languages=c,c++,objc,obj-c++ \
      --disable-multilib \
      --disable-nls \
      --disable-libstdcxx-pch \
      --disable-libgomp \
      --disable-libssp \
      --disable-libquadmath \
      --enable-checking=release \
      --without-isl \
      --with-system-zlib \
      --with-as="$as_path" \
      --with-ld="$ld_path"
    make -j"${TELEGRAM_PPC_JOBS:-2}" all-gcc all-target-libgcc
    ln -sf /bin/true "$build_dir/gcc/dsymutil"
    make -j"${TELEGRAM_PPC_JOBS:-2}"
    make install
  )
}

build_one powerpc-apple-darwin9 "$TELEGRAM_PPC_PPC_AS" "$TELEGRAM_PPC_PPC_LD"
build_one i686-apple-darwin9 "$TELEGRAM_PPC_I386_AS" "$TELEGRAM_PPC_I386_LD"
build_one x86_64-apple-darwin9 "$TELEGRAM_PPC_X86_64_AS" "$TELEGRAM_PPC_X86_64_LD"

ln -sf "$TELEGRAM_PPC_CI_ROOT/gcc/powerpc-apple-darwin9/bin/powerpc-apple-darwin9-gcc" "$bin_dir/powerpc-apple-darwin9-gcc"
ln -sf "$TELEGRAM_PPC_CI_ROOT/gcc/powerpc-apple-darwin9/bin/powerpc-apple-darwin9-g++" "$bin_dir/powerpc-apple-darwin9-g++"
ln -sf "$TELEGRAM_PPC_CI_ROOT/gcc/i686-apple-darwin9/bin/i686-apple-darwin9-gcc" "$bin_dir/i686-apple-darwin9-gcc"
ln -sf "$TELEGRAM_PPC_CI_ROOT/gcc/i686-apple-darwin9/bin/i686-apple-darwin9-g++" "$bin_dir/i686-apple-darwin9-g++"
ln -sf "$TELEGRAM_PPC_CI_ROOT/gcc/x86_64-apple-darwin9/bin/x86_64-apple-darwin9-gcc" "$bin_dir/x86_64-apple-darwin9-gcc"
ln -sf "$TELEGRAM_PPC_CI_ROOT/gcc/x86_64-apple-darwin9/bin/x86_64-apple-darwin9-g++" "$bin_dir/x86_64-apple-darwin9-g++"

{
  echo "TELEGRAM_PPC_PPC_CC=$bin_dir/powerpc-apple-darwin9-gcc"
  echo "TELEGRAM_PPC_PPC_CXX=$bin_dir/powerpc-apple-darwin9-g++"
  echo "TELEGRAM_PPC_I386_CC=$bin_dir/i686-apple-darwin9-gcc"
  echo "TELEGRAM_PPC_I386_CXX=$bin_dir/i686-apple-darwin9-g++"
  echo "TELEGRAM_PPC_X86_64_CC=$bin_dir/x86_64-apple-darwin9-gcc"
  echo "TELEGRAM_PPC_X86_64_CXX=$bin_dir/x86_64-apple-darwin9-g++"
} >> "$GITHUB_ENV"
