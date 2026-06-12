# JoininBox integration tests

Run the local Bats suite with:

```bash
test/run-bats-local.sh
```

The descriptor wallet tests require:

- `bats`
- `bitcoind`
- `bitcoin-cli`
- `curl`
- `jq`

The suite starts its own temporary `bitcoind -regtest` datadir and does not use
mainnet, signet, or any existing Bitcoin Core state.

The `amd64-image-test` workflow downloads a previously built
`joininbox-amd64-image-*` artifact, verifies the compressed and raw checksums,
decompresses a runner-local qcow2 copy, boots it with QEMU in snapshot mode,
installs `bats` inside that temporary VM session, and runs the same suite from
the JoininBox checkout inside the image.

The test workflow has three entry points:

- `pull_request`: waits for the successful `amd64-image-build` run for the same
  head commit, then tests that artifact. This makes the workflow usable while it
  is still being introduced in a PR.
- `workflow_run`: runs after a successful `amd64-image-build` once this workflow
  exists on the repository default branch.
- `workflow_dispatch`: reruns against a specific build artifact by providing the
  `amd64-image-build` workflow run ID, as long as the artifact is still retained
  by GitHub Actions.
