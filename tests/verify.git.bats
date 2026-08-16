#!/usr/bin/env bats

SCRIPT="$BATS_TEST_DIRNAME/../scripts/verify.git.sh"
FPR='13C688DB5B9C745DE4D2E4545BFB77609B081B65'

setup() {
  BIN="$BATS_TEST_TMPDIR/bin"
  CALLS="$BATS_TEST_TMPDIR/calls"
  mkdir -p "$BIN"
  : >"$CALLS"

  cat >"$BIN/wget" <<'EOF'
#!/bin/bash
printf 'PUBLIC KEY\n' >"$3"
EOF
  cat >"$BIN/gpg" <<'EOF'
#!/bin/bash
if [[ "$*" == *'--show-keys'* ]]; then
  printf '%s\n' "${KEY_FINGERPRINT:-$EXPECTED_FPR}"
fi
exit 0
EOF
  cat >"$BIN/git" <<'EOF'
#!/bin/bash
printf 'git %s\n' "$*" >>"$CALLS"
if [ "$1" = log ]; then
  printf 'abc123 signed commit\n'
  exit 0
fi
printf '%s\n' "${VALIDSIG:-[GNUPG:] VALIDSIG $EXPECTED_FPR 2026 0 4 0 1 10 00 $EXPECTED_FPR}"
exit "${VERIFY_EXIT:-0}"
EOF
  chmod +x "$BIN"/*
  export PATH="$BIN:$PATH" CALLS EXPECTED_FPR="$FPR"
}

@test "verifies a commit with the exact pinned fingerprint and --raw" {
  run bash "$SCRIPT" openoms https://example.test/key "$FPR"
  [ "$status" -eq 0 ]
  [[ "$output" == *"abc123 commit is correct"* ]]
  grep -q '^git verify-commit abc123 --raw$' "$CALLS"
}

@test "accepts a signing subkey when VALIDSIG binds it to the pinned primary key" {
  export VALIDSIG="[GNUPG:] VALIDSIG AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA 2026 0 4 0 1 10 00 $FPR"
  run bash "$SCRIPT" openoms https://example.test/key "$FPR" v1.2.3
  [ "$status" -eq 0 ]
  grep -q '^git verify-tag v1.2.3 --raw$' "$CALLS"
}

@test "rejects a valid signature made by a different key" {
  export VALIDSIG='[GNUPG:] VALIDSIG AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA 2026 0 4 0 1 10 00 BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB'
  run bash "$SCRIPT" openoms https://example.test/key "$FPR"
  [ "$status" -eq 1 ]
  [[ "$output" == *"verify(0)"* ]]
}

@test "rejects a failed git verification even when output names the pinned key" {
  export VERIFY_EXIT=1
  run bash "$SCRIPT" openoms https://example.test/key "$FPR"
  [ "$status" -eq 1 ]
  [[ "$output" == *"signature(0)"* ]]
}

@test "rejects a downloaded key that lacks the pinned fingerprint" {
  export KEY_FINGERPRINT='BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB'
  run bash "$SCRIPT" openoms https://example.test/key "$FPR"
  [ "$status" -eq 7 ]
  [[ "$output" == *"fingerprint is not as expected"* ]]
}
