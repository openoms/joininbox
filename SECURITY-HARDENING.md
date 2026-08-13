# JoininBox security hardening plan

This document records the findings of a source review of JoininBox and proposes
a staged remediation plan. The original review covered commit
`54473190c8278a023049f87ea4c5520fb26425e2`; a follow-up scan on 2026-08-13
re-verified every finding against the current default branch
(`16fc83f`, PR #177) and added two findings (#10 and #11).
JoininBox handles wallet credentials and installs system services, so its
security boundary should assume that network-facing applications and the
unprivileged `joinmarket` account can be compromised.

## Implementation PRs

Work on the plan has started as small, independently reviewable PRs:

| PR | Finding | Scope |
|----|---------|-------|
| #187 | #7 | Harden wallet credential temp files (`/dev/shm/.pw`, restrictive modes) |
| #188 | #9 | Validate and atomically install Tor hidden-service configuration |
| #189 | #6 | Constrain generated wallet service inputs (script/wallet allowlists) |
| #190 | #3, #4 | Verify JoininBox updates against pinned signing keys before install |

The critical privilege-escalation findings (#1, #2) and the first-boot
credential finding (#5) are not yet addressed by an implementation PR.

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

Status: open, no implementation PR yet.

### 2. User-writable configuration is sourced as shell code (critical)

Affected code: many scripts, including `scripts/install.hiddenservice.sh`, use
`source /home/joinmarket/joinin.conf`. The file is created as `joinmarket` and is
modified by user-facing scripts. The 2026-08-13 re-scan counted 20+ scripts
sourcing the file.

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

Status: open, no implementation PR yet.

### 3. Update authenticity is not enforced (critical)

Affected code: `updateJoininBox()` in `scripts/_functions.sh` pulls a moving
branch and copies its scripts into `/home/joinmarket` without calling
`verify.git.sh`. Those scripts can subsequently request privileged operations.
(Re-verified 2026-08-13: `verify.git.sh` is used for JoinMarket and Jam
installs, but never for JoininBox self-updates.)

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

Status: implementation in progress — PR #190.

### 4. Bootstrap script is downloaded from a moving branch (high)

Affected documentation and CI download `build_joininbox.sh` from `master` and
execute it as root. Verification performed later by that script cannot establish
the authenticity of code already executing.

Recommendation: publish a minimal versioned bootstrap with a detached signature,
document verification using a fingerprint distributed through an independent
channel, and execute only after successful verification. Prefer signed release
images with reproducible build metadata.

Status: partially covered by PR #190 (pinned verification helpers in the build
script); versioned signed bootstrap still open.

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

Status: open, no implementation PR yet.

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

Status: implementation in progress — PR #189.

### 7. Wallet password temporary file (medium)

Affected code uses the predictable path `/dev/shm/.pw`, creates it non-atomically,
and changes `/dev/shm` to mode `0777` rather than the normal sticky `1777`
(`build_joininbox.sh`).

Recommendation:

- Never change `/dev/shm` away from `1777`.
- Prefer systemd credentials (`LoadCredential=`) or an anonymous pipe.
- If a file is unavoidable, create a private runtime directory with mode `0700`
  and use `mktemp`, `umask 077`, `O_NOFOLLOW`, and exclusive creation.
- Do not depend on `shred` for tmpfs; unlink promptly and limit lifetime instead.

Status: implementation in progress — PR #187.

### 8. Passwords accepted through command-line arguments (medium)

Affected code: `scripts/set.password.sh` accepts a plaintext password as `$1` and
sets the same password on multiple accounts.

Recommendation: accept secrets through a terminal prompt or protected file
descriptor, never argv. Set independent account credentials and use PAM's normal
password-quality policy.

Status: open, no implementation PR yet.

### 9. Unsafe Tor configuration editing (medium)

Affected code: `scripts/install.hiddenservice.sh` interpolates service names and
ports into `sed` and `torrc`, temporarily uses a world-writable file
(`chmod 777 /home/joinmarket/tmp`), and changes `/etc/tor/torrc` ownership to
`bitcoin:bitcoin`.

Recommendation:

- Require service names matching a conservative identifier expression and ports
  in the range 1-65535.
- Write a dedicated root-owned file below `/etc/tor/torrc.d/` using `mktemp` in
  that directory, validate with `tor --verify-config`, then atomically rename it.
- Keep all Tor configuration owned by root and avoid signal-by-process-name.

Status: implementation in progress — PR #188.

### 10. `eval`-based argument parsing (medium) — new in 2026-08-13 scan

Affected code: `assign_value()`, `get_arg()`, and `range_argument()` in
`scripts/install.joinmarket.sh` build and run `eval "${1}"="\"${value}\""` and
`eval var='$'"${1}"` on caller-controlled names and values.

Impact: a crafted option name or value reaching these helpers executes arbitrary
shell. The install script runs privileged operations, so injection here can
escalate beyond the intended install steps.

Recommendation:

- Replace `eval` with `printf -v "${1}" '%s' "${value}"` (after validating the
  variable name against `[a-zA-Z_][a-zA-Z0-9_]*`) or with indirect expansion
  `${!name}` for reads.
- Reject option names and values that fail an explicit allowlist before any
  assignment.

Acceptance criteria: option names containing shell syntax, spaces, or
substitutions are rejected; no `eval` remains on user-controlled input.

Status: open, no implementation PR yet.

### 11. Root wildcard deletion in a world-writable directory (medium) — new in 2026-08-13 scan

Affected code: `scripts/menu.quickstart.sh` runs `sudo rm -f /dev/shm/*` after
displaying wallet data.

Impact: `/dev/shm` is world-writable. A local process can plant entries (or win
a race between glob expansion and unlink) so the root `rm` deletes files it
should not, or turns the cleanup into a denial of service against other
processes' runtime files.

Recommendation:

- Track and delete only the specific `mktemp` files the script created.
- Never glob-delete in shared directories from a privileged context; use a
  private `mktemp -d` directory owned by the calling user instead.

Acceptance criteria: the script unlinks exactly the files it created and no
longer runs `rm` with a wildcard as root.

Status: open, no implementation PR yet.

## Minor observations (2026-08-13 scan)

- `scripts/standalone/install.i2pd.sh` uses the deprecated `apt-key`; move the
  key to a dedicated keyring file referenced by a `signed-by=` source entry.
- `scripts/standalone/bitcoin.update.sh` imports all Bitcoin Core builder keys
  from the `guix.sigs` repository. This matches upstream verification practice,
  but the import should go to a temporary keyring rather than the user's default
  GnuPG home.

## Staged rollout

### Phase 1: break the root-escalation chain

1. Replace `NOPASSWD:ALL` with narrowly scoped root-owned helpers. (finding #1)
2. Stop sourcing `joinin.conf` in every privileged path. (finding #2)
3. Disable SSH until first-boot credential setup completes. (finding #5)
4. Fail closed on unverified JoininBox updates. (finding #3 — PR #190)

### Phase 2: remove injection and credential hazards

1. Replace dynamic systemd unit generation and `/bin/sh -c`. (finding #6 — PR #189)
2. Replace `/dev/shm/.pw` with systemd credentials or a pipe. (finding #7 — PR #187)
3. Validate Tor service identifiers, ports, wallet paths, version strings, and PR
   numbers. (finding #9 — PR #188)
4. Remove password-through-argv support and shared account passwords. (finding #8)
5. Remove `eval`-based argument parsing and wildcard deletions as root.
   (findings #10, #11)

### Phase 3: defense in depth and release engineering

1. Expand systemd hardening with service-specific write paths, syscall/address
   family restrictions, and capability bounding.
2. Add ShellCheck, secret scanning, dependency review, and a security-focused test
   suite to CI.
3. Produce signed reproducible images and publish a release provenance manifest.
4. Add a documented vulnerability-reporting process and supported-version policy
   (see `SECURITY.md`).

## Suggested regression tests

- A compromised `joinmarket` account cannot obtain root through sudo.
- Shell syntax inserted into either configuration file is rejected, not executed.
- Updates signed by an unknown key or left unsigned fail without changing files.
- SSH is unreachable until setup finishes and no image-wide password works.
- Service names containing separators, whitespace, paths, or shell syntax fail.
- Symlinks cannot redirect temporary credentials or Tor configuration writes.
- A failed update or configuration validation preserves the previous working state.
- Option names or values containing shell syntax never reach `eval`.
- Cleanup only removes the exact temporary files the script created.

## Review scope and limitations

The 2026-08-13 re-scan repeated the original review on the current default
branch (`16fc83f`): manual source analysis of privileged install/update paths,
credential handling, Tor/RPC exposure, signature verification, and
shell-injection surfaces; `bash -n` over all shell scripts (all pass); and a
common committed-secret pattern search (no private keys or common token formats
found). ShellCheck, Semgrep, and dependency/security alert results were not
available in the review environment, so those checks should be added before
treating this plan as exhaustive.
