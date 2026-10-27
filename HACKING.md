# Some tips to work on OCaml/Unikraft

## How to test some version of the OCaml/Unikraft in GitHub CI

The tests are run in CI on PRs and on pushes on the `main` branch but also on
pushes on branches prefixed by `ci-`, for instance `ci-xyz`.

On pushes to a branch named `ci-xyz` in a fork `abc/ocaml-unikraft` (for any
`xyz` and `abc`), the workflow will pin the branch `xyz+mirage` from the GitHub
repositories `abc/unikraft` and `abc/unikraft-lib-musl` so that it provides a
complete way to test changes on both OCaml/Unikraft and its dependencies.


## How to update the base Unikraft version

1. Update the [Unikraft] and [lib-musl] forks with the new versions and adapt
   the patches.
2. Regenerate the configurations (`make fullconfigs`), reviewing the necessary
   changes; this often requires some tuning of the configuration settings the
   full configurations are generated from, which are located in the
   `dummykernel/config/` directory; `make menuconfig.unikraft` brings up the
   interactive configuration editor for the default full configuration: it can
   be a handy way to explore the new configuration options and select the
   relevant ones.

[Unikraft]: https://github.com/mirage/unikraft/
[lib-musl]: https://github.com/mirage/unikraft-lib-musl/
