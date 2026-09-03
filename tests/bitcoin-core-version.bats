#!/usr/bin/env bats

SCRIPT="$BATS_TEST_DIRNAME/../scripts/_functions.bitcoincore.sh"

@test "standalone installer pins Bitcoin Core 31.1" {
  grep -Fq 'bitcoinVersion="31.1"' "$SCRIPT"
  ! grep -Fq 'bitcoinVersion="29.2"' "$SCRIPT"
}

@test "release downloads use the pinned version for signed manifests and binaries" {
  grep -Fq 'bitcoin-core-${bitcoinVersion}/SHA256SUMS' "$SCRIPT"
  grep -Fq 'bitcoin-core-${bitcoinVersion}/SHA256SUMS.asc' "$SCRIPT"
  grep -Fq 'bitcoin-core-${bitcoinVersion}/${binaryName}' "$SCRIPT"
  grep -Fq 'binaryName="bitcoin-${bitcoinVersion}-${bitcoinOSversion}.tar.gz"' "$SCRIPT"
}

@test "all JoininBox-supported v31.1 Linux architectures remain mapped" {
  grep -Fq 'bitcoinOSversion="arm-linux-gnueabihf"' "$SCRIPT"
  grep -Fq 'bitcoinOSversion="aarch64-linux-gnu"' "$SCRIPT"
  grep -Fq 'bitcoinOSversion="x86_64-linux-gnu"' "$SCRIPT"
}

@test "signed manifest lookup requires an exact artifact filename" {
  grep -Fq 'awk -v name="${binaryName}" '\''$2 == name {print $1; exit}'\'' SHA256SUMS' "$SCRIPT"
  ! grep -Fq 'grep -i "${binaryName}" SHA256SUMS' "$SCRIPT"
}

@test "post-install smoke check accepts daemon-specific version output" {
  grep -Fq "grep -Eq '^Bitcoin Core (daemon )?version v?[0-9]+(\\.[0-9]+)+'" "$SCRIPT"
}

@test "signature verification precedes binary checksum acceptance" {
  signature_line="$(grep -n 'gpg --verify SHA256SUMS.asc' "$SCRIPT" | head -n1 | cut -d: -f1)"
  checksum_line="$(grep -n 'binaryChecksum=' "$SCRIPT" | head -n1 | cut -d: -f1)"
  [ "$signature_line" -lt "$checksum_line" ]
}
