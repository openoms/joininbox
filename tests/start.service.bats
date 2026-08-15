#!/usr/bin/env bats
# Tests for the credential-file handling in start.service.sh:
# the wallet password is passed via a per-run, caller-owned, mode-600 file
# under /dev/shm/joininbox-wallet-password.* and is validated before any use.

load helpers/joininbox-env

SCRIPT="$REPO_ROOT/scripts/start.service.sh"

setup_file() {
  joininbox_setup_file
}

teardown_file() {
  joininbox_teardown_file
}

setup() {
  TEST_TMP="$(mktemp -d)"
  MOCK_BIN="$TEST_TMP/mockbin"
  mkdir -p "$MOCK_BIN"
  export MOCK_BIN
}

teardown() {
  rm -rf "$TEST_TMP"
  rm -rf /dev/shm/joininbox-wallet-password.bats-trav.d
  rm -f /dev/shm/joininbox-wallet-password.bats* /dev/shm/joininbox-pw-traversal-target
}

# create a valid password file: right prefix, caller-owned, mode 600
make_pwfile() {
  local f
  f="$(mktemp /dev/shm/joininbox-wallet-password.bats.XXXXXX)"
  printf 'bats-secret-password' >"$f"
  chmod 600 "$f"
  printf '%s\n' "$f"
}

# invoke via bash explicitly: works regardless of the exec bit or a noexec mount
@test "rejects a missing password file" {
  run bash "$SCRIPT" yg-privacyenhanced "$TEST_WALLET" /dev/shm/joininbox-wallet-password.bats-does-not-exist
  [ "$status" -eq 1 ]
  [[ "$output" == *"Invalid wallet password file"* ]]
}

@test "rejects a symlinked password file" {
  target="$(make_pwfile)"
  link=/dev/shm/joininbox-wallet-password.bats-link
  ln -sf "$target" "$link"
  run bash "$SCRIPT" yg-privacyenhanced "$TEST_WALLET" "$link"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Invalid wallet password file"* ]]
}

@test "rejects a password file outside the allowed runtime path" {
  outside="$TEST_TMP/pw"
  printf 'x' >"$outside"
  chmod 600 "$outside"
  run bash "$SCRIPT" yg-privacyenhanced "$TEST_WALLET" "$outside"
  [ "$status" -eq 1 ]
  [[ "$output" == *"outside the allowed runtime path"* ]]
}

@test "rejects path traversal in the password file name" {
  target=/dev/shm/joininbox-pw-traversal-target
  printf 'x' >"$target"
  chmod 600 "$target"
  travdir=/dev/shm/joininbox-wallet-password.bats-trav.d
  mkdir -p "$travdir"
  run bash "$SCRIPT" yg-privacyenhanced "$TEST_WALLET" "$travdir/../joininbox-pw-traversal-target"
  [ "$status" -eq 1 ]
  [[ "$output" == *"file name is invalid"* ]]
}

@test "rejects a password file with unsafe owner or mode" {
  pwfile="$(make_pwfile)"
  chmod 644 "$pwfile"
  run bash "$SCRIPT" yg-privacyenhanced "$TEST_WALLET" "$pwfile"
  [ "$status" -eq 1 ]
  [[ "$output" == *"unsafe owner or mode"* ]]
}

@test "validates the password file before the service arguments" {
  pwfile="$(make_pwfile)"
  run bash "$SCRIPT" not-a-real-service "$TEST_WALLET" "$pwfile"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Refusing unsupported service"* ]]
}

@test "passes the password over stdin, keeps it out of the unit and deletes the file after use" {
  # mock sudo: capture the generated unit file and log the systemctl calls
  cat >"$MOCK_BIN/sudo" <<'EOF'
#!/bin/bash
echo "sudo $*" >>"$MOCK_BIN/sudo.log"
if [ "$1" = "tee" ]; then
  cat >"$MOCK_BIN/unit.out"
fi
exit 0
EOF
  chmod +x "$MOCK_BIN/sudo"
  pwfile="$(make_pwfile)"
  export PATH="$MOCK_BIN:$PATH"
  run bash "$SCRIPT" yg-privacyenhanced "$TEST_WALLET" "$pwfile"
  [ "$status" -eq 0 ]
  grep -q "systemctl enable yg-privacyenhanced" "$MOCK_BIN/sudo.log"
  # the unit reads the password file over stdin ...
  grep -q -- "--wallet-password-stdin" "$MOCK_BIN/unit.out"
  grep -q "cat '$pwfile'" "$MOCK_BIN/unit.out"
  # ... and never contains the password itself
  ! grep -q "bats-secret-password" "$MOCK_BIN/unit.out"
  # the password file is deleted once used
  [ ! -e "$pwfile" ]
}
