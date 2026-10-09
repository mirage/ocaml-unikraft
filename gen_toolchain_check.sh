#!/bin/sh

# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Samuel Hym, Tarides <samuel@tarides.com>

# Generate a header to check for the version of the  C compiler
# Usage: $0 <ARCH> <SHAREDIR>
# with:
#   ARCH: the target architecture (x86_64 or arm64)
#   SHAREDIR: the directory containing ocaml-unikraft-backend-*-* directories
#       with the cc file

set -eu

ARCH=$1
SHAREDIR=$2

# To interrogate the C preprocessor to know which compiler it is (GCC or clang)
# and its major version number so that the following header_template can be
# filled in with the proper strings and value (they appear in the same order
# than the %s in the header_template)
cpp_test='#ifdef __clang__
!defined clang_major __clang_major__
#else
defined GNUC __GNUC__
#endif
'

header_template='#if %s(__clang__) || __%s__ != %s
#warning "This OCaml/Unikraft toolchain expects another C compiler version:\\
 reinstall the opam ocaml-unikraft-*-%s packages."
#endif
'

gen_compiler_version_check()
{
    read def key ver
    # def is either '!defined' (for Clang) or 'defined' (for GCC)
    # key is either 'clang_major' or 'GNUC'
    # ver is the major version number of the compiler
    printf "$header_template" "$def" "$key" "$ver" "$ARCH"
}

main() {
  cc=
  for b in "$SHAREDIR"/ocaml-unikraft-backend-*-"$ARCH"; do
    if test -d "$b"; then
      cc="$(cat "$b"/cc)"
      break
    fi
  done
  if test -z "$cc"; then
    printf "No compiler found!\n" 1>&2
    exit 1
  fi

  printf %s "$cpp_test" | $cc -E -P -x c - | sed '/^$/d' | \
    gen_compiler_version_check
}

main
