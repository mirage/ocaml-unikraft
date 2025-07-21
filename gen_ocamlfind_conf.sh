#!/bin/sh

# SPDX-License-Identifier: MIT
# Copyright (c) 2025 Samuel Hym, Tarides <samuel@tarides.com>

set -eu

# Pick up the binary extension to use from the `$EXEEXT`, with an empty default
# value
EXE="${EXEEXT:-}"

case "$1" in
  default)
    # When building the default `unikraft.conf`, the OCaml compiler this will
    # point to is assumed to be already installed in SYSROOT
    ARCH=""
    PREFIX="$3"
    SYSROOT="$3/lib/ocaml-unikraft-$2"
    OCAMLDIR="$SYSROOT/bin"
    BYTE=".byte"
    OCAMLDEP=ocamldep
    ;;
  *)
    ARCH="_$1"
    PREFIX="$2"
    SYSROOT="$2/lib/ocaml-unikraft-$1"
    OCAMLDIR="ocaml"
    BYTE=""
    OCAMLDEP=tools/ocamldep
    ;;
esac

checkopt() {
  if test -x "$OCAMLDIR/$1.opt$EXE"; then
    printf '.opt%s' "$EXE"
  else
    printf '.byte%s' "$EXE"
  fi
}

# Check that the compiler is installed in $SYSROOT, so that it makes sense to
# detect whether the .opt versions are available

for cmd in ocamlc ocamlopt "$OCAMLDEP"; do
  if ! test -x "$OCAMLDIR/$cmd.opt$EXE" \
    && ! test -x "$OCAMLDIR/$cmd$BYTE$EXE"; then
    printf 'Fatal error: cannot find %s!\nLooked in: "%s"\n' \
      "$cmd" "$OCAMLDIR" >&2
    exit 2
  fi
done

cat << EOF
path(unikraft$ARCH) = "$SYSROOT/lib/ocaml:$SYSROOT/lib:$PREFIX/lib"
destdir(unikraft$ARCH) = "$SYSROOT/lib"
stdlib(unikraft$ARCH) = "$SYSROOT/lib/ocaml"
ocamlopt(unikraft$ARCH) = "$SYSROOT/bin/ocamlopt$(checkopt ocamlopt)"
ocamlc(unikraft$ARCH) = "$SYSROOT/bin/ocamlc$(checkopt ocamlc)"
ocamlmklib(unikraft$ARCH) = "$SYSROOT/bin/ocamlmklib$EXE"
ocamldep(unikraft$ARCH) = "$SYSROOT/bin/ocamldep$(checkopt "$OCAMLDEP")"
ocamlcp(unikraft$ARCH) = "$SYSROOT/bin/ocamlcp$EXE"
EOF
