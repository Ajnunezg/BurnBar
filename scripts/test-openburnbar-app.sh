#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cache_dir="$repo_root/.spm-cache"
derived_data_dir="$repo_root/.derived-data/openburnbar-app-tests"

rm -rf "$derived_data_dir"
mkdir -p "$cache_dir" "$derived_data_dir"

xcodebuild test \
  -project "$repo_root/OpenBurnBar.xcodeproj" \
  -scheme "OpenBurnBar" \
  -destination "platform=macOS" \
  -clonedSourcePackagesDirPath "$cache_dir" \
  -derivedDataPath "$derived_data_dir" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  -only-testing:"OpenBurnBarTests"
