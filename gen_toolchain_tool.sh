#!/usr/bin/env bash

# SPDX-License-Identifier: MIT
# Copyright (c) 2025 Samuel Hym, Tarides <samuel@tarides.com>

# Generate a wrapper for the C compiler, the linker and other binutils
# Usage: $0 <ARCH> <SHAREDIR> <TOOL>
# with:
#   ARCH: the target architecture (x86_64 or arm64)
#   SHAREDIR: the directory containing ocaml-unikraft-backend-*-* directories
#       with cflags, ldflags, etc. files

ARCH="$1"
SHAREDIR="$2"
TOOL="$3"

# Extract the backend in `ocaml-unikraft-backend-<backend>-<arch>`
extract_backend() {
  backend="${1%-*}"
  backend="${backend##*-}"
  printf %s "$backend"
}

gen_cc() {
  DEFAULT_UNIKRAFT_BACKEND="$(extract_backend \
    "$SHAREDIR"/ocaml-unikraft-backend-*-"$ARCH")"
  case "$DEFAULT_UNIKRAFT_BACKEND" in
    qemu|firecracker|xen)
      ;;
    *)
      DEFAULT_UNIKRAFT_BACKEND=nobackendfound
      ;;
  esac

  cat << EOF
#!/bin/sh

set -e

basedir="\`dirname "\$0"\`"
basedir="\`realpath "\$basedir/.."\`"
UKLIBDIR="\$basedir/lib/unikraft"

# Go through the argument list to know:
# - if we are compiling (by default, we assume that we are linking and use both
#   CFLAGS and LDFLAGS), by looking for an argument suggesting we are compiling
# - the Unikraft backend to use, removing it from the command line as we go
# - the target file (for post-processing steps)

compiling=
backend=
flag=
TARGET=a.out
for arg do
  shift
  if test "\$flag" = z ; then
    flag=
    case "\$arg" in
      unikraft-backend=*)
        backend="\${arg#*=}"
        ;;
      *)
        set -- "\$@" -z "\$arg"
        ;;
    esac
    continue
  fi

  case "\$arg" in
    -[cSEM]|-MM)
      compiling="\$arg"
      flag=
      ;;
    -z)
      flag=z
      continue
      ;;
    -o)
      flag=o
      ;;
    *)
      if [ "\$flag" = o ]; then TARGET="\$arg"; fi
      flag=
      ;;
  esac
  set -- "\$@" "\$arg"
done

case "\${backend:-$DEFAULT_UNIKRAFT_BACKEND}" in
EOF

  for b in "$SHAREDIR"/ocaml-unikraft-backend-*-"$ARCH"; do
    if [ -d "$b" ]; then
      cc="`cat "$b"/cc`"
      includedir="`"$cc" -print-file-name=include`"
      printf '  '
      extract_backend "$b"
      printf ')\n    LIBDIR="$basedir/lib/%s"\n' "${b##*/}"
      printf '    set -- \\\n      -D __Unikraft__ \\\n'
      cat "$b"/cflags
      # Access the compiler base headers, such as x86intrin.h, if needed
      printf '      -isystem %s \\\n' "${includedir@Q}"
      printf '      -static \\\n'
      printf '      "$@" \\\n'
      # Disable warnings due to musl code
      printf '      -D _REDIR_TIME64=0 -Wno-undef -Wno-strict-prototypes\n'
      printf '    if [ -z "$compiling" ]; then\n    set -- \\\n'
      cat "$b"/ldflags
      printf '      ;\n    fi\n'

      # Call to the compiler and post-processing
      # Post-processing is performed only if the `-z` option is given explicitly
      # Call to the compiler is duplicated to `set -x` just before the actual
      # invocations
      printf '    if [ -z "$compiling" -a -n "$backend" ]; then\n'
      printf '      [ -n "${__V}" ] && set -x\n'
      printf '      %s "$@"\n' "$cc"
      cat "$b"/poststeps
      printf '    else\n'
      printf '    [ -n "${__V}" ] && set -x\n'
      printf '      %s "$@"\n' "$cc"
      printf '    fi\n    ;;\n'
    fi
  done

  cat << EOF
  *)
    if [ -n "\$backend" ]; then
      echo 'fatal error: backend "'"\$backend"'"not found' >&2
    else
      echo 'fatal error: no backend found' >&2
    fi
    exit 1
    ;;
esac
EOF
}

cat1() {
  cat "$1"
}

cat_config_file() {
  cat1 "$SHAREDIR"/ocaml-unikraft-backend-*-"$ARCH"/"$1"
}

# Should we use cc for as?
gen_tool() {
  TOOL="$1"
  PREFIX="`cat_config_file toolprefix`"
  if command -v -- "$PREFIX$TOOL" > /dev/null; then
    TOOL="$PREFIX$TOOL"
  fi

  cat << EOF
#!/bin/sh
exec $TOOL "\$@"
EOF
}

case "$TOOL" in
  cc|gcc)
    gen_cc
    ;;
  *)
    gen_tool "$TOOL"
    ;;
esac
