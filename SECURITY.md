# Security Policy

## Reporting a vulnerability

Please **do not** open a public GitHub issue for security vulnerabilities.

Report suspected vulnerabilities privately:

- **GitHub private vulnerability reporting:** use the
  [Security advisories](../../security/advisories/new) page of this repository
  ("Report a vulnerability"), or
- **Contact the maintainer** through the channels listed on
  [@openoms](https://github.com/openoms)'s profile.

Please include:

- a description of the issue and its potential impact,
- affected version(s) or commit(s),
- steps to reproduce or a proof of concept,
- any suggested remediation.

We aim to acknowledge reports within **7 days** and to keep reporters informed
while a fix is prepared. Once a fix is available we will credit reporters in
the release notes unless they prefer to remain anonymous.

## Scope

JoininBox is a terminal menu and management layer for JoinMarket, Bitcoin Core,
and related services. Issues in scope include:

- privilege escalation between the `joinmarket` user and root,
- execution of attacker-controlled code through configuration, updates, menus,
  or command arguments,
- exposure or mishandling of wallet credentials and seeds,
- update/bootstrap authenticity (signature verification, pinned keys),
- network-facing exposure introduced by the images or install scripts.

Issues in JoinMarket, Bitcoin Core, Tor, or other bundled software should be
reported to those projects directly; we will coordinate when the interaction
with JoininBox is part of the problem.

## Supported versions

Security fixes are applied to the default branch and included in the next
release tag. Only the **latest release** is supported; older releases and
development branches do not receive backports.

## Threat model

JoininBox handles wallet credentials and installs system services, so its
security boundary assumes that network-facing applications and the
unprivileged `joinmarket` account can be compromised. We protect against:

- compromise of JoinMarket, Jam, a Python dependency, or another service
  running as `joinmarket`;
- a malicious or compromised upstream repository or GitHub account;
- a local unprivileged user racing predictable temporary files;
- network access during initial setup, before the operator changes credentials;
- malformed values supplied through menus, configuration, or command arguments.

The `joinmarket` account and files writable by it must not be treated as
trusted input by root.

## Implemented controls

The following controls are present on the default branch today:

- **Configuration is parsed as data.** `sourceConf()` parses `joinin.conf`
  line-by-line and assigns values with `declare` — never `eval`, never
  sourcing. Malformed lines and values containing shell metacharacters
  (`` ` ``, `$(`, `;`, `|`, `&`, `<`, `>`) abort with an error naming the file
  and line.
- **JoininBox updates are verified before install.** `updateJoininBox()`
  verifies the selected tag or commit with `verify.git.sh` against pinned
  signing-key fingerprints before any file is copied or executed. Unknown
  keys, unsigned refs, and ambiguous object IDs fail closed. Installing a
  pull request or development branch requires explicit operator consent.
- **No passwords via command-line arguments.** Secrets are entered through
  terminal prompts.
- **No `eval` on caller-controlled input** in the installer argument parsing.
- **Safer credential temp files.** Wallet credential material uses `mktemp`
  files with restrictive modes; scripts delete only the exact files they
  created — no wildcard deletion as root in `/dev/shm`, which keeps its
  normal sticky `1777` mode.
- **Constrained generated services.** Generated wallet systemd services
  restrict script identifiers and wallet arguments to explicit allowlists.
- **Validated Tor configuration.** Hidden-service configuration is written to
  a candidate file, validated with `tor --verify-config`, and installed
  atomically.
- **CI checks.** ShellCheck runs on all shell scripts; Bats tests cover the
  hardening contracts above (config parser rejection, update verification
  fail-closed behavior, argument validation, temp-file hygiene).

## Target design principles

The following principles are the normative direction for the codebase. They
guide review of new contributions and the remaining hardening work; not all
are fully implemented yet (see Known limitations).

- **Least privilege.** Privileged operations should live in small, root-owned
  helper programs exposed through `/etc/sudoers.d/joininbox` with absolute
  paths and fixed arguments — no unrestricted passwordless sudo. Helper
  inputs must be validated against allowlists.
- **Stricter configuration handling.** Parsers should accept only known keys,
  reject duplicates, and validate types. Privileged state should move to
  root-owned files under `/etc/joininbox/`, with atomic writes, restrictive
  umask, and explicit owner and mode.
- **Isolated verification.** Signature verification should run in a fresh
  temporary keyring, never importing keys into the user's default GnuPG home.
  Releases should ship signed, reproducible manifests of installed files.
- **Stronger secret handling.** Credential material should prefer systemd
  credentials (`LoadCredential=`) or anonymous pipes; unavoidable files
  belong in a private `0700` runtime directory, not shared `/dev/shm`.
- **Stricter boundary validation.** Tor configuration should be installed as
  a dedicated root-owned file below `/etc/tor/torrc.d/`; systemd units should
  avoid interpolated `/bin/sh -c` entirely.
- **Unique credentials from first boot.** Images should generate unique
  bootstrap credentials or require console entry, keep SSH blocked until
  first-boot setup completes, and keep root login disabled.
- **Defense in depth.** Service-specific systemd write paths, syscall and
  address-family restrictions, capability bounding, and signed reproducible
  release images with a published provenance manifest.
- **Safe failure.** A failed update or configuration validation must preserve
  the previous working state.

## Known limitations

- **Unrestricted passwordless sudo.** The `joinmarket` account still has
  `NOPASSWD:ALL` in the build script and images. Treat any service running as
  that user as equivalent to root until the scoped-helper migration lands.
- **Shared default password.** Images still set the password `joininbox` for
  `root`, `joinmarket`, and `pi`. Change it on first boot before exposing the
  machine to any network you do not control. Unique first-boot credentials
  are in progress ([#193](../../pull/193)).
- **Bootstrap from a moving branch.** The documented install path downloads
  `build_joininbox.sh` from the default branch and executes it as root;
  verification performed later cannot authenticate code already executing. A
  versioned, signed bootstrap is planned.
- **Verification keyring.** `verify.git.sh` imports signing keys into the
  user's default GnuPG home rather than a temporary keyring.
- **Sandboxing and provenance.** Systemd sandboxing is partial; signed
  reproducible images and a release provenance manifest are not yet produced.
- **Scanning coverage.** CI runs ShellCheck and Bats, but no Semgrep-style
  static analysis, dependency review, or secret scanning yet.

## Review methods

The 2026-08 source review used, and future reviews should repeat:

- manual analysis of privileged install/update paths, credential handling,
  Tor/RPC exposure, signature verification, and shell-injection surfaces;
- `bash -n` and ShellCheck over all shell scripts;
- committed-secret pattern searches;
- Bats regression tests for the hardening contracts: shell syntax in
  configuration is rejected, unverified updates fail without changing files,
  invalid identifiers are refused, and cleanup removes only the exact
  temporary files the script created.

Regression tests for the remaining target-state controls (no root via sudo
from `joinmarket`, SSH unreachable until first-boot setup completes) should
be added as those controls land.

## Disclosure policy

We follow coordinated disclosure: a fix is prepared privately, released with a
security advisory, and only then are details made public. We ask reporters to
give us reasonable time to ship a fix before publishing details.
