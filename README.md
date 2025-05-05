# OCaml / Unikraft: an OCaml cross compiler to Unikraft backends

This repository provides [opam] packages to install an OCaml (cross) compiler
that can generate unikernels using [Unikraft].

[opam]: https://opam.ocaml.org
[Unikraft]: https://unikraft.org


## Packages

This project is split up into the following packages.

- `ocaml-unikraft-backend-<backend>-<arch>`: all the object files and headers
  necessary to build a unikernel for the specific `<backend>` and `<arch>`
  combination.

- `ocaml-unikraft-option-debug`: if that package is installed, the backends will
  be built with (really verbose!) debugging messages.

- `ocaml-unikraft-toolchain-<arch>`: a toolchain using the
  `<arch>-unikraft-ocaml-` prefix; the toolchain is a set of wrapper shell
  scripts to add the necessary options to drive the underlying tools.
  - In particular, `<arch>-unikraft-ocaml-cc` is a wrapper for the C compiler
    that will interpret the `-z unikraft-backend=xyz` arguments to choose the
    backend that should be used and that will proceed to generate a unikernel
    (ie it will apply the required postprocessing steps to do so) when asked to
    link; it follows [Solo5] toolchain convention: if you set `$__V` to `1`, it
    will verbosely display all the external invocations.

- `ocaml-unikraft-<arch>`: the actual OCaml cross compilers for the given `<arch>`.

- `ocaml-unikraft-default-<arch>`: simple packages that only install a
  `ocamlfind` toolchain named `unikraft` (so that switching between architecture
  do not require to rebuild the full OCaml compiler).

- `ocaml-unikraft-backend-<backend>`: virtual packages to ensure that the given
  `<backend>` is installed for the default architecture, as set by which
  `ocaml-unikraft-default-<arch>` package is installed.

- `ocaml-unikraft`: the virtual package to ensure one of the default compiler
  package is installed.

The supported backends at the moment are:

- [QEMU],
- [Firecracker].

[QEMU]: https://www.qemu.org/
[Firecracker]: https://firecracker-microvm.github.io/


## Installation

This project is really meant to be installed by [opam], as it relies on opam to:

- download the various necessary sources (the OCaml compiler, [musl], Unikraft’s
  [lib-musl] and a few patches),
- install most of the files (the installation of the OCaml compiler itself is
  done by its upstream installation procedure).

So the easiest way to go about installing this project is to use the standard
`opam` commands:
- [`install`] to install the versions released on the opam repository,
- or [`pin`] to install specific revisions of that repository.

[musl]: https://musl.libc.org/
[lib-musl]: https://github.com/unikraft/lib-musl
[`install`]: https://opam.ocaml.org/doc/Usage.html#opam-install
[`pin`]: https://opam.ocaml.org/doc/Usage.html#opam-pin


## Examples

The `examples` directory contains a couple of small examples. In particular, the
`simple` subdirectory contains a single easy Hello-World example. You can simply
test it thus:

```
$ cd examples/simple/
$ dune build
$ qemu-system-x86_64 -nographic -nodefaults -serial stdio -kernel _build/unikraft/hello.exe
```

The `all` subdirectory is a bit more involved, in particular because it supports
building for QEMU or Firecracker and to run the resulting unikernels and because
both QEMU and Firecracker require some configuration to run a unikernel. The
OCaml code of those examples are all quite simple, though.


## Development

It is possible to build this project fully locally, which is really what is used
to develop it.

1.  Install Unikraft sources:

    ```
    $ opam install unikraft
    # or, if you must, you can also create a package by pinning and editing it,
    # setting its description from unikraft.0.18.0.opin, so, in one go:
    $ OPAMEDITOR="cp unikraft.0.18.0.opin" opam pin add --edit -y unikraft - < /dev/null
    ```

2.  Download the other dependencies, mimicking what opam downloads when
    installing the `ocaml-unikraft-<backend>-<arch>` packages:

    ```
    $ make downloads
    ```

3.  Build the compiler locally, ie fully installed in `_build`:

    ```
    $ make localbuild UNIKRAFT="$(opam var unikraft:lib)"
    ```

    where an extra `-jX` will be really useful.

4.  Set the `PATH` and `OCAMLFIND_CONF` variables as indicated to access the
    ocamlfind `unikraft` toolchain in your shell session, or simply run
    `make localtests` to run the tests in `examples/all/` with that compiler.


## Contributions

Contributions are most welcome!

- [File issues](https://github.com/mirage/ocaml-unikraft/issues) to report bugs
  or feature requests.
- [Contribute code or documentation](./CONTRIBUTING.md).

---

This project has been created and is maintained by
[Tarides](https://tarides.com).
