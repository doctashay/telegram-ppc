#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

fail=0

check_executable() {
  local path=$1
  local mode
  mode="$(git ls-files --stage -- "$path" | awk '{print $1}')"
  if [ "$mode" != "100755" ]; then
    echo "$path is not executable in git (mode $mode)" >&2
    fail=1
  fi
}

check_untracked_sensitive_file() {
  local path=$1
  if [ -e "$path" ] && git check-ignore -q "$path"; then
    return
  fi
  if [ -e "$path" ]; then
    echo "$path exists and is not ignored" >&2
    fail=1
  fi
}

check_for_tracked_path() {
  local path=$1
  if git ls-files --error-unmatch "$path" "$path/**" >/dev/null 2>&1; then
    echo "$path must not be tracked" >&2
    fail=1
  fi
}

check_executable scripts/build-universal.sh
check_executable scripts/build-ffmpeg-static.sh
check_executable scripts/ci/bootstrap-common-deps.sh
check_executable scripts/ci/bootstrap-darwin-xtools.sh
check_executable scripts/ci/bootstrap-ffmpeg.sh
check_executable scripts/ci/bootstrap-gcc14.sh
check_executable scripts/ci/bootstrap-openssl.sh
check_executable scripts/ci/bootstrap-osxcross.sh
check_executable scripts/ci/bootstrap-tdlib.sh
check_executable scripts/ci/bootstrap-zlib.sh
check_executable scripts/ci/check-repo.sh
check_executable scripts/ci/use-darwin-legacy-cross-env.sh
check_executable scripts/ci/write-build-config.sh
check_executable scripts/ci/verify-release-app.sh

check_for_tracked_path TelegramCredentials.h
check_for_tracked_path local-build-config.sh
check_for_tracked_path local-build-config.static-ffmpeg.sh
check_for_tracked_path docker

check_untracked_sensitive_file TelegramCredentials.h

if git ls-files | grep -E '(^|/)(dist|build)(/|$)|\.tgz$|\.dmg$' >/dev/null; then
  echo "build artifacts must not be tracked" >&2
  fail=1
fi

exit "$fail"
