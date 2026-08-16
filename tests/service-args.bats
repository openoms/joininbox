#!/usr/bin/env bats

setup() {
  FUNCTIONS="$BATS_TEST_DIRNAME/../scripts/_functions.sh"
  WALLET_DIR="$BATS_TEST_TMPDIR/wallets"
  mkdir -p "$WALLET_DIR"
  walletPath="$WALLET_DIR/"
  sed -n '/^function validateServiceArgs()/,/^}/p' "$FUNCTIONS" >"$BATS_TEST_TMPDIR/service-args.sh"
  source "$BATS_TEST_TMPDIR/service-args.sh"
}

@test "accepts only the supported service and canonicalizes its wallet" {
  wallet="$WALLET_DIR/wallet.jmdat"
  touch "$wallet"
  run validateServiceArgs yg-privacyenhanced "$wallet"
  [ "$status" -eq 0 ]
  [ "$output" = "$(readlink -f "$wallet")" ]
}

@test "rejects unsupported service names before using the wallet" {
  wallet="$WALLET_DIR/wallet.jmdat"
  touch "$wallet"
  run validateServiceArgs 'yg-privacyenhanced;id' "$wallet"
  [ "$status" -eq 1 ]
  [[ "$output" == *'Refusing unsupported service'* ]]
}

@test "rejects symlinks and files outside the wallet directory" {
  outside="$BATS_TEST_TMPDIR/outside.jmdat"
  link="$WALLET_DIR/link.jmdat"
  touch "$outside"
  ln -s "$outside" "$link"
  run validateServiceArgs yg-privacyenhanced "$link"
  [ "$status" -eq 1 ]
  [[ "$output" == *'Refusing a symlink'* ]]

  run validateServiceArgs yg-privacyenhanced "$outside"
  [ "$status" -eq 1 ]
  [[ "$output" == *'directly inside'* ]]
}

@test "rejects missing, nested and unsafe wallet names" {
  mkdir -p "$WALLET_DIR/nested"
  touch "$WALLET_DIR/nested/wallet.jmdat" "$WALLET_DIR/bad name.jmdat"
  run validateServiceArgs yg-privacyenhanced "$WALLET_DIR/missing.jmdat"
  [ "$status" -eq 1 ]
  run validateServiceArgs yg-privacyenhanced "$WALLET_DIR/nested/wallet.jmdat"
  [ "$status" -eq 1 ]
  run validateServiceArgs yg-privacyenhanced "$WALLET_DIR/bad name.jmdat"
  [ "$status" -eq 1 ]
  [[ "$output" == *'unsafe wallet filename'* ]]
}
