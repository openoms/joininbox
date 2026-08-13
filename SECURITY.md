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

## Known limitations and ongoing hardening

See [SECURITY-HARDENING.md](SECURITY-HARDENING.md) for the full threat model,
the findings of the most recent source review, and the staged remediation plan
with links to the implementation pull requests.

Until the hardening plan lands, operators should be aware that:

- the `joinmarket` account has passwordless sudo by design — treat any service
  running as that user as equivalent to root;
- the initial images ship with a shared default password (`joininbox`) — change
  it on first boot before exposing the machine to any network you do not
  control;
- JoininBox self-updates follow the default branch — prefer verifying release
  tags before updating.

## Disclosure policy

We follow coordinated disclosure: a fix is prepared privately, released with a
security advisory, and only then are details made public. We ask reporters to
give us reasonable time to ship a fix before publishing details.
