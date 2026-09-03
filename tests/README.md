# JoininBox tests

## bats suite

Shell tests using [bats-core](https://github.com/bats-core/bats-core).
They run alongside the JoinMarket NG suite in GitHub Actions
(`.github/workflows/test-bats.yml`) on every push to master and every pull
request. `test/run-bats-local.sh` is the canonical runner for both suites.
`bats -r tests` discovers every `*.bats` file here recursively.

Current coverage:
- `bitcoin-core-version.bats` - pinned Bitcoin Core release, signed manifest
  URLs, supported Linux artifact matrix, and verification ordering
- `repository-contracts.bats` - syntax checks for every maintained shell and
  Python script, systemd unit structure, and safe config-parser adoption
- `source-conf.bats` - safe parsing of config data, quoting, malformed lines,
  forbidden shell syntax, and command-substitution regression coverage
- `service-args.bats` - generated service and wallet path validation
- `hiddenservice-validation.bats` - Tor directory/service/port validation and
  verified atomic torrc replacement invariants
- `start.service.bats` - the wallet password file validation in
  `start.service.sh` (missing/symlink/outside-path/traversal/bad-mode
  rejection, validation order, password over stdin, deletion after use)
- `password-to-file.bats` - `passwordToFile` in `scripts/_functions.sh`
  (unpredictable per-run file, mode 600, EXIT-trap cleanup, cancel/ESC paths)

Shared environment setup lives in `helpers/joininbox-env.bash` - `load` it
from new test files to get a minimal `/home/joinmarket` prepared.

### Run locally

```
git clone --depth 1 https://github.com/bats-core/bats-core /tmp/bats-core
/tmp/bats-core/bin/bats -r tests
```

The suite needs to create `/home/joinmarket` (uses sudo; passwordless on CI
runners). On a machine without passwordless sudo run it inside a user
namespace with a bind-mounted fake home:

```
mkdir -p /tmp/jm-fakehome /tmp/fakebin
printf '#!/bin/bash\nexec "$@"\n' > /tmp/fakebin/sudo && chmod +x /tmp/fakebin/sudo
unshare -rm bash -c '
  mount --bind /tmp/jm-fakehome /home/joinmarket &&
  export PATH="/tmp/fakebin:/tmp/bats-core/bin:$PATH" &&
  cd '"$(pwd)"' && bats -r tests'
```

## Other tests

- `test-prepare-release.sh` (on the first-boot-credentials branch) - mock-based
  regression test for `prepare.release.sh`, no bats required:
  `bash tests/test-prepare-release.sh`
