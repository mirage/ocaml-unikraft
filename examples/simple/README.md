# Simple example

This directory contains just one simple example, avoiding all the complexities
in the multi-examples directory:
- only one example so the C stub can be included simply, without building it as
  library,
- only one backend supported, namely QEMU,
- no code to _run_ the example, as QEMU and Firecracker entail some complexity
  which are really independent from OCaml/Unikraft _per se_.

## How to test it

```
$ dune build
$ qemu-system-x86_64 -nographic -nodefaults -serial stdio -kernel _build/unikraft/hello.exe
```
