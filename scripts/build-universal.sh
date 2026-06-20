#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: scripts/build-universal.sh [--config PATH] [--clean] [--skip-build]

Build ppc, i386, and x86_64 thin apps, then assemble dist/TelegramPPC.app.
Machine-specific paths come from local-build-config.sh.
USAGE
}

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
config="$repo_root/local-build-config.sh"
clean=0
skip_build=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --config) config="$2"; shift 2 ;;
    --clean) clean=1; shift ;;
    --skip-build) skip_build=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

if [ ! -f "$config" ]; then
  echo "missing config: $config" >&2
  echo "copy scripts/build-config.example.sh to local-build-config.sh and fill in paths" >&2
  exit 1
fi

# shellcheck source=/dev/null
. "$config"

require_var() {
  local name=$1
  local value="${!name:-}"
  if [ -z "$value" ]; then
    echo "required config variable is empty: $name" >&2
    exit 1
  fi
}

require_file() {
  local name=$1
  local value
  require_var "$name"
  value="${!name}"
  if [ ! -e "$value" ]; then
    echo "$name does not exist: $value" >&2
    exit 1
  fi
}

join_extra_cmake_args() {
  local prefix=$1
  local bundle_var="${prefix}_BUNDLE_LIBS"
  local extra_var="${prefix}_FFMPEG_EXTRA_LIBS"
  cmake_bundle_libs="${!bundle_var:-}"
  cmake_ffmpeg_extra_libs="${!extra_var:-}"
}

build_slice() {
  local name=$1 arch=$2 compiler=$3 cpu=$4 deployment=$5 ffmpeg_root=$6 tdlib=$7 prefix=$8
  local build_dir="$TELEGRAM_PPC_BUILD_ROOT/build-$name"

  if [ "$clean" -eq 1 ]; then
    rm -rf "$build_dir"
  fi
  mkdir -p "$build_dir"

  if [ "$skip_build" -eq 0 ]; then
    join_extra_cmake_args "$prefix"
    cmake_args=(
      -S "$repo_root"
      -B "$build_dir"
      -G "Unix Makefiles"
      -DCMAKE_SYSTEM_NAME=Darwin \
      -DCMAKE_CXX_COMPILER="$compiler" \
      -DCMAKE_OBJCXX_COMPILER="$compiler" \
      -DCMAKE_OSX_SYSROOT="$TELEGRAM_PPC_SDK_ROOT" \
      -DCMAKE_OSX_DEPLOYMENT_TARGET="$deployment" \
      -DCMAKE_OSX_ARCHITECTURES="$arch" \
      -DCMAKE_BUILD_TYPE=Release \
      -DTELEGRAM_PPC_CPU_TARGET="$cpu" \
      -DTELEGRAM_PPC_DEPENDENCY_ROOTS="${TELEGRAM_PPC_DEPENDENCY_ROOTS:-}" \
      -DTELEGRAM_PPC_MIN_SYSTEM_VERSION=10.4 \
      -DTELEGRAM_PPC_FFMPEG_ROOT="$ffmpeg_root" \
      -DTELEGRAM_PPC_FFMPEG_LINKAGE="$TELEGRAM_PPC_FFMPEG_LINKAGE" \
      -DTELEGRAM_PPC_FFMPEG_EXTRA_LIBS="$cmake_ffmpeg_extra_libs" \
      -DTELEGRAM_PPC_TDLIB_LIBRARY="$tdlib" \
      -DTELEGRAM_PPC_BUNDLE_LIBS="$cmake_bundle_libs" \
      -DTELEGRAM_PPC_INSTALL_NAME_TOOL="$TELEGRAM_PPC_INSTALL_NAME_TOOL"
    )
    if [ -n "${TELEGRAM_PPC_CMAKE_ARGS:-}" ]; then
      # Word splitting is intentional for local one-off CMake overrides.
      cmake_args+=($TELEGRAM_PPC_CMAKE_ARGS)
    fi
    cmake "${cmake_args[@]}"
    cmake --build "$build_dir" -- -j"${TELEGRAM_PPC_JOBS:-2}"
  fi
}

copy_or_lipo() {
  local output=$1
  shift
  if [ "$#" -eq 1 ]; then
    cp -f "$1" "$output"
  else
    "$TELEGRAM_PPC_LIPO" -create "$@" -output "$output"
  fi
}

list_framework_names() {
  local framework_dir=$1
  [ -d "$framework_dir" ] || return 0
  find "$framework_dir" -maxdepth 1 -type f | while read -r framework_file; do
    basename "$framework_file"
  done
}

normalize_bundle() {
  local app=$1
  local fw="$app/Contents/Frameworks"
  local target load name

  find "$fw" -maxdepth 1 -type f -name "*.dylib" | while read -r target; do
    name="$(basename "$target")"
    "$TELEGRAM_PPC_INSTALL_NAME_TOOL" -id "@executable_path/../Frameworks/$name" "$target" 2>/dev/null || true
  done

  {
    printf '%s\n' "$app/Contents/MacOS/TelegramPPC"
    find "$fw" -maxdepth 1 -type f -name "*.dylib"
  } | while read -r target; do
    "$TELEGRAM_PPC_OTOOL" -L "$target" | awk '/^[[:space:]]/ {print $1}' | while read -r load; do
      [ -n "$load" ] || continue
      name="$(basename "$load")"
      [ -e "$fw/$name" ] || continue
      case "$load" in
        @executable_path/*|/System/*|/usr/lib/*) continue ;;
      esac
      "$TELEGRAM_PPC_INSTALL_NAME_TOOL" -change "$load" "@executable_path/../Frameworks/$name" "$target" 2>/dev/null || true
    done
  done
}

verify_bundle() {
  local app=$1
  local forbidden_pattern="${TELEGRAM_PPC_FORBIDDEN_LOAD_PATH_PATTERN:-/opt/local|/home/|/mnt/|/tmp/}"
  local bad_loads

  "$TELEGRAM_PPC_LIPO" "$app/Contents/MacOS/TelegramPPC" -verify_arch ppc i386 x86_64

  bad_loads="$(
    {
      printf '%s\n' "$app/Contents/MacOS/TelegramPPC"
      find "$app/Contents/Frameworks" -maxdepth 1 -type f -name "*.dylib"
    } | while read -r target; do
      "$TELEGRAM_PPC_OTOOL" -L "$target" 2>/dev/null | awk '/^[[:space:]]/ {print $1}' | grep -E "$forbidden_pattern" || true
    done | sort -u
  )"

  if [ -n "$bad_loads" ]; then
    echo "bundle contains non-relocatable load commands:" >&2
    echo "$bad_loads" >&2
    exit 1
  fi
}

assemble_universal() {
  local dist="${TELEGRAM_PPC_DIST_DIR:-$repo_root/dist}"
  local app="$dist/TelegramPPC.app"
  local ppc_app="$TELEGRAM_PPC_BUILD_ROOT/build-ppc/TelegramPPC.app"
  local i386_app="$TELEGRAM_PPC_BUILD_ROOT/build-i386/TelegramPPC.app"
  local x64_app="$TELEGRAM_PPC_BUILD_ROOT/build-x86_64/TelegramPPC.app"

  rm -rf "$app"
  mkdir -p "$dist"
  cp -a "$x64_app" "$app"

  "$TELEGRAM_PPC_LIPO" -create \
    "$ppc_app/Contents/MacOS/TelegramPPC" \
    "$i386_app/Contents/MacOS/TelegramPPC" \
    "$x64_app/Contents/MacOS/TelegramPPC" \
    -output "$app/Contents/MacOS/TelegramPPC"

  {
    list_framework_names "$ppc_app/Contents/Frameworks"
    list_framework_names "$i386_app/Contents/Frameworks"
    list_framework_names "$x64_app/Contents/Frameworks"
  } | sort -u | while read -r name; do
    [ -n "$name" ] || continue
    inputs=()
    [ -e "$ppc_app/Contents/Frameworks/$name" ] && inputs+=("$ppc_app/Contents/Frameworks/$name")
    [ -e "$i386_app/Contents/Frameworks/$name" ] && inputs+=("$i386_app/Contents/Frameworks/$name")
    [ -e "$x64_app/Contents/Frameworks/$name" ] && inputs+=("$x64_app/Contents/Frameworks/$name")
    copy_or_lipo "$app/Contents/Frameworks/$name" "${inputs[@]}"
  done

  normalize_bundle "$app"
  verify_bundle "$app"

  "$TELEGRAM_PPC_LIPO" -info "$app/Contents/MacOS/TelegramPPC"
  echo "built $app"
}

require_file TELEGRAM_PPC_SDK_ROOT
require_file TELEGRAM_PPC_INSTALL_NAME_TOOL
require_file TELEGRAM_PPC_OTOOL
require_file TELEGRAM_PPC_LIPO
require_file TELEGRAM_PPC_PPC_CXX
require_file TELEGRAM_PPC_I386_CXX
require_file TELEGRAM_PPC_X86_64_CXX
require_file TELEGRAM_PPC_PPC_TDLIB_LIBRARY
require_file TELEGRAM_PPC_I386_TDLIB_LIBRARY
require_file TELEGRAM_PPC_X86_64_TDLIB_LIBRARY
require_file TELEGRAM_PPC_PPC_FFMPEG_ROOT
require_file TELEGRAM_PPC_I386_FFMPEG_ROOT
require_file TELEGRAM_PPC_X86_64_FFMPEG_ROOT

mkdir -p "$TELEGRAM_PPC_BUILD_ROOT"
build_slice ppc ppc "$TELEGRAM_PPC_PPC_CXX" generic 10.4 "$TELEGRAM_PPC_PPC_FFMPEG_ROOT" "$TELEGRAM_PPC_PPC_TDLIB_LIBRARY" TELEGRAM_PPC_PPC
build_slice i386 i386 "$TELEGRAM_PPC_I386_CXX" intel 10.4 "$TELEGRAM_PPC_I386_FFMPEG_ROOT" "$TELEGRAM_PPC_I386_TDLIB_LIBRARY" TELEGRAM_PPC_I386
build_slice x86_64 x86_64 "$TELEGRAM_PPC_X86_64_CXX" intel 10.5 "$TELEGRAM_PPC_X86_64_FFMPEG_ROOT" "$TELEGRAM_PPC_X86_64_TDLIB_LIBRARY" TELEGRAM_PPC_X86_64
assemble_universal
