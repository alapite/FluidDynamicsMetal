#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
derived_data="$project_root/.build"
app_name="FluidDynamicsMetalOSX.app"
built_app="$derived_data/Build/Products/Debug/$app_name"
root_app="$project_root/$app_name"

xcodebuild \
  -project "$project_root/FluidDynamicsMetal.xcodeproj" \
  -scheme FluidDynamicsMetalOSX \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath "$derived_data" \
  CODE_SIGNING_ALLOWED=NO \
  build

if [[ ! -d "$built_app" ]]; then
  printf 'Build succeeded, but the app was not found at %s\n' "$built_app" >&2
  exit 1
fi

if [[ -L "$root_app" || ( -e "$root_app" && ! -d "$root_app/Contents" ) ]]; then
  printf 'Refusing to replace an unexpected path: %s\n' "$root_app" >&2
  exit 1
fi

ditto "$built_app" "$root_app"
printf 'App ready: %s\n' "$root_app"
