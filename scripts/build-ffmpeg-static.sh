#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: scripts/build-ffmpeg-static.sh [--config PATH] [--arch ppc|i386|x86_64|all] [--source PATH] [--clean]

Build lean static FFmpeg libraries for the TelegramPPC universal build.
The output prefixes are the TELEGRAM_PPC_<ARCH>_STATIC_FFMPEG_ROOT values from local-build-config.sh.
USAGE
}

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
config="$repo_root/local-build-config.sh"
arch=all
source_dir_arg=""
clean=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --config) config="$2"; shift 2 ;;
    --arch) arch="$2"; shift 2 ;;
    --source) source_dir_arg="$2"; shift 2 ;;
    --clean) clean=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

if [ ! -f "$config" ]; then
  echo "missing config: $config" >&2
  exit 1
fi

# shellcheck source=/dev/null
. "$config"

source_dir="${source_dir_arg:-${TELEGRAM_PPC_FFMPEG_SOURCE:-}}"

if [ -z "$source_dir" ]; then
  echo "set TELEGRAM_PPC_FFMPEG_SOURCE or pass --source" >&2
  exit 1
fi

if [ ! -x "$source_dir/configure" ]; then
  echo "FFmpeg configure script not found: $source_dir/configure" >&2
  exit 1
fi

tool_or_empty() {
  local path=$1
  if [ -x "$path" ]; then
    printf '%s\n' "$path"
  fi
}

arch_var_prefix() {
  case "$1" in
    ppc) printf '%s\n' TELEGRAM_PPC_PPC ;;
    i386) printf '%s\n' TELEGRAM_PPC_I386 ;;
    x86_64) printf '%s\n' TELEGRAM_PPC_X86_64 ;;
    *) echo "unknown architecture: $1" >&2; exit 2 ;;
  esac
}

build_one() {
  local name=$1 target_os=$2 arch_name=$3 cpu=$4 cc=$5 prefix=$6 deployment=$7 extra_cflags=$8 extra_ldflags=$9
  local build_dir="$TELEGRAM_PPC_BUILD_ROOT/ffmpeg-static-$name"
  local tool_prefix="${cc%gcc}"
  local darwin_tools_dir
  darwin_tools_dir="$(dirname "$TELEGRAM_PPC_LIPO")"
  local darwin_tool_arch=$name
  local variable_prefix
  variable_prefix="$(arch_var_prefix "$name")"
  local ar_var="${variable_prefix}_STATIC_FFMPEG_AR"
  local ranlib_var="${variable_prefix}_STATIC_FFMPEG_RANLIB"
  local strip_var="${variable_prefix}_STATIC_FFMPEG_STRIP"
  if [ "$darwin_tool_arch" = i386 ]; then
    darwin_tool_arch=i386
  fi
  local ar="${!ar_var:-$(tool_or_empty "${tool_prefix}ar")}"
  local ranlib="${!ranlib_var:-$(tool_or_empty "${tool_prefix}ranlib")}"
  local strip="${!strip_var:-$(tool_or_empty "${tool_prefix}strip")}"

  if [ -z "$ar" ]; then
    ar="$(tool_or_empty "$darwin_tools_dir/$darwin_tool_arch-apple-darwin9-ar")"
  fi
  if [ -z "$ranlib" ]; then
    ranlib="$(tool_or_empty "$darwin_tools_dir/$darwin_tool_arch-apple-darwin9-ranlib")"
  fi
  if [ -z "$strip" ]; then
    strip="$(tool_or_empty "$darwin_tools_dir/$darwin_tool_arch-apple-darwin9-strip")"
  fi

  if [ -z "$ar" ] || [ -z "$ranlib" ]; then
    echo "missing Darwin archive tools for $name" >&2
    exit 1
  fi

  if [ "$clean" -eq 1 ]; then
    rm -rf "$build_dir" "$prefix"
  fi
  mkdir -p "$build_dir" "$prefix"

  (
    cd "$build_dir"
    "$source_dir/configure" \
      --prefix="$prefix" \
      --target-os="$target_os" \
      --arch="$arch_name" \
      --cpu="$cpu" \
      --cc="$cc" \
      --ar="$ar" \
      --ranlib="$ranlib" \
      ${strip:+--strip="$strip"} \
      --sysroot="$TELEGRAM_PPC_SDK_ROOT" \
      --enable-cross-compile \
      --disable-programs \
      --disable-doc \
      --disable-debug \
      --disable-everything \
      --enable-avcodec \
      --enable-avformat \
      --enable-avutil \
      --enable-swscale \
      --disable-avdevice \
      --disable-avfilter \
      --disable-swresample \
      --enable-protocol=file \
      --enable-protocol=pipe \
      --enable-protocol=data \
      --enable-demuxer=aac \
      --enable-demuxer=apng \
      --enable-demuxer=avi \
      --enable-demuxer=flac \
      --enable-demuxer=flv \
      --enable-demuxer=gif \
      --enable-demuxer=h264 \
      --enable-demuxer=hevc \
      --enable-demuxer=image2 \
      --enable-demuxer=image2pipe \
      --enable-demuxer=matroska \
      --enable-demuxer=mov \
      --enable-demuxer=mp3 \
      --enable-demuxer=mpegts \
      --enable-demuxer=mpegvideo \
      --enable-demuxer=ogg \
      --enable-demuxer=wav \
      --enable-decoder=aac \
      --enable-decoder=aac_fixed \
      --enable-decoder=alac \
      --enable-decoder=apng \
      --enable-decoder=av1 \
      --enable-decoder=flac \
      --enable-decoder=gif \
      --enable-decoder=h264 \
      --enable-decoder=hevc \
      --enable-decoder=mjpeg \
      --enable-decoder=mp1 \
      --enable-decoder=mp1float \
      --enable-decoder=mp2 \
      --enable-decoder=mp2float \
      --enable-decoder=mp3 \
      --enable-decoder=mp3float \
      --enable-decoder=mpeg1video \
      --enable-decoder=mpeg2video \
      --enable-decoder=mpeg4 \
      --enable-decoder=opus \
      --enable-decoder=pcm_s16be \
      --enable-decoder=pcm_s16le \
      --enable-decoder=pcm_s24be \
      --enable-decoder=pcm_s24le \
      --enable-decoder=pcm_s32be \
      --enable-decoder=pcm_s32le \
      --enable-decoder=png \
      --enable-decoder=vorbis \
      --enable-decoder=vp8 \
      --enable-decoder=vp9 \
      --enable-decoder=webp \
      --enable-parser=aac \
      --enable-parser=aac_latm \
      --enable-parser=av1 \
      --enable-parser=flac \
      --enable-parser=h264 \
      --enable-parser=hevc \
      --enable-parser=mjpeg \
      --enable-parser=mpegaudio \
      --enable-parser=mpeg4video \
      --enable-parser=mpegvideo \
      --enable-parser=opus \
      --enable-parser=png \
      --enable-parser=vorbis \
      --enable-parser=vp8 \
      --enable-parser=vp9 \
      --enable-bsf=aac_adtstoasc \
      --enable-bsf=av1_frame_split \
      --enable-bsf=h264_mp4toannexb \
      --enable-bsf=hevc_mp4toannexb \
      --disable-shared \
      --enable-static \
      --pkg-config=false \
      --disable-autodetect \
      --disable-network \
      --enable-pthreads \
      --disable-iconv \
      --disable-asm \
      --disable-xlib \
      --disable-securetransport \
      --disable-videotoolbox \
      --disable-audiotoolbox \
      --extra-cflags="-mmacosx-version-min=$deployment -Dstatic_assert=_Static_assert $extra_cflags" \
      --extra-ldflags="-mmacosx-version-min=$deployment $extra_ldflags"
    make -j"${TELEGRAM_PPC_JOBS:-2}"
    make install
  )
}

case "$arch" in
  ppc|i386|x86_64|all) ;;
  *) echo "unknown architecture: $arch" >&2; exit 2 ;;
esac

if [ "$arch" = ppc ] || [ "$arch" = all ]; then
  build_one ppc darwin ppc powerpc "$TELEGRAM_PPC_PPC_CC" "${TELEGRAM_PPC_PPC_STATIC_FFMPEG_ROOT:-$TELEGRAM_PPC_PPC_FFMPEG_ROOT}" 10.4 "${TELEGRAM_PPC_PPC_STATIC_FFMPEG_EXTRA_CFLAGS:-}" "${TELEGRAM_PPC_PPC_STATIC_FFMPEG_EXTRA_LDFLAGS:-}"
fi

if [ "$arch" = i386 ] || [ "$arch" = all ]; then
  build_one i386 darwin x86 i686 "$TELEGRAM_PPC_I386_CC" "${TELEGRAM_PPC_I386_STATIC_FFMPEG_ROOT:-$TELEGRAM_PPC_I386_FFMPEG_ROOT}" 10.4 "${TELEGRAM_PPC_I386_STATIC_FFMPEG_EXTRA_CFLAGS:-}" "${TELEGRAM_PPC_I386_STATIC_FFMPEG_EXTRA_LDFLAGS:-}"
fi

if [ "$arch" = x86_64 ] || [ "$arch" = all ]; then
  build_one x86_64 darwin x86_64 x86-64 "$TELEGRAM_PPC_X86_64_CC" "${TELEGRAM_PPC_X86_64_STATIC_FFMPEG_ROOT:-$TELEGRAM_PPC_X86_64_FFMPEG_ROOT}" 10.5 "${TELEGRAM_PPC_X86_64_STATIC_FFMPEG_EXTRA_CFLAGS:-}" "${TELEGRAM_PPC_X86_64_STATIC_FFMPEG_EXTRA_LDFLAGS:-}"
fi
