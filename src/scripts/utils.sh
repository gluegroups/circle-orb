#!/bin/false
# shellcheck shell=sh
# shellcheck disable=SC2154

detect_os() {
  # Skip if PLATFORM is already set and readonly
  if [ -n "${PLATFORM:-}" ]; then
    return 0
  fi

  detected_platform="$(uname -s | tr '[:upper:]' '[:lower:]')"

  case "$detected_platform" in
  linux*)
    PLATFORM=linux
    ;;
  darwin*)
    PLATFORM=macos
    ;;
  msys* | cygwin*)
    PLATFORM=windows
    ;;
  *)
    printf '%s\n' "Unsupported OS: \"$platform\"."
    exit 1
    ;;
  esac

  export PLATFORM
  readonly PLATFORM
}
