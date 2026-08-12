#!/bin/bash

# command info
if [ $# -lt 3 ] || [ "$1" = "-h" ] || [ "$1" = "-help" ]; then
  echo "script use to verify a git commit or tag"
  echo "Usage:"
  echo "Run after 'git reset --hard VERSION' with the user running the installation"
  echo "To verify the checked out commit:"
  echo "verify.git.sh [PGPsigner] [PGPpubkeyLink] [PGPpubkeyFingerprint]"
  echo "To use 'git verify-tag' add the 'tag':"
  echo "verify.git.sh [PGPsigner] [PGPpubkeyLink] [PGPpubkeyFingerprint] <tag>"
  exit 1
fi

# Example for commits created on GitHub:
# PGPsigner="web-flow"
# PGPpubkeyLink="https://github.com/${PGPsigner}.gpg"
# PGPpubkeyFingerprint="B5690EEEBB952194"

# Example for commits signed with a personal PGP key:
# PGPsigner="janoside"
# PGPpubkeyLink="https://github.com/${PGPsigner}.gpg"
# PGPpubkeyFingerprint="F579929B39B119CC7B0BB71FB326ACF51F317B69"

# Run with the installing user to clear permissions:
# sudo -u btcrpcexplorer /home/admin/config.scripts/verify.git.sh \
#  "${PGPsigner}" "${PGPpubkeyLink}" "${PGPpubkeyFingerprint}" || exit 1

PGPsigner="$1"
PGPpubkeyLink="$2"
PGPpubkeyFingerprint="$3"

_temp_dir="$(mktemp -d -p /dev/shm/ 2>/dev/null || mktemp -d)"
trap 'rm -rf "$_temp_dir"' EXIT

keyFile="${_temp_dir}/pgp_keys_${PGPsigner}.asc"
rawKeyFile="${keyFile}.raw"

wget --prefer-family=ipv4 -O "${rawKeyFile}" "${PGPpubkeyLink}"
# GitHub can add a Note: armor header when an account key cannot be exported.
# GPG imports the key anyway, but prints a misleading "unknown armor header".
grep -v '^Note: ' "${rawKeyFile}" >"${keyFile}"
gpg --quiet --import --import-options show-only "${keyFile}"
fingerprint=$(gpg --show-keys --with-subkey-fingerprint "${keyFile}" 2>/dev/null | tr -d " \t\n\r" | grep "${PGPpubkeyFingerprint}" -c)
if [ "${fingerprint}" -lt 1 ]; then
  echo
  echo "# WARNING --> the PGP fingerprint is not as expected for ${PGPsigner}" >&2
  echo "# Should contain PGP: ${PGPpubkeyFingerprint}" >&2
  echo "# Exiting" >&2
  exit 7
fi
gpg --quiet --import "${keyFile}"

_temp="${_temp_dir}/git-verify.out"

if [ $# -eq 3 ] || [ -z "$4" ]; then
  commitHash="$(git log --oneline | head -1 | awk '{print $1}')"
  gitCommand="git verify-commit $commitHash"
  commitOrTag="$commitHash commit"
elif [ $# -eq 4 ] && [ -n "$4" ]; then
  gitCommand="git verify-tag $4"
  commitOrTag="$4 tag"
fi
echo "# running: ${gitCommand}"
# --raw includes GnuPG's machine-readable VALIDSIG record with the complete
# signing-key fingerprint. Do not authenticate signatures using a short key ID.
if ${gitCommand} --raw >"$_temp" 2>&1; then
  goodSignature=1
else
  goodSignature=0
fi
echo
cat "$_temp"
echo "# goodSignature(${goodSignature})"

correctKey=$(grep -F "[GNUPG:] VALIDSIG ${PGPpubkeyFingerprint} " "$_temp" -c)
echo "# correctKey(${correctKey})"

if [ "${correctKey}" -lt 1 ] || [ "${goodSignature}" -lt 1 ]; then
  echo
  echo "# BUILD FAILED --> PGP verification not OK / signature(${goodSignature}) verify(${correctKey})"
  exit 1
else
  echo
  echo "##########################################################################"
  echo "# OK --> the PGP signature of the checked out ${commitOrTag} is correct"
  echo "##########################################################################"
  echo
  exit 0
fi
