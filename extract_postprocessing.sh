#!/usr/bin/env bash

# SPDX-License-Identifier: MIT
# Copyright (c) 2025 Samuel Hym, Tarides <samuel@tarides.com>

# Unikraft says in various places it requires bash, so we can follow suit, to
# use its powerful ${v//"$var"/...} substitution

# extract_postprocessing <unikraftdir> <builddir> <targetradix> <targetsuffix>

UNIKRAFTDIR="${1%/}"
REALUNIKRAFTDIR="$(realpath "$UNIKRAFTDIR")"
BUILDDIR="${2%/}"
REALBUILDDIR="$(realpath "$BUILDDIR")"
TARGETRDX="$3"
PATHTARGET="$BUILDDIR/$TARGETRDX"
REALPATHTARGET="$REALBUILDDIR/$TARGETRDX"
TARGETSUFFIX="$(< "$4")"

IFS='\n'

process() {
  while read line; do
    case "$line" in
      "sh "*.cmd|"/bin/sh "*.cmd|"bash "*.cmd|*"/bash "*.cmd)
        # Process the content of the .cmd file
        process < "${line#* }"
        ;;
      *)
        line="${line//"$PATHTARGET"/\"\$\{TARGET\}\"}"
        line="${line//"$REALPATHTARGET"/\"\$\{TARGET\}\"}"
        line="${line//"$TARGETRDX"/\"\$\{TARGET\}\"}"
        line="${line//"$BUILDDIR"/\"\$\{LIBDIR\}\"}"
        line="${line//"$REALBUILDDIR"/\"\$\{LIBDIR\}\"}"
        line="${line//"$UNIKRAFTDIR"/\"\$\{UKLIBDIR\}\"}"
        line="${line//"$REALUNIKRAFTDIR"/\"\$\{UKLIBDIR\}\"}"
        echo "      $line"
        ;;
    esac
  done
}

echo '      mv "$TARGET" "$TARGET".'"$TARGETSUFFIX"
process
