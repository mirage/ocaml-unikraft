(* SPDX-License-Identifier: MIT
 * Copyright (c) 2025 Samuel Hym, Tarides <samuel@tarides.com>
 *)

(* OCaml script to generate all the *.opam files *)

let version_ocaml_unikraft = "1.0.0"
let version_unikraft = "0.18.0"

(**)

let repository_layout = ref false
let url = ref None

let _ =
  let url_src = ref "" in
  let url_and_checksum =
    let seen = ref 0 in
    fun arg ->
      match !seen with
      | 0 ->
          url_src := arg;
          incr seen
      | 1 -> url := Some (!url_src, arg)
      | _ -> failwith ("Don't know what to do with argument: " ^ arg)
  in
  Arg.parse
    [
      ( "-r",
        Arg.Set repository_layout,
        "Use the standard opam-repository layout (packages/...)" );
    ]
    url_and_checksum "gen_opams [-r]";
  match (!repository_layout, !url) with
  | true, None ->
      Printf.eprintf
        "Warning: packages are generated in a repository layout but with `url` \
         missing.\n"
  | false, Some _ ->
      Printf.eprintf
        {|Warning: the `url` field is ignored in package descriptions in source
repositories (ie not from the `opam-repository`).
Generating packages with `url` fields but not in a opam-repository-like
layout (see `-r`) nevertheless.
|}
  | _, _ -> ()

let archs = [ "arm64"; "x86_64" ]
let backends = [ ("firecracker", "Firecracker"); ("qemu", "QEMU") ]
let options = [ ("debug", "debugging", []) ]

(** How the architecture appears in the tool prefixes *)
let prefix_arch = function
  | "arm64" -> "aarch64"
  | "x86_64" as x -> x
  | x -> failwith ("Unsupported arch: " ^ x)

let mkdir_p chunks =
  List.fold_left
    (fun prefix chunk ->
      let dir = Filename.concat prefix chunk in
      (try Sys.mkdir dir 0o755
       with Sys_error msg -> assert (String.ends_with ~suffix:"exists" msg));
      dir)
    "" chunks

let with_package virt package_name version gen =
  let filename =
    if !repository_layout then
      Filename.concat
        (mkdir_p
           [
             "packages";
             package_name;
             Printf.sprintf "%s.%s" package_name version;
           ])
        "opam"
    else Printf.sprintf "%s.opam" package_name
  in
  Out_channel.with_open_bin filename (fun out ->
      if not !repository_layout then
        Printf.fprintf out
          "# This file is generated by gen_opams.ml, edit it instead\n";
      Printf.fprintf out {|opam-version: "2.0"|};
      if not !repository_layout then
        Printf.fprintf out {|
name: "%s"
version: "%s"|} package_name version;
      Printf.fprintf out
        {|
maintainer: "samuel@tarides.com"
homepage: "https://github.com/mirage/ocaml-unikraft/"
dev-repo: "git+https://github.com/mirage/ocaml-unikraft.git"
bug-reports: "https://github.com/mirage/ocaml-unikraft/issues"
tags: "org:mirage"|};
      gen out;
      (match (virt, !url) with
      | true, _ | _, None -> ()
      | false, Some (src, checksum) ->
          Printf.fprintf out
            {|url {
  src:
    "%s"
  checksum:
    "sha256=%s"
}
|}
            src checksum);
      if !repository_layout then
        Printf.fprintf out
          {|available: os = "linux"
x-maintenance-intent: ["(latest)"]
|})

let unikraft_package () =
  (* only when generating a repository layout *)
  if !repository_layout then
    let filename =
      Filename.concat
        (mkdir_p
           [
             "packages";
             "unikraft";
             Printf.sprintf "unikraft.%s" version_unikraft;
           ])
        "opam"
    in
    Out_channel.with_open_bin filename (fun out ->
        Printf.fprintf out
          {|opam-version: "2.0"
synopsis: "Unikraft sources"
description: "Source package for Unikraft"
maintainer: "samuel@tarides.com"
authors: "Unikraft contributors"
license: ["BSD-3-Clause" "MIT" "GPL-2.0-or-later" "GPL-2.0-only"]
homepage: "https://unikraft.org"
bug-reports: "https://github.com/mirage/ocaml-unikraft/issues"
tags: "org:mirage"
depends: [
    "conf-bison"
    "conf-flex"
    "conf-python-3"
]
install: [
  ["rm" "-rf" ".github" ".gitignore"]
  ["cp" "-r" "." "%%{_:lib}%%"]
]
dev-repo: "git+https://github.com/unikraft/unikraft.git"
url {
  src:
    "https://github.com/mirage/unikraft/archive/refs/tags/v0.18.0.tar.gz"
  checksum:
    "sha256=bea0178b74d1c63fbb64c6c477e12bd01200cd7faa400dcd1114b5b679e274a5"
}
available:
  os = "linux" &
  (arch = "arm64" | arch = "x86_64" | arch = "s390x" | arch = "riscv64" |
   arch = "ppc64")
x-maintenance-intent: ["(latest)"]
|})

let unikraft_musl_package () =
  (* only when generating a repository layout *)
  if !repository_layout then
    let filename =
      Filename.concat
        (mkdir_p
           [
             "packages";
             "unikraft-musl";
             Printf.sprintf "unikraft-musl.%s" version_unikraft;
           ])
        "opam"
    in
    Out_channel.with_open_bin filename (fun out ->
        Printf.fprintf out
          {|opam-version: "2.0"
synopsis: "Unikraft's wrapper for musl"
description: "Source package for the musl wrapper for Unikraft"
maintainer: "samuel@tarides.com"
authors: "Unikraft contributors"
license: ["MIT" "BSD-3-Clause"]
homepage: "https://unikraft.org"
bug-reports: "https://github.com/mirage/ocaml-unikraft/issues"
tags: "org:mirage"
install: [
  ["rm" "-rf" ".github"]
  ["cp" "-r" "." "%%{_:lib}%%"]
]
dev-repo: "git+https://github.com/unikraft/lib-musl.git"
url {
  src:
    "https://github.com/mirage/unikraft-lib-musl/archive/refs/tags/v0.18.0.tar.gz"
  checksum:
    "sha256=1ef2a96b732a21a591be2bad49f6ccff623564119470e2098d66cc23a225ca29"
}
extra-source "musl-1.2.3.tar.gz" {
  src: "https://www.musl-libc.org/releases/musl-1.2.3.tar.gz"
  checksum:
    "sha256=7d5b0b6062521e4627e099e4c9dc8248d32a30285e959b7eecaa780cf8cfd4a4"
}
x-maintenance-intent: ["(latest)"]
|})

let conf_target_gcc_package arch =
  (* only when generating a repository layout *)
  let version = "1"
  and pfx_arch = prefix_arch arch
  and deb_arch =
    (* how the arch appears in the Debian package name, as it’s yet another
       variant... *)
    match arch with
    | "arm64" -> "aarch64"
    | "x86_64" -> "x86-64"
    | x -> failwith ("Unsupported arch: " ^ x)
  in
  let cmd = Printf.sprintf "%s-linux-gnu-gcc" pfx_arch in
  if !repository_layout then
    let filename =
      Filename.concat
        (mkdir_p
           [
             "packages";
             Printf.sprintf "conf-%s" cmd;
             Printf.sprintf "conf-%s.%s" cmd version;
           ])
        "opam"
    in
    Out_channel.with_open_bin filename (fun out ->
        Printf.fprintf out
          {|opam-version: "2.0"
synopsis: "Virtual package relying on the %s compiler (for C)"
description:
  "This package can only install if the %s compiler is installed on the system (whether this is a cross compiler or not)."
maintainer: "samuel@tarides.com"
authors: ["Samuel Hym"]
license: "GPL-2.0-or-later"
homepage: "https://github.com/ocaml/opam-repository"
bug-reports: "https://github.com/ocaml/opam-repository/issues"
flags: conf
build: [%S "--version"]
depexts: [
  ["gcc-%s-linux-gnu"] {os-family = "debian"}
  ["gcc-%s-linux-gnu"] {os-family = "fedora"}
  ["%s-linux-gnu-gcc"] {os-family = "arch"}
]
post-messages:
  """\
Please install %s-linux-gnu-gcc manually, as there is no known package
for it for your distribution."""
    {failure}
x-maintenance-intent: ["(latest)"]
|}
          cmd cmd cmd deb_arch pfx_arch pfx_arch pfx_arch)

let backend_package arch backend =
  let short_name, long_name = backend in
  let package_name =
    Printf.sprintf "ocaml-unikraft-backend-%s-%s" short_name arch
  in
  with_package false package_name version_unikraft (fun out ->
      Printf.fprintf out
        {|
synopsis: "%s/%s Unikraft backend for OCaml"
authors: ["Samuel Hym" "Unikraft contributors"]
license: ["MIT" "BSD-3-Clause" "GPL-2.0-only"]
depends: [
  "unikraft" {= version}
  "unikraft-musl" {= version}
  "conf-%s-linux-gnu-gcc" {arch != "%s"}
]
depopts: [|}
        long_name arch (prefix_arch arch) arch;
      List.iter
        (fun (opt, _, _) ->
          Printf.fprintf out "\n  \"ocaml-unikraft-option-%s\"" opt)
        options;
      Printf.fprintf out
        {|
]
build: [
  [
    make
    "-j%%{jobs}%%"
    "UNIKRAFT=%%{unikraft:lib}%%"
    "UNIKRAFTMUSL=%%{unikraft-musl:lib}%%"
    "OCUKPLAT=%s"
    "OCUKARCH=%s"
    "OCUKEXTLIBS=musl"
    "OCUKCONFIGOPTS+=debug" {ocaml-unikraft-option-debug:installed}
    "UK_CFLAGS=-std=gnu11"
    "%%{name}%%.install"
  ]
]
|}
        short_name arch)

let option_package option =
  let short_name, long_name, conflicts = option in
  let package_name = Printf.sprintf "ocaml-unikraft-option-%s" short_name in
  with_package true package_name version_unikraft (fun out ->
      Printf.fprintf out
        {|
synopsis:
  "Virtual package to enable %s in the Unikraft backends"
authors: "Samuel Hym"
license: "MIT"
|}
        long_name;
      match conflicts with
      | [] -> ()
      | _ ->
          Printf.fprintf out "conflict-class: [\n";
          List.iter (Printf.fprintf out "  \"ocaml-unikraft-%s\"\n") conflicts;
          Printf.fprintf out "]\n")

let toolchain_package arch =
  let package_name = Printf.sprintf "ocaml-unikraft-toolchain-%s" arch in
  with_package false package_name version_unikraft (fun out ->
      Printf.fprintf out
        {|
synopsis:
  "C toolchain to build an OCaml cross compiler to the freestanding Unikraft %s backends"
description:
  "This package provides a C toolchain to build an OCaml cross compiler, suitable for linking with a Unikraft %s unikernel."
authors: "Samuel Hym"
license: "MIT"
depends: [
  "ocaml-unikraft-backend-qemu-%s" | "ocaml-unikraft-backend-firecracker-%s"
]
build: [
  [
    make
    "-j%%{jobs}%%"
    "LIB=%%{lib}%%"
    "SHARE=%%{share}%%"
    "OCUKARCH=%s"
    "%%{name}%%.install"
  ]
]
|}
        arch arch arch arch arch)

let compiler_package arch =
  let package_name = Printf.sprintf "ocaml-unikraft-%s" arch in
  with_package false package_name version_ocaml_unikraft (fun out ->
      Printf.fprintf out
        {|
synopsis: "OCaml cross compiler to the freestanding Unikraft %s backends"
description:
  "This package provides an OCaml cross compiler, suitable for linking with a Unikraft %s unikernel."
authors: "Samuel Hym"
license: ["MIT" "LGPL-2.1-or-later WITH OCaml-LGPL-linking-exception"]
depends: [
  "ocaml" {= "5.3.0"}
  "ocaml-unikraft-toolchain-%s"
  "ocamlfind"
  "ocaml-src" {build}
  "conf-git" {build}
]
build: [
  [
    make
    "-j%%{jobs}%%"
    "prefix=%%{prefix}%%"
    "BIN=%%{bin}%%"
    "LIB=%%{lib}%%"
    "SHARE=%%{share}%%"
    "OCUKARCH=%s"
    "%%{name}%%.install"
  ]
]
install: [
  [make "install-ocaml"]
]
conflicts: ["ocaml-option-bytecode-only"]
|}
        arch arch arch arch)

let default_compiler_package arch =
  let package_name = Printf.sprintf "ocaml-unikraft-default-%s" arch in
  with_package false package_name version_ocaml_unikraft (fun out ->
      Printf.fprintf out
        {|
synopsis:
  "OCaml default cross compiler to the freestanding Unikraft %s backends"
description:
  "This package provides an OCaml cross compiler, suitable for linking with a Unikraft %s unikernel, as the default `unikraft` ocamlfind toolchain."
authors: "Samuel Hym"
license: "MIT"
depends: ["ocaml-unikraft-%s" "ocamlfind"]
conflict-class: "ocaml-unikraft-default"
build: [
  [make "prefix=%%{prefix}%%" "OCUKARCH=%s" "%%{name}%%.install"]
]
|}
        arch arch arch arch)

let default_backend_package backend =
  let short_name, long_name = backend in
  let package_name = Printf.sprintf "ocaml-unikraft-backend-%s" short_name in
  with_package true package_name version_unikraft (fun out ->
      Printf.fprintf out
        {|
synopsis:
  "Virtual package to ensure the %s Unikraft backend is installed for the default cross compiler"
description:
  "This virtual package ensures that the %s backend is installed for the default `unikraft` ocamlfind cross toolchain."
authors: "Samuel Hym"
license: "MIT"
depends: [
  "ocaml-unikraft"
  ("ocaml-unikraft-default-x86_64" & "ocaml-unikraft-backend-%s-x86_64") |
  ("ocaml-unikraft-default-arm64" & "ocaml-unikraft-backend-%s-arm64")
]
|}
        long_name long_name short_name short_name)

let main_package () =
  with_package true "ocaml-unikraft" version_ocaml_unikraft (fun out ->
      Printf.fprintf out
        {|
synopsis:
  "Virtual package to install one of the OCaml default cross compilers to the freestanding Unikraft backends"
description:
  "This virtual package ensures that an OCaml cross compiler is available for linking with a Unikraft unikernel as the default `unikraft` ocamlfind toolchain. Explicitly choose one among the ocaml-unikraft-default-* packages to control which one is actually installed."
authors: "Samuel Hym"
license: "MIT"
depends: ["ocaml-unikraft-default-x86_64" | "ocaml-unikraft-default-arm64"]
|})

let _ =
  unikraft_package ();
  unikraft_musl_package ();
  List.iter conf_target_gcc_package archs;
  List.iter (fun arch -> List.iter (backend_package arch) backends) archs;
  List.iter option_package options;
  List.iter toolchain_package archs;
  List.iter compiler_package archs;
  List.iter default_compiler_package archs;
  List.iter default_backend_package backends;
  main_package ()
