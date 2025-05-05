#!/bin/sh

# SPDX-License-Identifier: MIT
# Copyright (c) 2025 Samuel Hym, Tarides <samuel@tarides.com>

ARCH="$1"

main() {
  printf 'lib_root: [
  "_build/unikraft_%s.conf" { "findlib.conf.d/unikraft_%s.conf" }
]
lib: [
  "_build/empty" { "lib/is_unikraft/META" }
]
' "$ARCH" "$ARCH"
}

main
