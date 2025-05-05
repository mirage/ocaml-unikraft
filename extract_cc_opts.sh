#!/usr/bin/env bash

# SPDX-License-Identifier: MIT
# Copyright (c) 2025 Samuel Hym, Tarides <samuel@tarides.com>

# Unikraft says in various places it requires bash, so we can follow suit, to
# use its powerful ${v//"$var"/...} substitution

# extract_cc_opts <unikraftdir> <builddir> <file.cmd> <opts> <cc> <toolprefix>
# 3 inputs, 3 outputs, outputs are optional

UNIKRAFTDIR="${1%/}"
REALUNIKRAFTDIR="$(realpath "$UNIKRAFTDIR")"
BUILDDIR="${2%/}"
REALBUILDDIR="$(realpath "$BUILDDIR")"
# for the backend in X/lib/ocaml-unikraft-backend-qemu-x86_64, the library L
# (musl, etc.) is in X/libs/L
UKLIBSDIR="${BUILDDIR%/*/*}/libs"
REALUKLIBSDIR="$(realpath "$UKLIBSDIR")"
FILEOPTS="$4"
FILECC="$5"
FILETOOLPREFIX="$6"

last_was_obj=

maybe_inject_placeholder() {
  if [ -n "$last_was_obj" ]; then
    printf '      "$@" \\\n'
    last_was_obj=
  fi
}

# Process one option: quote so that it can be fed back to another shell and
# replace the UNIKRAFTDIR and BUILDDIR directories with variables, so that it
# can be interpreted on the fly
process_option() {
  opt="$1"
  opt="${opt//"$BUILDDIR"/__builddir_temporary_placeholder__}"
  opt="${opt//"$REALBUILDDIR"/__builddir_temporary_placeholder__}"
  opt="${opt//"$UKLIBSDIR"/__builddir_temporary_placeholder__}"
  opt="${opt//"$REALUKLIBSDIR"/__builddir_temporary_placeholder__}"
  opt="${opt//"$UNIKRAFTDIR"/__unikraftdir_temporary_placeholder__}"
  opt="${opt//"$REALUNIKRAFTDIR"/__unikraftdir_temporary_placeholder__}"
  qopt="${opt@Q}"
  # Check that it was quoted using the form '...', as we will assume it was when
  # injecting the variables; if that's not the case, do it using sed
  if [ -n "${qopt##\'*\'}" ]; then
    qopt="'$(printf %s "$opt" | sed "s/'/'\\\\''/g")'"
  fi
  qopt="${qopt//__builddir_temporary_placeholder__/\'\"\$\{LIBDIR\}\"\'}"
  qopt="${qopt//__unikraftdir_temporary_placeholder__/\'\"\$\{UKLIBDIR\}\"\'}"
  printf '      %s \\\n' "$qopt"
}

# Compilation options, extracted from the commandline for dummymain.o
# or linking options, extracted from the commandline for dummykernel*.dbg
process_options() {
  eval set -- `cat "$1"`
  case "$1" in
    *gcc)
      # OK
      if [ -n "$FILECC" ] ; then
        printf '%s' "$1" > "$FILECC"
      fi
      if [ -n "$FILETOOLPREFIX" ] ; then
        printf '%s' "${1%gcc}" > "$FILETOOLPREFIX"
      fi
      shift
      ;;
    *)
      echo Expected a commandline calling out to GCC to compile the source
      exit 1
      ;;
  esac

  skip=
  for opt in "$@"; do
    if [ -z "$skip" ]; then
      case "$opt" in
        *dummymain.c)
          # the dummy source we want to replace, skip it
          ;;
        *appdummykernel.o)
          # the dummy object we want to replace, skip it
          last_was_obj=y
          ;;
        *appdummykernel/*)
          # some file inside the dummy directory, skip it
          ;;
        */libukboot_main.o)
          # the (weak) `main` symbol, skip it so that the standard `main` from
          # OCaml runtime is used if the user doesn't override it
          last_was_obj=y
          ;;
        -g*|-D?*|-O*|-Wall|-Wextra|-Wp,*|-c)
          # we'll let OCaml choose such options, skip it
          ;;
        -D|-o)
          # skip this and the argument that follows
          skip=y
          ;;
        -I*|-L*)
          # Keep only existing directories
          if [ -d "${opt#-[IL]}" ]; then
            # Use variables for the base directories, so that we can install
            # object files and use them in all unikernels
            maybe_inject_placeholder
            process_option "$opt"
          fi
          ;;
        *.o)
          # Use variables for the base directories, so that we can install
          # object files and use them in all unikernels
          process_option "$opt"
          last_was_obj=y
          ;;
        *)
          # Use variables for the base directories, so that we can install
          # object files and use them in all unikernels
          maybe_inject_placeholder
          process_option "$opt"
          ;;
      esac
    else
      # we wanted to skip one argument
      skip=
    fi
  done
  maybe_inject_placeholder
}

if [ -n "$FILEOPTS" ]; then
  process_options "$3" > "$FILEOPTS"
else
  process_options "$3"
fi
