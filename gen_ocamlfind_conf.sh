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
    # point to is assumed to be already installed in PREFIX
    ARCH=""
    PREFIX="$3/lib/ocaml-unikraft-$2"
    OCAMLDIR="$PREFIX/bin"
    BYTE=".byte"
    OCAMLDEP=ocamldep
    ;;
  *)
    ARCH="_$1"
    PREFIX="$2/lib/ocaml-unikraft-$1"
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

# Check that the compiler is installed in $PREFIX, so that it makes sense to
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
path(unikraft$ARCH) = "$PREFIX/lib/ocaml:$PREFIX/lib"
destdir(unikraft$ARCH) = "$PREFIX/lib"
stdlib(unikraft$ARCH) = "$PREFIX/lib/ocaml"
ocamlopt(unikraft$ARCH) = "$PREFIX/bin/ocamlopt$(checkopt ocamlopt)"
ocamlc(unikraft$ARCH) = "$PREFIX/bin/ocamlc$(checkopt ocamlc)"
ocamlmklib(unikraft$ARCH) = "$PREFIX/bin/ocamlmklib$EXE"
ocamldep(unikraft$ARCH) = "$PREFIX/bin/ocamldep$(checkopt "$OCAMLDEP")"
ocamlcp(unikraft$ARCH) = "$PREFIX/bin/ocamlcp$EXE"
EOF
