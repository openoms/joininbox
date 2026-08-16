#!/usr/bin/env bats

setup() {
  SCRIPT="$BATS_TEST_DIRNAME/../scripts/install.hiddenservice.sh"
  sed -n -e '/^validateHiddenServiceDir()/,/^}/p' -e '/^validateService()/,/^}/p' -e '/^validatePort()/,/^}/p' "$SCRIPT" >"$BATS_TEST_TMPDIR/validators.sh"
  source "$BATS_TEST_TMPDIR/validators.sh"
}

@test "accepts only the two supported Tor data roots" {
  run validateHiddenServiceDir /var/lib/tor
  [ "$status" -eq 0 ]
  run validateHiddenServiceDir /mnt/hdd/tor
  [ "$status" -eq 0 ]
  for path in /tmp/tor '/var/lib/tor/../tmp' '/var/lib/tor bad'; do
    run validateHiddenServiceDir "$path"
    [ "$status" -eq 1 ]
    [[ "$output" == *'unexpected HiddenServiceDir'* ]]
  done
}

@test "service names allow only letters digits underscore and hyphen" {
  for service in jam joinmarket-api service_2; do
    run validateService "$service"
    [ "$status" -eq 0 ]
  done
  for service in '' '../tor' 'bad name' 'bad;id' 'bad/name'; do
    run validateService "$service"
    [ "$status" -eq 1 ]
    [[ "$output" == *'invalid service name'* ]]
  done
}

@test "ports must be decimal integers in the complete TCP range" {
  for port in 1 80 65535; do
    run validatePort "$port"
    [ "$status" -eq 0 ]
  done
  for port in '' 0 65536 -1 1.5 80x '80;id'; do
    run validatePort "$port"
    [ "$status" -eq 1 ]
    [[ "$output" == *'invalid port'* || "$output" == *'outside the range'* ]]
  done
}

@test "Tor configuration is verified before the atomic replacement" {
  grep -Fq 'tor --verify-config -f "$candidate"' "$SCRIPT"
  grep -Fq 'mv -f -- "$candidate" /etc/tor/torrc' "$SCRIPT"
  verify_line="$(grep -n 'tor --verify-config' "$SCRIPT" | cut -d: -f1)"
  move_line="$(grep -n 'mv -f --' "$SCRIPT" | cut -d: -f1)"
  [ "$verify_line" -lt "$move_line" ]
}

@test "a failed candidate pipeline cannot replace the live torrc" {
  grep -Fq 'set -o pipefail' "$SCRIPT"
  grep -Fq 'processed torrc is empty - refusing to install' "$SCRIPT"
  grep -Fq 'generated candidate is empty - refusing to install' "$SCRIPT"
}
