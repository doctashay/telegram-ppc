#!/usr/bin/env bash
set -euo pipefail

: "${TELEGRAM_PPC_CI_ROOT:?TELEGRAM_PPC_CI_ROOT is required}"
: "${TELEGRAM_PPC_NLOHMANN_JSON_VERSION:=v3.11.3}"

common_root="$TELEGRAM_PPC_CI_ROOT/deps/common"
include_dir="$common_root/include/nlohmann"

mkdir -p "$include_dir"

if [ ! -f "$include_dir/json.hpp" ]; then
  curl -fsSL \
    "https://raw.githubusercontent.com/nlohmann/json/${TELEGRAM_PPC_NLOHMANN_JSON_VERSION}/single_include/nlohmann/json.hpp" \
    -o "$include_dir/json.hpp"
fi

echo "TELEGRAM_PPC_DEPENDENCY_ROOTS=$common_root" >> "$GITHUB_ENV"
