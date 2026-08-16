#!/usr/bin/env bats

SCRIPT="$BATS_TEST_DIRNAME/../scripts/set.password.sh"

setup() {
  MOCK_BIN="$BATS_TEST_TMPDIR/bin"
  PASSWORD_LOG="$BATS_TEST_TMPDIR/chpasswd.log"
  mkdir -p "$MOCK_BIN"
  : >"$PASSWORD_LOG"
  cat >"$MOCK_BIN/chpasswd" <<'EOF'
#!/bin/bash
cat >>"$PASSWORD_LOG"
EOF
  cat >"$MOCK_BIN/sleep" <<'EOF'
#!/bin/bash
exit 0
EOF
  chmod +x "$MOCK_BIN"/*
  export MOCK_BIN PASSWORD_LOG
  # Exercise the script as an unprivileged test user with chpasswd mocked.
  # Only the root guard is disabled in this fixture; CI separately runs the
  # production script's argument rejection before that guard.
  sed 's/if \[ "$EUID" -ne 0 \]/if false/' "$SCRIPT" >"$BATS_TEST_TMPDIR/set.password-under-test.sh"
}

run_as_root_with_input() {
  local input="$1"
  run bash -c 'printf "%b" "$1" | env PATH="$2:$PATH" PASSWORD_LOG="$3" bash "$4"' \
    _ "$input" "$MOCK_BIN" "$PASSWORD_LOG" "$BATS_TEST_TMPDIR/set.password-under-test.sh"
}

@test "help succeeds and advertises interactive-only use" {
  run bash "$SCRIPT" -help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Interactive only"* ]]
}

@test "refuses every password passed through argv" {
  run bash "$SCRIPT" 'secret-on-command-line'
  [ "$status" -eq 1 ]
  [[ "$output" == *"refusing to take a password"* ]]
  [ ! -s "$PASSWORD_LOG" ]
}

@test "same-password flow sends secrets only to chpasswd stdin" {
  run_as_root_with_input 'y\nstrong-pass-1\nstrong-pass-1\n'
  [ "$status" -eq 0 ]
  grep -q '^joinmarket:strong-pass-1$' "$PASSWORD_LOG"
  grep -q '^root:strong-pass-1$' "$PASSWORD_LOG"
  [[ "$output" != *"strong-pass-1"* ]]
}

@test "rejects mismatch and short input before accepting a valid password" {
  run_as_root_with_input 'y\nfirst-pass\nsecond-pass\nshort\nshort\nstrong-pass-2\nstrong-pass-2\n'
  [ "$status" -eq 0 ]
  [[ "$output" == *"Passwords don't match"* ]]
  [[ "$output" == *"Password length under 8"* ]]
  grep -q '^joinmarket:strong-pass-2$' "$PASSWORD_LOG"
  ! grep -q 'first-pass\|second-pass\|short' "$PASSWORD_LOG"
}

@test "separate-password flow assigns each account independently" {
  # Supply the optional pi account input too; it is consumed only on hosts
  # where that exact account exists.
  run_as_root_with_input 'n\njoinmarket-pass\njoinmarket-pass\nroot-password\nroot-password\npi-password\npi-password\n'
  [ "$status" -eq 0 ]
  grep -q '^joinmarket:joinmarket-pass$' "$PASSWORD_LOG"
  grep -q '^root:root-password$' "$PASSWORD_LOG"
  if compgen -u | grep -qx pi; then
    grep -q '^pi:pi-password$' "$PASSWORD_LOG"
  fi
}
