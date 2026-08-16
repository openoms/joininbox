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

## Design principles

The codebase follows these principles; contributions are expected to uphold
them:

- **Least privilege.** Privileged operations live in small, root-owned helper
  programs exposed through `/etc/sudoers.d/joininbox` with absolute paths and
  fixed arguments. No account gets unrestricted passwordless sudo. Helper
  inputs are validated against allowlists — never arbitrary service names,
  file paths, commands, or environment variables.
- **Configuration is data, not code.** Configuration files are parsed, never
  sourced, in privileged processes. Parsers accept only known keys and reject
  shell metacharacters, duplicate keys, invalid types, and unexpected lines.
  Privileged state lives in root-owned files under `/etc/joininbox/`; user
  preferences stay in the home directory. Configuration is written atomically
  with a restrictive umask and explicit owner and mode.
- **Fail closed on authenticity.** Updates select immutable release tags or
  full commit IDs and are verified against a bundled allowlist of full
  signing-key fingerprints in a fresh temporary keyring — never the user's
  GnuPG home. An unsigned commit, an unexpected signing key, a short or
  ambiguous object ID, or a moved tag must fail before any installed file
  changes. Development-branch and pull-request installs are an explicit,
  consent-gated test mode that cannot install privileged helpers.
- **No secrets in argv or predictable files.** Secrets arrive through terminal
  prompts or protected file descriptors, never command-line arguments.
  Credential material prefers systemd credentials (`LoadCredential=`) or
  anonymous pipes; unavoidable files use a private `0700` runtime directory,
  `mktemp`, `umask 077`, and exclusive creation. `/dev/shm` keeps its normal
  sticky `1777` mode; privileged contexts never glob-delete in shared
  directories and only unlink the exact files they created.
- **Validate at trust boundaries.** Service identifiers, ports, wallet paths,
  version strings, and similar inputs are validated against conservative
  allowlists before use. Tor configuration is written to a dedicated
  root-owned file below `/etc/tor/torrc.d/`, validated with
  `tor --verify-config`, then atomically renamed. Systemd units use fixed or
  escaped instance names; no `/bin/sh -c` with interpolated values, no `eval`
  on caller-controlled input.
- **Unique credentials from first boot.** Images generate unique random
  bootstrap credentials or require console entry. SSH stays blocked until
  first-boot setup completes, uses keys by default, and keeps root login
  disabled. Accounts get independent credentials; unused accounts are removed.
- **Defense in depth.** Systemd sandboxing with service-specific write paths,
  syscall/address-family restrictions, and capability bounding. Signed
  reproducible release images with a published provenance manifest.
- **Safe failure.** A failed update or configuration validation preserves the
  previous working state.

## Review methods

Security work on this repository uses, and future reviews should repeat:

- manual source analysis of privileged install/update paths, credential
  handling, Tor/RPC exposure, signature verification, and shell-injection
  surfaces;
- `bash -n` over all shell scripts;
- committed-secret pattern searches;
- regression tests asserting that: a compromised `joinmarket` account cannot
  obtain root through sudo; shell syntax in configuration files is rejected,
  not executed; unsigned or wrongly-signed updates fail without changing
  files; SSH is unreachable until setup finishes and no image-wide password
  works; identifiers containing separators, whitespace, paths, or shell syntax
  fail; symlinks cannot redirect credential or Tor configuration writes;
  option names or values containing shell syntax never reach `eval`; cleanup
  removes only the exact temporary files the script created.

ShellCheck, Semgrep-style static analysis, and dependency/secret scanning run
in CI and should be extended as the toolchain grows.

## Known limitations

- the `joinmarket` account currently retains broad passwordless sudo —
  treat any service running as that user as equivalent to root until the
  scoped-helper migration completes;
- until the first-boot credential work is universally deployed, change the
  default password on first boot before exposing the machine to any network
  you do not control.

## Disclosure policy

We follow coordinated disclosure: a fix is prepared privately, released with a
security advisory, and only then are details made public. We ask reporters to
give us reasonable time to ship a fix before publishing details.
