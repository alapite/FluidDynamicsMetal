#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
derived_data="$project_root/.build"
app_name="FluidDynamicsMetalOSX.app"
built_app="$derived_data/Build/Products/Debug/$app_name"
root_app="$project_root/$app_name"

usage() {
  printf 'Usage: %s [build|clean|rebuild]\n' "${0##*/}"
  printf '  build    Build and copy the Mac Debug app (default).\n'
  printf '  clean    Remove this script\047s .build directory and copied app.\n'
  printf '  rebuild  Clean, then build and copy the app.\n'
}

if [[ $# -gt 1 ]]; then
  usage >&2
  exit 2
fi

action="${1:-build}"
case "$action" in
  build|clean|rebuild) ;;
  -h|--help) usage; exit 0 ;;
  *) usage >&2; exit 2 ;;
esac

check_root_app() {
  if [[ -L "$root_app" || ( -e "$root_app" && ! -d "$root_app/Contents" ) ]]; then
    printf 'Refusing to replace or remove an unexpected path: %s\n' "$root_app" >&2
    exit 1
  fi
}

if [[ "$action" == clean || "$action" == rebuild ]]; then
  # Validate both paths before deleting either one. Never clean global DerivedData.
  check_root_app
  if [[ -L "$derived_data" || ( -e "$derived_data" && ! -d "$derived_data" ) ]]; then
    printf 'Refusing to remove an unexpected path: %s\n' "$derived_data" >&2
    exit 1
  fi
  rm -rf -- "$derived_data" "$root_app"
  printf 'Removed build artifacts: %s and %s\n' "$derived_data" "$root_app"
  if [[ "$action" == clean ]]; then
    exit 0
  fi
fi

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

check_root_app

# ditto merges directories, so remove the previous app to avoid stale bundle files.
rm -rf -- "$root_app"
ditto "$built_app" "$root_app"
printf 'App ready: %s\n' "$root_app"
