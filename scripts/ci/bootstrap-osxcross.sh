#!/usr/bin/env bash
set -euo pipefail

: "${TELEGRAM_PPC_CI_ROOT:?TELEGRAM_PPC_CI_ROOT is required}"
: "${TELEGRAM_PPC_OSXCROSS_REV:=osxcross-1.1}"
: "${TELEGRAM_PPC_SDK_URL:=https://github.com/phracker/MacOSX-SDKs/releases/download/11.3/MacOSX10.5.sdk.tar.xz}"

src_root="${TELEGRAM_PPC_CI_ROOT}/src"
osxcross_src="${src_root}/osxcross"
target_root="${TELEGRAM_PPC_CI_ROOT}/osxcross-target"
sdk_dir="${target_root}/SDK/MacOSX10.5.sdk"
bin_dir="${TELEGRAM_PPC_CI_ROOT}/bin"

mkdir -p "$src_root" "$bin_dir"

if [ ! -d "$osxcross_src/.git" ]; then
  git clone --depth 1 --branch "$TELEGRAM_PPC_OSXCROSS_REV" https://github.com/tpoechtrager/osxcross.git "$osxcross_src"
fi

mkdir -p "$osxcross_src/tarballs"
if [ ! -f "$osxcross_src/tarballs/MacOSX10.5.sdk.tar.xz" ]; then
  curl -fsSL "$TELEGRAM_PPC_SDK_URL" -o "$osxcross_src/tarballs/MacOSX10.5.sdk.tar.xz"
fi

if [ ! -x "$target_root/bin/lipo" ]; then
  (
    cd "$osxcross_src"
    export TARGET_DIR="$target_root"
    export UNATTENDED=1
    export OSX_VERSION_MIN=10.4
    ./build.sh
  )
fi

if [ ! -d "$sdk_dir" ]; then
  echo "osxcross did not install expected SDK: $sdk_dir" >&2
  exit 1
fi

ln -sf "$target_root/bin/lipo" "$bin_dir/lipo"
ln -sf "$target_root/bin/lipo" "$bin_dir/powerpc-apple-darwin9-lipo"
ln -sf "$target_root/bin/lipo" "$bin_dir/i686-apple-darwin9-lipo"
ln -sf "$target_root/bin/lipo" "$bin_dir/x86_64-apple-darwin9-lipo"

install_name_tool="$(find "$target_root/bin" -maxdepth 1 -type f -name '*install_name_tool' | head -n 1)"
otool="$(find "$target_root/bin" -maxdepth 1 -type f -name '*otool' | head -n 1)"

if [ -z "$install_name_tool" ] || [ -z "$otool" ]; then
  echo "osxcross did not produce install_name_tool/otool" >&2
  exit 1
fi

ln -sf "$install_name_tool" "$bin_dir/install_name_tool"
ln -sf "$otool" "$bin_dir/otool"

link_tool() {
  local output=$1 input=$2
  if [ ! -x "$target_root/bin/$input" ]; then
    echo "missing osxcross tool: $target_root/bin/$input" >&2
    exit 1
  fi
  ln -sf "$target_root/bin/$input" "$bin_dir/$output"
}

link_tool powerpc-apple-darwin9-as x86_64-apple-darwin9-as
link_tool powerpc-apple-darwin9-ar x86_64-apple-darwin9-ar
link_tool powerpc-apple-darwin9-dsymutil x86_64-apple-darwin9-dsymutil
link_tool powerpc-apple-darwin9-libtool x86_64-apple-darwin9-libtool
link_tool powerpc-apple-darwin9-nm x86_64-apple-darwin9-nm
link_tool powerpc-apple-darwin9-nmedit x86_64-apple-darwin9-nmedit
link_tool powerpc-apple-darwin9-otool x86_64-apple-darwin9-otool
link_tool powerpc-apple-darwin9-ranlib x86_64-apple-darwin9-ranlib
link_tool powerpc-apple-darwin9-strip x86_64-apple-darwin9-strip
link_tool i686-apple-darwin9-as i386-apple-darwin9-as
link_tool i686-apple-darwin9-ld i386-apple-darwin9-ld
link_tool i686-apple-darwin9-ar i386-apple-darwin9-ar
link_tool i686-apple-darwin9-dsymutil i386-apple-darwin9-dsymutil
link_tool i686-apple-darwin9-libtool i386-apple-darwin9-libtool
link_tool i686-apple-darwin9-nm i386-apple-darwin9-nm
link_tool i686-apple-darwin9-nmedit i386-apple-darwin9-nmedit
link_tool i686-apple-darwin9-otool i386-apple-darwin9-otool
link_tool i686-apple-darwin9-ranlib i386-apple-darwin9-ranlib
link_tool i686-apple-darwin9-strip i386-apple-darwin9-strip
link_tool x86_64-apple-darwin9-as x86_64-apple-darwin9-as
link_tool x86_64-apple-darwin9-ld x86_64-apple-darwin9-ld
link_tool x86_64-apple-darwin9-ar x86_64-apple-darwin9-ar
link_tool x86_64-apple-darwin9-dsymutil x86_64-apple-darwin9-dsymutil
link_tool x86_64-apple-darwin9-libtool x86_64-apple-darwin9-libtool
link_tool x86_64-apple-darwin9-nm x86_64-apple-darwin9-nm
link_tool x86_64-apple-darwin9-nmedit x86_64-apple-darwin9-nmedit
link_tool x86_64-apple-darwin9-otool x86_64-apple-darwin9-otool
link_tool x86_64-apple-darwin9-ranlib x86_64-apple-darwin9-ranlib
link_tool x86_64-apple-darwin9-strip x86_64-apple-darwin9-strip

{
  echo "TELEGRAM_PPC_SDK_ROOT=$sdk_dir"
  echo "TELEGRAM_PPC_INSTALL_NAME_TOOL=$bin_dir/install_name_tool"
  echo "TELEGRAM_PPC_OTOOL=$bin_dir/otool"
  echo "TELEGRAM_PPC_LIPO=$bin_dir/lipo"
  echo "TELEGRAM_PPC_PPC_AS=$bin_dir/powerpc-apple-darwin9-as"
  echo "TELEGRAM_PPC_I386_AS=$bin_dir/i686-apple-darwin9-as"
  echo "TELEGRAM_PPC_I386_LD=$bin_dir/i686-apple-darwin9-ld"
  echo "TELEGRAM_PPC_X86_64_AS=$bin_dir/x86_64-apple-darwin9-as"
  echo "TELEGRAM_PPC_X86_64_LD=$bin_dir/x86_64-apple-darwin9-ld"
} >> "$GITHUB_ENV"
