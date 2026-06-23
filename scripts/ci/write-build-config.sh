#!/usr/bin/env bash
set -euo pipefail

out="${1:-local-build-config.ci.sh}"

require_env() {
  local name=$1
  if [ -z "${!name:-}" ]; then
    echo "required environment variable is empty: $name" >&2
    exit 1
  fi
}

optional_env() {
  local name=$1
  local fallback=${2:-}
  printf '%s\n' "${!name:-$fallback}"
}

required_vars=(
  TELEGRAM_PPC_BUILD_ROOT
  TELEGRAM_PPC_DIST_DIR
  TELEGRAM_PPC_SDK_ROOT
  TELEGRAM_PPC_INSTALL_NAME_TOOL
  TELEGRAM_PPC_OTOOL
  TELEGRAM_PPC_LIPO
)

for name in "${required_vars[@]}"; do
  require_env "$name"
done

quote() {
  printf "%q" "$1"
}

{
  printf '#!/usr/bin/env bash\n'
  printf 'export TELEGRAM_PPC_BUILD_ROOT=%s\n' "$(quote "$TELEGRAM_PPC_BUILD_ROOT")"
  printf 'export TELEGRAM_PPC_DIST_DIR=%s\n' "$(quote "$TELEGRAM_PPC_DIST_DIR")"
  printf 'export TELEGRAM_PPC_DEPENDENCY_ROOTS=%s\n' "$(quote "$(optional_env TELEGRAM_PPC_DEPENDENCY_ROOTS)")"
  printf 'export TELEGRAM_PPC_SDK_ROOT=%s\n' "$(quote "$TELEGRAM_PPC_SDK_ROOT")"
  printf 'export TELEGRAM_PPC_ARM64_SDK_ROOT=%s\n' "$(quote "$(optional_env TELEGRAM_PPC_ARM64_SDK_ROOT)")"
  printf 'export TELEGRAM_PPC_INSTALL_NAME_TOOL=%s\n' "$(quote "$TELEGRAM_PPC_INSTALL_NAME_TOOL")"
  printf 'export TELEGRAM_PPC_OTOOL=%s\n' "$(quote "$TELEGRAM_PPC_OTOOL")"
  printf 'export TELEGRAM_PPC_LIPO=%s\n' "$(quote "$TELEGRAM_PPC_LIPO")"
  printf 'export TELEGRAM_PPC_CA_BUNDLE=%s\n' "$(quote "$(optional_env TELEGRAM_PPC_CA_BUNDLE)")"
  printf 'export TELEGRAM_PPC_JOBS=%s\n' "$(quote "$(optional_env TELEGRAM_PPC_JOBS 2)")"
  printf 'export TELEGRAM_PPC_VERSION=%s\n' "$(quote "$(optional_env TELEGRAM_PPC_VERSION 0.2.1)")"
  printf 'export TELEGRAM_PPC_BUILD_NUMBER=%s\n' "$(quote "$(optional_env TELEGRAM_PPC_BUILD_NUMBER 0)")"
  printf 'export TELEGRAM_PPC_PPC_CXX=%s\n' "$(quote "$(optional_env TELEGRAM_PPC_PPC_CXX)")"
  printf 'export TELEGRAM_PPC_I386_CXX=%s\n' "$(quote "$(optional_env TELEGRAM_PPC_I386_CXX)")"
  printf 'export TELEGRAM_PPC_X86_64_CXX=%s\n' "$(quote "$(optional_env TELEGRAM_PPC_X86_64_CXX)")"
  printf 'export TELEGRAM_PPC_ARM64_CXX=%s\n' "$(quote "$(optional_env TELEGRAM_PPC_ARM64_CXX)")"
  printf 'export TELEGRAM_PPC_PPC_CC=%s\n' "$(quote "$(optional_env TELEGRAM_PPC_PPC_CC)")"
  printf 'export TELEGRAM_PPC_I386_CC=%s\n' "$(quote "$(optional_env TELEGRAM_PPC_I386_CC)")"
  printf 'export TELEGRAM_PPC_X86_64_CC=%s\n' "$(quote "$(optional_env TELEGRAM_PPC_X86_64_CC)")"
  printf 'export TELEGRAM_PPC_ARM64_CC=%s\n' "$(quote "$(optional_env TELEGRAM_PPC_ARM64_CC)")"
  printf 'export TELEGRAM_PPC_PPC_FFMPEG_ROOT=%s\n' "$(quote "$(optional_env TELEGRAM_PPC_PPC_FFMPEG_ROOT)")"
  printf 'export TELEGRAM_PPC_I386_FFMPEG_ROOT=%s\n' "$(quote "$(optional_env TELEGRAM_PPC_I386_FFMPEG_ROOT)")"
  printf 'export TELEGRAM_PPC_X86_64_FFMPEG_ROOT=%s\n' "$(quote "$(optional_env TELEGRAM_PPC_X86_64_FFMPEG_ROOT)")"
  printf 'export TELEGRAM_PPC_ARM64_FFMPEG_ROOT=%s\n' "$(quote "$(optional_env TELEGRAM_PPC_ARM64_FFMPEG_ROOT)")"
  printf 'export TELEGRAM_PPC_PPC_CURL_ROOT=%s\n' "$(quote "$(optional_env TELEGRAM_PPC_PPC_CURL_ROOT)")"
  printf 'export TELEGRAM_PPC_I386_CURL_ROOT=%s\n' "$(quote "$(optional_env TELEGRAM_PPC_I386_CURL_ROOT)")"
  printf 'export TELEGRAM_PPC_X86_64_CURL_ROOT=%s\n' "$(quote "$(optional_env TELEGRAM_PPC_X86_64_CURL_ROOT)")"
  printf 'export TELEGRAM_PPC_ARM64_CURL_ROOT=%s\n' "$(quote "$(optional_env TELEGRAM_PPC_ARM64_CURL_ROOT)")"
  printf 'export TELEGRAM_PPC_PPC_OPENSSL_ROOT=%s\n' "$(quote "$(optional_env TELEGRAM_PPC_PPC_OPENSSL_ROOT)")"
  printf 'export TELEGRAM_PPC_I386_OPENSSL_ROOT=%s\n' "$(quote "$(optional_env TELEGRAM_PPC_I386_OPENSSL_ROOT)")"
  printf 'export TELEGRAM_PPC_X86_64_OPENSSL_ROOT=%s\n' "$(quote "$(optional_env TELEGRAM_PPC_X86_64_OPENSSL_ROOT)")"
  printf 'export TELEGRAM_PPC_ARM64_OPENSSL_ROOT=%s\n' "$(quote "$(optional_env TELEGRAM_PPC_ARM64_OPENSSL_ROOT)")"
  printf 'export TELEGRAM_PPC_PPC_ZLIB_ROOT=%s\n' "$(quote "$(optional_env TELEGRAM_PPC_PPC_ZLIB_ROOT)")"
  printf 'export TELEGRAM_PPC_I386_ZLIB_ROOT=%s\n' "$(quote "$(optional_env TELEGRAM_PPC_I386_ZLIB_ROOT)")"
  printf 'export TELEGRAM_PPC_X86_64_ZLIB_ROOT=%s\n' "$(quote "$(optional_env TELEGRAM_PPC_X86_64_ZLIB_ROOT)")"
  printf 'export TELEGRAM_PPC_ARM64_ZLIB_ROOT=%s\n' "$(quote "$(optional_env TELEGRAM_PPC_ARM64_ZLIB_ROOT)")"
  printf 'export TELEGRAM_PPC_PPC_TDLIB_LIBRARY=%s\n' "$(quote "$(optional_env TELEGRAM_PPC_PPC_TDLIB_LIBRARY)")"
  printf 'export TELEGRAM_PPC_I386_TDLIB_LIBRARY=%s\n' "$(quote "$(optional_env TELEGRAM_PPC_I386_TDLIB_LIBRARY)")"
  printf 'export TELEGRAM_PPC_X86_64_TDLIB_LIBRARY=%s\n' "$(quote "$(optional_env TELEGRAM_PPC_X86_64_TDLIB_LIBRARY)")"
  printf 'export TELEGRAM_PPC_ARM64_TDLIB_LIBRARY=%s\n' "$(quote "$(optional_env TELEGRAM_PPC_ARM64_TDLIB_LIBRARY)")"
  printf 'export TELEGRAM_PPC_PPC_BUNDLE_LIBS=%s\n' "$(quote "$(optional_env TELEGRAM_PPC_PPC_BUNDLE_LIBS)")"
  printf 'export TELEGRAM_PPC_I386_BUNDLE_LIBS=%s\n' "$(quote "$(optional_env TELEGRAM_PPC_I386_BUNDLE_LIBS)")"
  printf 'export TELEGRAM_PPC_X86_64_BUNDLE_LIBS=%s\n' "$(quote "$(optional_env TELEGRAM_PPC_X86_64_BUNDLE_LIBS)")"
  printf 'export TELEGRAM_PPC_ARM64_BUNDLE_LIBS=%s\n' "$(quote "$(optional_env TELEGRAM_PPC_ARM64_BUNDLE_LIBS)")"
  printf 'export TELEGRAM_PPC_FFMPEG_LINKAGE=%s\n' "$(quote "$(optional_env TELEGRAM_PPC_FFMPEG_LINKAGE static)")"
  printf 'export TELEGRAM_PPC_PPC_FFMPEG_EXTRA_LIBS=%s\n' "$(quote "$(optional_env TELEGRAM_PPC_PPC_FFMPEG_EXTRA_LIBS)")"
  printf 'export TELEGRAM_PPC_I386_FFMPEG_EXTRA_LIBS=%s\n' "$(quote "$(optional_env TELEGRAM_PPC_I386_FFMPEG_EXTRA_LIBS)")"
  printf 'export TELEGRAM_PPC_X86_64_FFMPEG_EXTRA_LIBS=%s\n' "$(quote "$(optional_env TELEGRAM_PPC_X86_64_FFMPEG_EXTRA_LIBS)")"
  printf 'export TELEGRAM_PPC_ARM64_FFMPEG_EXTRA_LIBS=%s\n' "$(quote "$(optional_env TELEGRAM_PPC_ARM64_FFMPEG_EXTRA_LIBS)")"
  printf 'export TELEGRAM_PPC_CMAKE_ARGS=%s\n' "$(quote "$(optional_env TELEGRAM_PPC_CMAKE_ARGS)")"
  printf 'export TELEGRAM_PPC_FORBIDDEN_LOAD_PATH_PATTERN=%s\n' "$(quote "$(optional_env TELEGRAM_PPC_FORBIDDEN_LOAD_PATH_PATTERN '/opt/local|/home/|/mnt/|/tmp/')")"
} > "$out"

chmod 600 "$out"
