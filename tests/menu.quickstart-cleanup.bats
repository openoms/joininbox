#!/usr/bin/env bats

setup() {
  TEST_ROOT="$BATS_TEST_TMPDIR/root"
  MOCK_BIN="$TEST_ROOT/bin"
  mkdir -p "$MOCK_BIN"
  export PATH="$MOCK_BIN:$PATH"

  cat >"$MOCK_BIN/wallet-tool" <<'EOF'
#!/bin/bash
printf '0.00000000\tnew-address\n'
EOF
  cat >"$MOCK_BIN/qrencode" <<'EOF'
#!/bin/bash
exit 0
EOF
  cat >"$MOCK_BIN/shred" <<'EOF'
#!/bin/bash
exit 0
EOF
  chmod +x "$MOCK_BIN"/*

  # Load only the function under test, replacing its absolute service path
  # with the harmless wallet-tool fixture above.
  sed -n '/^function cacheAndShowQR()/,/^}/p' \
    "$BATS_TEST_DIRNAME/../scripts/menu.quickstart.sh" |
    sed "s#/home/joinmarket/start.script.sh#$MOCK_BIN/wallet-tool#" >"$TEST_ROOT/function.sh"
  source "$TEST_ROOT/function.sh"
}

@test "removes only the wallet, mixdepth and function-owned cache" {
  wallet="$TEST_ROOT/wallet"
  mixdepth="$TEST_ROOT/mixdepth"
  sentinel="/dev/shm/joininbox-quickstart-sentinel.$$"
  touch "$wallet" "$mixdepth" "$sentinel"

  run cacheAndShowQR
  [ "$status" -eq 0 ]
  [ ! -e "$wallet" ]
  [ ! -e "$mixdepth" ]
  [ -e "$sentinel" ]
  rm -f "$sentinel"
}

@test "handles an empty optional mixdepth without glob deletion" {
  wallet="$TEST_ROOT/wallet"
  mixdepth=""
  sentinel="/dev/shm/joininbox-quickstart-sentinel.$$"
  touch "$wallet" "$sentinel"

  run cacheAndShowQR
  [ "$status" -eq 0 ]
  [ ! -e "$wallet" ]
  [ -e "$sentinel" ]
  rm -f "$sentinel"
}
