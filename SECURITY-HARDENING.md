# JoininBox security hardening plan

This document records the findings of a source review of commit
`54473190c8278a023049f87ea4c5520fb26425e2` and proposes a staged remediation
plan. JoininBox handles wallet credentials and installs system services, so its
security boundary should assume that network-facing applications and the
unprivileged `joinmarket` account can be compromised.

## Executive summary

The current design gives the `joinmarket` account unrestricted passwordless
sudo and then runs scripts and configuration owned by that account in privileged
contexts. This collapses the intended separation between wallet applications and
the host operating system. The update path and known initial password make that
trust relationship more exposed.

The first release in the hardening series should break this privilege-escalation
chain. Later releases can tighten credential transport, argument validation, and
service sandboxing without blocking the highest-impact fixes.

## Threat model

Protect against:

- compromise of JoinMarket, Jam, a Python dependency, or another service running
  as `joinmarket`;
- a malicious or compromised upstream repository or GitHub account;
- a local unprivileged user racing predictable temporary files;
- network access during initial setup, before the operator changes credentials;
- malformed values supplied through menus, configuration, or command arguments.

The `joinmarket` account and files writable by it must not be treated as trusted
input by root.

## Findings and recommendations

### 1. Unrestricted passwordless sudo (critical)

Affected code:

- `build_joininbox.sh` grants `joinmarket ALL=(ALL) NOPASSWD:ALL`.
- `scripts/install.joinmarket.sh` grants the same access to additional users.
- `ci/amd64/debian/scripts/sudoers.sh` installs the same rule in images.

Impact: code execution in any process running as `joinmarket` immediately becomes
root code execution. The systemd sandbox options used by wallet services do not
provide a meaningful boundary while this rule exists.

Recommendation:

1. Remove the account from the `sudo` group and delete all `NOPASSWD:ALL` rules.
2. Move privileged operations into small, root-owned helper programs.
3. Expose only the required helpers through `/etc/sudoers.d/joininbox`, using
   absolute paths and fixed arguments wherever possible.
4. Validate every helper input against an allowlist. Do not allow arbitrary
   service names, file paths, commands, or environment variables.

Acceptance criteria: compromising `joinmarket` cannot modify root-owned files,
sudoers, systemd units, SSH configuration, Tor configuration, or execute an
arbitrary command as another user.

### 2. User-writable configuration is sourced as shell code (critical)

Affected code: many scripts, including `scripts/install.hiddenservice.sh`, use
`source /home/joinmarket/joinin.conf`. The file is created as `joinmarket` and is
modified by user-facing scripts.

Impact: `joinin.conf` is executable shell syntax. A command placed in the file is
executed whenever a privileged script sources it.

Recommendation:

- Never source a writable configuration file in a privileged process.
- Parse it as data using a shared parser that accepts only known keys and rejects
  shell metacharacters, duplicate keys, invalid types, and unexpected lines.
- Split privileged state into a root-owned file under `/etc/joininbox/` and keep
  user preferences in the home directory.
- Write configuration atomically with a restrictive umask and explicit owner and
  mode.

Acceptance criteria: values such as command substitutions, redirections, shell
functions, and additional statements are rejected and never executed.

### 3. Update authenticity is not enforced (critical)

Affected code: `updateJoininBox()` in `scripts/_functions.sh` pulls a moving
branch and copies its scripts into `/home/joinmarket` without calling
`verify.git.sh`. Those scripts can subsequently request privileged operations.

Recommendation:

- Normal updates must select an immutable release tag or full commit ID.
- Verify the selected tag/commit against a bundled allowlist of full signing-key
  fingerprints before copying or executing files.
- Perform verification in a fresh temporary keyring; do not trust keys already
  present in the user's GnuPG home.
- Make development-branch and pull-request installation an explicit unsafe/test
  mode that cannot install privileged helpers.
- Build and publish signed, reproducible release manifests containing hashes of
  installed files.

Acceptance criteria: an unsigned commit, an unexpected signing key, a short or
ambiguous object ID, and a moved tag all fail closed before installed files are
changed.

### 4. Bootstrap script is downloaded from a moving branch (high)

Affected documentation and CI download `build_joininbox.sh` from `master` and
execute it as root. Verification performed later by that script cannot establish
the authenticity of code already executing.

Recommendation: publish a minimal versioned bootstrap with a detached signature,
document verification using a fingerprint distributed through an independent
channel, and execute only after successful verification. Prefer signed release
images with reproducible build metadata.

### 5. Shared initial password and early SSH exposure (high)

Affected code sets the password `joininbox` for `root`, `joinmarket`, and `pi`,
while the firewall allows TCP port 22.

Recommendation:

- Lock password authentication and keep SSH blocked until first-boot setup is
  complete.
- Generate a unique random bootstrap secret locally or require console entry.
- Use SSH keys by default and keep root login disabled.
- Use independent credentials for different accounts; remove unused accounts.

Acceptance criteria: a newly flashed node is not remotely accessible with a
credential shared by every image.

### 6. Shell and systemd-unit injection (medium)

Affected code: `scripts/start.service.sh` interpolates `script` and `wallet` into
`/bin/sh -c` and into a systemd unit filename.

Recommendation:

- Remove `/bin/sh -c` and invoke a fixed, root-owned wrapper with separate argv
  entries.
- Restrict script identifiers to an explicit allowlist and wallet arguments to
  canonical files below the wallet directory.
- Use a fixed service name or escaped systemd instance identifiers.
- Quote all expansions and terminate option parsing with `--` where supported.

### 7. Wallet password temporary file (medium)

Affected code uses the predictable path `/dev/shm/.pw`, creates it non-atomically,
and changes `/dev/shm` to mode `0777` rather than the normal sticky `1777`.

Recommendation:

- Never change `/dev/shm` away from `1777`.
- Prefer systemd credentials (`LoadCredential=`) or an anonymous pipe.
- If a file is unavoidable, create a private runtime directory with mode `0700`
  and use `mktemp`, `umask 077`, `O_NOFOLLOW`, and exclusive creation.
- Do not depend on `shred` for tmpfs; unlink promptly and limit lifetime instead.

### 8. Passwords accepted through command-line arguments (medium)

Affected code: `scripts/set.password.sh` accepts a plaintext password as `$1` and
sets the same password on multiple accounts.

Recommendation: accept secrets through a terminal prompt or protected file
descriptor, never argv. Set independent account credentials and use PAM's normal
password-quality policy.

### 9. Unsafe Tor configuration editing (medium)

Affected code: `scripts/install.hiddenservice.sh` interpolates service names and
ports into `sed` and `torrc`, temporarily uses a world-writable file, and changes
`/etc/tor/torrc` ownership to `bitcoin:bitcoin`.

Recommendation:

- Require service names matching a conservative identifier expression and ports
  in the range 1-65535.
- Write a dedicated root-owned file below `/etc/tor/torrc.d/` using `mktemp` in
  that directory, validate with `tor --verify-config`, then atomically rename it.
- Keep all Tor configuration owned by root and avoid signal-by-process-name.

## Staged rollout

### Phase 1: break the root-escalation chain

1. Replace `NOPASSWD:ALL` with narrowly scoped root-owned helpers.
2. Stop sourcing `joinin.conf` in every privileged path.
3. Disable SSH until first-boot credential setup completes.
4. Fail closed on unverified JoininBox updates.

### Phase 2: remove injection and credential hazards

1. Replace dynamic systemd unit generation and `/bin/sh -c`.
2. Replace `/dev/shm/.pw` with systemd credentials or a pipe.
3. Validate Tor service identifiers, ports, wallet paths, version strings, and PR
   numbers.
4. Remove password-through-argv support and shared account passwords.

### Phase 3: defense in depth and release engineering

1. Expand systemd hardening with service-specific write paths, syscall/address
   family restrictions, and capability bounding.
2. Add ShellCheck, secret scanning, dependency review, and a security-focused test
   suite to CI.
3. Produce signed reproducible images and publish a release provenance manifest.
4. Add a documented vulnerability-reporting process and supported-version policy.

## Suggested regression tests

- A compromised `joinmarket` account cannot obtain root through sudo.
- Shell syntax inserted into either configuration file is rejected, not executed.
- Updates signed by an unknown key or left unsigned fail without changing files.
- SSH is unreachable until setup finishes and no image-wide password works.
- Service names containing separators, whitespace, paths, or shell syntax fail.
- Symlinks cannot redirect temporary credentials or Tor configuration writes.
- A failed update or configuration validation preserves the previous working state.

## Review scope and limitations

The review combined manual source analysis, shell syntax checks, and common secret
pattern searches. No committed private keys or common token formats were found,
and all shell files passed `bash -n`. ShellCheck, Semgrep, and dependency/security
alert results were not available in the review environment, so those checks should
be added before treating this plan as exhaustive.
