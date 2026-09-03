#!/usr/bin/env bats

FUNCTIONS="$BATS_TEST_DIRNAME/../scripts/_functions.sh"

setup() {
  BIN="$BATS_TEST_TMPDIR/bin"
  VERIFY_LOG="$BATS_TEST_TMPDIR/verify.log"
  mkdir -p "$BIN"
  cat >"$BIN/git" <<'EOF'
#!/bin/bash
printf '%s\n' "${SIGNATURE_OUTPUT:-unknown signer}"
EOF
  cat >"$BIN/verify" <<'EOF'
#!/bin/bash
printf '%s\n' "$*" >>"$VERIFY_LOG"
exit "${VERIFY_STATUS:-0}"
EOF
  chmod +x "$BIN"/*
  export PATH="$BIN:$PATH" VERIFY_LOG

  sed -n -e '/^function validatePRNumber()/,/^}/p' \
    -e '/^function verifyJoininBoxRef()/,/^}/p' "$FUNCTIONS" |
    sed "s#/home/joinmarket/verify.git.sh#$BIN/verify#" >"$BATS_TEST_TMPDIR/function.sh"
  source "$BATS_TEST_TMPDIR/function.sh"
}

@test "PR numbers are decimal before any fetch refspec is constructed" {
  for number in 1 190 999999; do
    run validatePRNumber "$number"
    [ "$status" -eq 0 ]
  done
  for number in '' -1 1.5 '190/head' '190;id' '--upload-pack=evil'; do
    run validatePRNumber "$number"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Invalid pull-request number"* ]]
  done
  grep -Fq 'validatePRNumber "$2" || return 1' "$FUNCTIONS"
}

@test "tag updates pin the openoms key and pass the tag to verification" {
  run verifyJoininBoxRef v1.2.3 tag
  [ "$status" -eq 0 ]
  grep -q '^openoms https://github.com/openoms.gpg 13C688DB5B9C745DE4D2E4545BFB77609B081B65 v1.2.3$' "$VERIFY_LOG"
}

@test "commit updates select the openoms key from the signed commit" {
  export SIGNATURE_OUTPUT='Good signature 13C688DB5B9C745DE4D2E4545BFB77609B081B65'
  run verifyJoininBoxRef HEAD commit
  [ "$status" -eq 0 ]
  grep -q '^openoms https://github.com/openoms.gpg 13C688DB5B9C745DE4D2E4545BFB77609B081B65$' "$VERIFY_LOG"
}

@test "commit updates expand the NG release key ID to the full pinned fingerprint" {
  export SIGNATURE_OUTPUT='Good signature 44912E1E03005B31'
  run verifyJoininBoxRef HEAD commit
  [ "$status" -eq 0 ]
  grep -q '^joinmarket-ng https://raw.githubusercontent.com/joinmarket-ng/joinmarket-ng/0c3716b53c132bd46fc92d240beebe7158a06e16/signatures/pubkeys/1C53A412D11EF3051704419C44912E1E03005B31.asc 1C53A412D11EF3051704419C44912E1E03005B31$' "$VERIFY_LOG"
}

@test "GitHub commit updates expand the recognized key ID to the full pinned fingerprint" {
  export SIGNATURE_OUTPUT='Good signature B5690EEEBB952194'
  run verifyJoininBoxRef HEAD commit
  [ "$status" -eq 0 ]
  grep -q '^web-flow https://github.com/web-flow.gpg 968479A1AFF927E37D1A566BB5690EEEBB952194$' "$VERIFY_LOG"
}

@test "commit updates fail closed for an unrecognized signer" {
  export SIGNATURE_OUTPUT='Good signature DEADBEEF'
  run verifyJoininBoxRef HEAD commit
  [ "$status" -eq 1 ]
  [[ "$output" == *"Refusing an update"* ]]
  [ ! -s "$VERIFY_LOG" ]
}

@test "PR update UI requires the PR-specific typed confirmation" {
  menu="$BATS_TEST_DIRNAME/../scripts/menu.update.advanced.sh"
  grep -Fq 'Type '\''test PR $PRnumber'\'' to confirm' "$menu"
  grep -Fq '[ "$confirm" != "test PR $PRnumber" ]' "$menu"
  grep -Fq 'installing UNVERIFIED pull-request code' "$FUNCTIONS"
  grep -Fq 'Skipping signature verification for unverified PR code' "$FUNCTIONS"
}

@test "image builds pin GitHub web-flow with its full fingerprint" {
  build="$BATS_TEST_DIRNAME/../build_joininbox.sh"
  grep -Fq 'PGPpubkeyFingerprint="968479A1AFF927E37D1A566BB5690EEEBB952194"' "$build"
  ! grep -Fq 'PGPpubkeyFingerprint="B5690EEEBB952194"' "$build"
}
