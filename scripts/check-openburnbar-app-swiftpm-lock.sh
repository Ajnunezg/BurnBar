#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
project_path="$repo_root/OpenBurnBar.xcodeproj"
lockfile_path="$repo_root/OpenBurnBar.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
cache_dir="$repo_root/.spm-cache"
derived_data_dir="$repo_root/.derived-data/openburnbar-lock-check"

if [[ ! -f "$lockfile_path" ]]; then
  echo "Missing app SwiftPM lockfile at $lockfile_path" >&2
  exit 1
fi

rm -rf "$derived_data_dir"
mkdir -p "$cache_dir" "$derived_data_dir"

xcodebuild -resolvePackageDependencies \
  -project "$project_path" \
  -scheme "OpenBurnBar" \
  -clonedSourcePackagesDirPath "$cache_dir" \
  -derivedDataPath "$derived_data_dir" \
  >/dev/null

git -C "$repo_root" diff --exit-code -- "$lockfile_path"
