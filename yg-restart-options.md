# Optional remote YubiKey session-unlocked restart for yg-privacyenhanced

This document explains the security principles and tradeoffs around one specific optional restart design for `yg-privacyenhanced`.

The design in scope is:

* keep the current manual password flow available
* add an optional session-unlocked restart mode
* use a YubiKey attached to a separate trusted machine
* reach that YubiKey over SSH for a manual unlock step after boot
* allow automatic restart only within the same boot session

The important point is that this should stay optional.
Not every JoininBox user wants automatic restart behavior.
Not every user has a YubiKey or wants to depend on GPG, `pass`, or any other external secret manager.

The current behavior and its security properties should remain available as the default or stricter mode.

## Why this is not a simple restart flag

Today the wallet password is entered manually, written temporarily to `/dev/shm/.pw`, piped once into JoinMarket with `--wallet-password-stdin`, then shredded.

That gives a clear property:

* there is no reusable wallet password stored on persistent disk on the JoininBox machine

But it also means a clear limitation:

* if `yg-privacyenhanced` crashes or the machine reboots, there is no password source left for an automatic restart

Enabling `Restart=always` in systemd is not enough on its own.
The service still needs a way to get the wallet password again.

## Security principles

Any restart design should keep these principles explicit:

1. Plaintext wallet passwords should not be stored on persistent disk.
2. A named pipe can protect the delivery path, but it does not solve where the secret comes from.
3. Restart after a process crash is a different problem from restart after a full reboot.
4. Physical theft of a powered off machine is a different threat from compromise of a running unlocked machine.
5. Convenience always comes from introducing some reusable secret handling path, and that changes the threat model.

## Named pipes help, but only for delivery

The `lnd` example with `mkfifo` is a good pattern for one part of the problem.
A FIFO lets a password be passed to a process without writing the plaintext to an ordinary file on disk.

That is useful.
It narrows exposure during startup.

But a FIFO does not remove the need for a password source.
If the service crashes later and must restart automatically, something still needs to provide the password again.
That "something" is the real design decision.

## Modes

### Mode 1: current manual password entry

This is the current JoininBox model.

How it works:

* the operator enters the wallet password manually
* the password is kept only in temporary memory-backed storage long enough to start the service
* the temporary file is shredded after use

Properties:

* strongest protection against reusable secret storage on the JoininBox host
* no dependency on YubiKey, GPG, `pass`, or another password manager
* simplest mental model

Tradeoffs:

* no unattended restart after crash
* no unattended restart after reboot
* the operator must be present to start the Yield Generator again

This should remain available for users who prefer the stricter security posture.

### Mode 2: optional remote session-unlocked restart mode

This is the only restartable mode in scope here.
It is intended for crash restart within the same boot session without supporting unattended restart after reboot.

How it would work:

* the wallet password is enrolled once into an encrypted blob stored on disk
* the blob is encrypted to a GPG key whose private key stays on a YubiKey attached to a separate trusted machine
* after boot, the operator opens an SSH session to perform one manual unlock step with YubiKey touch or PIN
* that unlock step releases or derives a runtime-only secret on JoininBox for the current boot session
* service starts and later same-boot restarts use that boot-session runtime secret locally
* plaintext is still delivered through a FIFO or another short-lived runtime-only mechanism

Properties:

* still no plaintext wallet password stored on persistent disk
* the YubiKey does not need to be physically attached to the JoininBox machine
* better protection if the machine is stolen while powered off
* supports automatic restart after a crash in the same boot session
* keeps reboot behavior manual by design

Tradeoffs:

* this is weaker than Mode 1 once the boot session has been unlocked
* a compromised running JoininBox host may be able to use the boot-session secret or otherwise abuse the unlocked restart path
* the trust boundary now includes the remote helper machine, the SSH path, and the unlock workflow
* if the SSH forwarding or remote agent exposure is left open too broadly, the remote key can be abused as a decryption oracle
* adds operational complexity around GPG, smartcard support, SSH policy, agent behavior, and recovery procedures
* depends on extra hardware or software that not every user wants

This mode should be opt-in.
It should not replace the current behavior for everyone.

## Why use a remote YubiKey over SSH

A remote YubiKey can be a reasonable fit if the operator does not want to attach the hardware token directly to JoininBox.

In this design:

* the encrypted secret can be stored on disk on JoininBox
* the private key material stays on the YubiKey attached to a separate trusted machine
* the operator can require a touch or PIN when performing the post-boot unlock step over SSH

That is useful for protecting the encrypted secret while JoininBox is powered off.

But this is not a free security win.
Compared with the current manual-only design, the running system becomes more trusted after the boot session has been unlocked.
Compared with a locally attached YubiKey, the trust boundary also grows to include the helper machine and the SSH-mediated unlock path.

## Recommended shape of the remote unlock

The safest shape for this remote model is:

1. JoininBox stores only an encrypted password blob at rest.
2. After reboot, the operator manually opens an SSH session to a trusted helper machine that has the YubiKey attached.
3. The operator confirms the unlock with touch or PIN.
4. The unlock operation creates only a boot-session runtime secret on JoininBox.
5. The SSH session and any forwarding used for the unlock are closed immediately after the runtime secret is in place.
6. Later same-boot restarts happen locally on JoininBox without needing a continuously open SSH channel.

This keeps the remote YubiKey in the loop only for the manual post-boot unlock.
That is narrower and safer than leaving agent access or SSH forwarding open for the entire session.

## Comparison: local YubiKey and remote YubiKey with fresh FIFOs

If the goal is to avoid a long-lived plaintext password file and instead decrypt into a fresh FIFO whenever the service starts, there are two main shapes to compare.

### Local YubiKey + fresh FIFO on each restart

How it works:

1. JoininBox stores only an encrypted password blob at rest.
2. The YubiKey is physically attached to JoininBox.
3. On each service start or restart, JoininBox decrypts the blob locally.
4. The decrypted password is written directly into a newly created FIFO.
5. `yg-privacyenhanced` reads the password from the FIFO and starts.

What it improves:

* there is no long-lived plaintext password file on disk or in `/run`
* the trust boundary stays smaller because the decrypt path is local to JoininBox and the attached YubiKey
* there is no network dependency for restart-time decrypt

What it does not improve:

* the plaintext still exists transiently in RAM during decrypt, in the kernel pipe buffer, and in the receiving process
* unattended same-boot restart still requires JoininBox to have a locally usable decrypt capability after boot
* that usually means smartcard authorization caching, relaxed touch policy, or another locally unlocked agent state

Main tradeoff:

* this is usually the simpler and safer of the two fresh-FIFO designs if a locally attached token is acceptable
* but it still creates a locally usable decrypt path for the duration of the unlocked session

### Remote YubiKey over SSH + fresh FIFO on each restart

How it works:

1. JoininBox stores only an encrypted password blob at rest.
2. The YubiKey is attached to a separate trusted helper machine.
3. On each service start or restart, JoininBox reaches the helper over SSH or an equivalent forwarded agent path.
4. The helper uses the YubiKey-backed key to decrypt.
5. The decrypted password is streamed into a newly created FIFO for `yg-privacyenhanced`.

What it improves:

* the YubiKey remains physically separate from JoininBox
* if JoininBox is stolen while powered off, the token is elsewhere
* there is no long-lived plaintext password file on JoininBox between restarts

What it does not improve:

* the plaintext still exists transiently in RAM during decrypt and pipe delivery
* unattended same-boot restart still requires a remotely usable decrypt path after boot
* that usually means an open forwarded agent, cached authorization, or another remote helper policy that stays available

Main tradeoff:

* this removes one local artifact but creates a larger live attack surface
* the trust boundary now includes JoininBox, the helper host, the SSH path, and the forwarding or agent behavior
* it is usually more fragile operationally because restart depends on remote host health and session continuity

### Direct comparison

Local YubiKey is usually better when:

* you want the smallest trust boundary
* you want fewer moving parts and better restart reliability
* you can tolerate the token being physically attached to JoininBox

Remote YubiKey is usually only better when:

* physical separation of the token matters more than simplicity
* you are willing to trust and operate a second hardened machine
* you accept a larger attack surface and more operational failure modes

The important point is that a fresh FIFO improves password delivery hygiene in both models, but it does not keep the plaintext entirely out of RAM and it does not remove the need for an unlocked decrypt capability.

## Discouraged patterns

The following patterns are outside the intended model and materially weaken it:

* leaving SSH agent or GPG forwarding open for the whole boot session
* letting JoininBox directly ask the remote helper to decrypt on every restart
* running an always-on remote broker that automatically approves decrypt requests
* enabling unattended restart after reboot through the remote helper

Those approaches move the design closer to an always-on secret-release service.
That is a different and weaker security model than the optional session-unlocked mode described here.

## Out of scope

The following are not in scope for this document:

* unattended restart after reboot
* a permanently connected remote decryption service
* a claim that remote YubiKey over SSH preserves exactly the same security properties as the current manual-only mode

## Recommended position for JoininBox

If this capability is added, the safest way to present it is:

* keep the current ephemeral password entry flow available
* make the remote YubiKey over SSH restartable mode explicitly optional
* support automatic restart after crash within the same boot session
* require a manual unlock step after reboot
* document clearly that this improves convenience and powered-off theft resistance, but weakens the current no-reusable-secret posture once the session is unlocked
* document clearly that the remote helper machine and SSH unlock path become part of the trusted computing base

## Who should choose which mode

Choose Mode 1 if:

* you want the simplest and strictest model
* you do not want any reusable secret path on the host
* you are comfortable manually starting the Yield Generator

Choose Mode 2 if:

* you want automatic recovery from crashes during the same boot session
* you accept one manual unlock step after reboot
* you are comfortable managing a helper machine, SSH trust, a YubiKey, GPG, and backup or recovery procedures
* you accept that the helper machine becomes part of the trust boundary

## Short version

Named pipes are useful, but they only protect password delivery.
Automatic restart requires a reusable password source.
In this design, that source is unlocked manually after reboot through a YubiKey attached to a separate trusted machine over SSH, then reduced to a local boot-session secret on JoininBox.
That can be a reasonable optional compromise, but it cannot preserve the exact same security properties as the current manual-only model.

That is why any restartable YG design should remain optional.