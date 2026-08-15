#!/usr/bin/env bats
# Tests for passwordToFile (scripts/_functions.sh): the wallet password goes
# to an unpredictable, caller-owned, mode-600 file under /dev/shm - never to
# the old fixed /dev/shm/.pw path - and is cleaned up on exit or cancel.
#
# Note: the suite must also pass from a tagless shallow checkout (CI), where
# the git describe in _functions.sh fails - the source guard above covers it.

load helpers/joininbox-env

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
  # dialog mock: --passwordbox writes the entered password to stderr
  cat >"$MOCK_BIN/dialog" <<'EOF'
#!/bin/bash
printf '%s' "${DIALOG_PASSWORD:-}" >&2
exit "${DIALOG_EXIT:-0}"
EOF
  chmod +x "$MOCK_BIN/dialog"
  export MOCK_BIN
  export PATH="$MOCK_BIN:$PATH"
  export DIALOG_PASSWORD="bats-secret-123"
  export DIALOG_EXIT=0
  # '|| true': the version-detection block at the top of _functions.sh runs
  # git describe which fails (128) on a tagless/shallow checkout; without the
  # guard bats' errexit would abort the source before the function definitions
  source /home/joinmarket/_functions.sh || true
}

teardown() {
  rm -rf "$TEST_TMP"
}

@test "creates the password file under the joininbox prefix with mode 600 and the entered content" {
  wallet="$TEST_TMP/wallet.jmdat"
  : >"$wallet"
  passwordToFile
  [[ "$walletPasswordFile" == /dev/shm/joininbox-wallet-password.* ]]
  [ -f "$walletPasswordFile" ]
  [ "$(stat -c '%a' -- "$walletPasswordFile")" = "600" ]
  [ "$(stat -c '%u' -- "$walletPasswordFile")" = "$(id -u)" ]
  [ "$(cat "$walletPasswordFile")" = "bats-secret-123" ]
  # the old fixed path is not used
  [ ! -e /dev/shm/.pw ]
  rm -f "$walletPasswordFile"
}

@test "uses a fresh unpredictable file name on each call" {
  wallet="$TEST_TMP/w1.jmdat"
  : >"$wallet"
  passwordToFile
  first="$walletPasswordFile"
  wallet="$TEST_TMP/w2.jmdat"
  : >"$wallet"
  passwordToFile
  second="$walletPasswordFile"
  [ "$first" != "$second" ]
  [[ "$first" == /dev/shm/joininbox-wallet-password.* ]]
  [[ "$second" == /dev/shm/joininbox-wallet-password.* ]]
  rm -f "$first" "$second"
}

@test "removes the password file when the shell exits (EXIT trap)" {
  f="$(DIALOG_PASSWORD=x bash "$REPO_ROOT/tests/helpers/passwordToFile-harness.sh" "$TEST_TMP/w.jmdat")"
  [[ "$f" == /dev/shm/joininbox-wallet-password.* ]]
  # the harness has exited by now, so the trap must have removed the file
  [ ! -e "$f" ]
}

@test "cancel removes the credential files and exits 1" {
  wallet="$TEST_TMP/w.jmdat"
  : >"$wallet"
  export DIALOG_EXIT=1
  run passwordToFile
  [ "$status" -eq 1 ]
  [[ "$output" == *"Cancelled"* ]]
  [ ! -e "$wallet" ]
}

@test "ESC removes the credential files and exits 1" {
  wallet="$TEST_TMP/w.jmdat"
  : >"$wallet"
  export DIALOG_EXIT=255
  run passwordToFile
  [ "$status" -eq 1 ]
  [ ! -e "$wallet" ]
}
