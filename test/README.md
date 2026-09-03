# JoininBox integration tests

Run the local Bats suite with:

```bash
test/run-bats-local.sh
```

The runner executes both the retained hardening tests under `tests/` and the
JoinMarket NG tests under `test/bats/`. The NG configuration, lifecycle, and
wiring tests require only `bats` and Python 3.11 or newer. They do not need root
or network access. Some retained hardening tests require passwordless `sudo` to
prepare `/home/joinmarket`; see `tests/README.md` for a local user-namespace
alternative.

The retained legacy descriptor-wallet migration tests additionally require:

- `bats`
- `bitcoind`
- `bitcoin-cli`
- `curl`
- `jq`

Those tests start their own temporary `bitcoind -regtest` datadir and do not use
mainnet, signet, or any existing Bitcoin Core state.

Run a focused file or test with:

```bash
bats test/bats/joinmarket-ng-lifecycle.bats
bats -f 'onion RPC detection' test/bats/joinmarket-ng-lifecycle.bats
```

The `amd64-image-test` workflow downloads a previously built
`joininbox-amd64-image-*` artifact, verifies the compressed and raw checksums,
decompresses a runner-local qcow2 copy, boots it with QEMU in snapshot mode,
copies a pinned `bats-core` checkout into that temporary VM session, and runs
the same suite from the JoininBox checkout inside the image. This avoids
depending on the guest's configured APT repositories just to install test
tooling.

The test workflow has two entry points:

- `workflow_run`: runs after a successful `amd64-image-build` once this workflow
  exists on the repository default branch.
- `workflow_dispatch`: reruns against a specific build artifact by providing the
  `amd64-image-build` workflow run ID, as long as the artifact is still retained
  by GitHub Actions.
