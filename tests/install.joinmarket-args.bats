#!/usr/bin/env bats

SCRIPT="$BATS_TEST_DIRNAME/../scripts/install.joinmarket.sh"

@test "help documents supported arguments without evaluating input" {
  run bash "$SCRIPT" --help
  [ "$status" -eq 1 ]
  [[ "$output" == *"--install"* ]]
  [[ "$output" == *"--version"* ]]
}

@test "rejects command substitution in an option value" {
  marker="$BATS_TEST_TMPDIR/injected"
  run bash "$SCRIPT" "--install=\$(touch $marker)"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Invalid characters"* ]]
  [ ! -e "$marker" ]
}

@test "rejects shell separators in an option value" {
  marker="$BATS_TEST_TMPDIR/injected"
  run bash "$SCRIPT" "--version=v0.9.11;touch $marker"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Invalid characters"* ]]
  [ ! -e "$marker" ]
}

@test "rejects redirection and pipeline syntax" {
  run bash "$SCRIPT" '--user=joinmarket>/tmp/result'
  [ "$status" -eq 1 ]
  [[ "$output" == *"Invalid characters"* ]]

  run bash "$SCRIPT" '--user=joinmarket|id'
  [ "$status" -eq 1 ]
  [[ "$output" == *"Invalid characters"* ]]
}
