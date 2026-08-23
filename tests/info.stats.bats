#!/usr/bin/env bats
# End-to-end regression coverage for the STATS command.  The real script is
# executed against a synthetic maker statement and mocked process table.

load helpers/joininbox-env

SCRIPT="$REPO_ROOT/scripts/info.stats.sh"

setup_file() {
  joininbox_setup_file
  sudo cp "$SCRIPT" "$JM_HOME/info.stats.sh"
  sudo mkdir -p "$JM_HOME/.joinmarket/logs"
}

teardown_file() {
  joininbox_teardown_file
}

setup() {
  TEST_TMP="$(mktemp -d)"
  MOCK_BIN="$TEST_TMP/mockbin"
  mkdir -p "$MOCK_BIN"

  cat >"$MOCK_BIN/pgrep" <<'EOF'
#!/bin/bash
printf '4242\n'
EOF
  cat >"$MOCK_BIN/ps" <<'EOF'
#!/bin/bash
printf '1-02:03:04\n'
EOF
  chmod +x "$MOCK_BIN/pgrep" "$MOCK_BIN/ps"

  now="$(date '+%Y-%m-%d %H:%M:%S')"
  two_days_ago="$(date -d '2 days ago' '+%Y-%m-%d %H:%M:%S')"
  ten_days_ago="$(date -d '10 days ago' '+%Y-%m-%d %H:%M:%S')"
  two_months_ago="$(date -d '2 months ago' '+%Y-%m-%d %H:%M:%S')"

  sudo tee "$JM_HOME/.joinmarket/logs/yigen-statement.csv" >/dev/null <<EOF
timestamp,cj amount/satoshi,my input count,my input value/satoshi,cjfee/satoshi,earned/satoshi,confirm time/min,notes
$now,,,,,,,Connected
$now,100000,1,50000,10,100,1,new
$two_days_ago,100000,1,50000,10,200,1,week
$ten_days_ago,100000,1,50000,10,300,1,month
$two_months_ago,100000,1,50000,10,400,1,lifetime
EOF
}

teardown() {
  rm -rf "$TEST_TMP"
}

@test "STATS shows uptime and computes lifetime totals without double-counting periods" {
  run env PATH="$MOCK_BIN:$PATH" bash "$SCRIPT" showAllEarned

  [ "$status" -eq 0 ]
  [[ "$output" == *"JoinMarket stats"*"day"*"week"*"month"*"all"* ]]
  [[ "$output" == *"coinjoins as a Maker"*"1"*"2"*"3"*"4"* ]]
  [[ "$output" == *"sats earned"*"100"*"300"*"600"*"1000"* ]]
  [[ "$output" == *"up"*"1d"*"2h"*"3m"* ]]
}
