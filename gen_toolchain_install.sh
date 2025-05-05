#!/bin/sh

# SPDX-License-Identifier: MIT
# Copyright (c) 2025 Samuel Hym, Tarides <samuel@tarides.com>

# Generate a .install file for the toolchain
# Takes as arguments the architecture (x86_64 or arm64) followed by all the
# toolchain tools

ARCH="$1"
shift

install_file() {
  # install_file <src> [dest]
  if [ -z "$2" ]; then
    printf '  "%s"\n' "$1"
  else
    printf '  "%s" { "%s" }\n' "$1" "$2"
  fi
}

main() {
  printf '%s: [\n' bin
  for f in "$@"; do
    install_file "$f"
  done
  printf ']\n'
}

main "$@"
