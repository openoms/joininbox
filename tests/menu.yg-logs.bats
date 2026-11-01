#!/usr/bin/env bats
# Real menu entrypoint and full _functions.sh, with synthetic logs only.
load helpers/joininbox-env

setup_file() {
  joininbox_setup_file
  # No RPC or wallet operations: replace only the unrelated startup dependency.
  printf 'checkRPCwallet() { :; }\n' | sudo tee "$JM_HOME/_functions.bitcoincore.sh" >/dev/null
  sudo mkdir -p "$JM_HOME/joininbox" "$JM_HOME/joinmarket-clientserver/scripts"
  printf '#!/bin/bash\nexit 0\n' | sudo tee "$JM_HOME/menu.yg.sh" >/dev/null
  sudo chmod +x "$JM_HOME/menu.yg.sh"
}

teardown_file() {
  joininbox_teardown_file
}

setup() {
  TEST_TMP="$(mktemp -d)"
  export TRACE="$TEST_TMP/trace" CHOICE=LOGS
  mkdir -p "$TEST_TMP/bin"
  sudo mkdir -p "$JM_HOME/.joinmarket/logs"
  export LOG_DIR="$JM_HOME/.joinmarket/logs"
  cat > "$TEST_TMP/bin/dialog" <<'EOF'
#!/bin/bash
printf '%s\n' "$@" >> "$TRACE"
case " $* " in *' --menu '*) printf '%s\n' "$CHOICE" >&2;; esac
EOF
  cat > "$TEST_TMP/bin/tail" <<'EOF'
#!/bin/bash
case "$1" in
  -fn1000)
    if [ "${REAL_TAIL:-}" = yes ]; then
      exec timeout 1 /usr/bin/tail "$@"
    fi
    printf 'TAIL'; printf '<%s>' "$@"; printf '\n';;
  *) exec /usr/bin/tail "$@";;
esac
EOF
  cat > "$TEST_TMP/bin/whiptail" <<'EOF'
#!/bin/bash
printf '%s\n' "$@" >> "$TRACE"
EOF
  printf '#!/bin/bash\nexit 0\n' > "$TEST_TMP/bin/sleep"
  # _functions.sh queries versions at import time. Keep those unrelated probes
  # deterministic on clean CI machines without a real checkout or Bitcoin Core.
  printf '#!/bin/bash\nprintf "v0.0.0\\n"\n' > "$TEST_TMP/bin/git"
  printf '#!/bin/bash\nprintf "Bitcoin Core version v0.0.0\\n"\n' > "$TEST_TMP/bin/bitcoind"
  # Process state must not turn an arbitrary newest logfile into a current maker.
  printf '#!/bin/bash\nprintf "4242\\n"\n' > "$TEST_TMP/bin/pgrep"
  chmod +x "$TEST_TMP/bin/"*
  export PATH="$TEST_TMP/bin:$PATH" TERM=xterm
}

teardown() {
  sudo rm -rf "$LOG_DIR"
  rm -rf "$TEST_TMP"
}

make_log() {
  printf '2026-01-01 00:00:00 [MainThread  ] [DEBUG] NickServ a b %s\n' "$2" | sudo tee "$LOG_DIR/$1" >/dev/null
  sudo touch -t "$3" "$LOG_DIR/$1"
}

run_menu() {
  # util-linux script supplies /dev/tty for the production dialog redirection.
  run bash -c 'printf "\n" | script -q -e -c "bash $1/scripts/menu.yg.sh" /dev/null' _ "$REPO_ROOT"
}

@test "LOGS accurately labels the newest log, including an orderbook log" {
  make_log J5-maker.log J5maker 202601010000
  make_log J5-orderbook.log J5orderbook 202601020000
  run_menu
  [ "$status" -eq 0 ]
  [[ "$output" == *"J5-orderbook.log>"* ]]
  grep -q 'View the latest JoinMarket logfile' "$TRACE"
  grep -q 'may belong to the order book' "$TRACE"
}

@test "LOGS still selects a newer maker log" {
  make_log J5-orderbook.log J5orderbook 202601010000
  make_log J5-maker.log J5maker 202601020000
  run_menu
  [ "$status" -eq 0 ]
  [[ "$output" == *"J5-maker.log>"* ]]
}

@test "LOGS preserves spaces and ignores newer directories and non-log files" {
  make_log 'J5 maker.log' J5maker 202601010000
  sudo mkdir "$LOG_DIR/J5-directory.log"
  printf 'not a logfile\n' | sudo tee "$LOG_DIR/J5-notes.txt" >/dev/null
  run_menu
  [ "$status" -eq 0 ]
  [[ "$output" == *"TAIL<-fn1000><--><$LOG_DIR/J5 maker.log>"* ]]
}

@test "LOGS returns without tail when the log directory is empty" {
  run_menu
  [ "$status" -eq 0 ]
  [[ "$output" == *"No JoinMarket logfile found"* ]]
  [[ "$output" != *TAIL* ]]
}

@test "LOGS returns without tail when the log directory is absent" {
  sudo rmdir "$LOG_DIR"
  run_menu
  [ "$status" -eq 0 ]
  [[ "$output" == *"No JoinMarket logfile found"* ]]
  [[ "$output" != *TAIL* ]]
}

@test "nickname uses the same latest log and makes no current maker claim" {
  make_log J5-maker.log J5maker 202601010000
  make_log J5-orderbook.log J5orderbook 202601020000
  export CHOICE=NICKNAME
  run_menu
  [ "$status" -eq 0 ]
  grep -q J5orderbook "$TRACE"
  grep -q 'not proof of a current YG offer' "$TRACE"
}

@test "a stale log remains historical even with a fake running process" {
  make_log J5-old.log J5old 202001010000
  export CHOICE=NICKNAME
  run_menu
  [ "$status" -eq 0 ]
  grep -q J5old "$TRACE"
  grep -q 'not proof of a current YG offer' "$TRACE"
}

@test "nickname retains placeholders for missing and empty logs" {
  run bash -c 'source /home/joinmarket/_functions.sh; YGnickname'
  [ "$status" -eq 0 ]
  [[ "$output" == *waiting__to__run* ]]
  sudo touch "$LOG_DIR/J5-empty.log"
  run bash -c 'source /home/joinmarket/_functions.sh; YGnickname'
  [ "$status" -eq 0 ]
  [[ "$output" == *no_Nick_see_LOGS* ]]
}

@test "nickname keeps its missing-log fallback with errexit enabled" {
  run bash -c 'source /home/joinmarket/_functions.sh; set -e; YGnickname'
  [ "$status" -eq 0 ]
  [[ "$output" == *waiting__to__run* ]]
}

@test "the real tail reads a spaced logfile through the production menu" {
  make_log 'J5 maker.log' J5realTail 202601010000
  export REAL_TAIL=yes
  run_menu
  [ "$status" -eq 0 ]
  [[ "$output" == *J5realTail* ]]
  [[ "$output" != *'cannot open'* ]]
}

@test "nickname ignores newer matching directories and unrelated files" {
  make_log J5-maker.log J5maker 202601010000
  sudo mkdir "$LOG_DIR/J5-new-directory.log"
  make_log J5-backup.txt J5unrelated 202601020000
  run bash -c 'source /home/joinmarket/_functions.sh; YGnickname'
  [ "$status" -eq 0 ]
  [ "$output" = J5maker ]
}
