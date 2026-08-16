#!/usr/bin/env bats

setup() {
  FUNCTIONS="$BATS_TEST_DIRNAME/../scripts/_functions.sh"
  sed -n '/^function sourceConf()/,/^}/p' "$FUNCTIONS" >"$BATS_TEST_TMPDIR/source-conf.sh"
  source "$BATS_TEST_TMPDIR/source-conf.sh"
}

@test "loads plain and quoted values while ignoring comments and blanks" {
  conf="$BATS_TEST_TMPDIR/joinin.conf"
  printf '%s\n' '# comment' '' 'plain=hello world' "single='quoted value'" 'double="other value"' 'empty=' >"$conf"
  sourceConf "$conf"
  [ "$plain" = 'hello world' ]
  [ "$single" = 'quoted value' ]
  [ "$double" = 'other value' ]
  [ "$empty" = '' ]
}

@test "supports the final line without a trailing newline" {
  conf="$BATS_TEST_TMPDIR/joinin.conf"
  printf 'last=value' >"$conf"
  sourceConf "$conf"
  [ "$last" = value ]
}

@test "fails closed when the config file is absent" {
  run sourceConf "$BATS_TEST_TMPDIR/missing"
  [ "$status" -eq 1 ]
  [[ "$output" == *'config file not found'* ]]
}

@test "rejects malformed keys and reports the exact line" {
  conf="$BATS_TEST_TMPDIR/joinin.conf"
  printf 'good=value\ninvalid-key=value\n' >"$conf"
  run sourceConf "$conf"
  [ "$status" -eq 1 ]
  [[ "$output" == *'malformed line 2'* ]]
}

@test "rejects every forbidden shell metacharacter as inert data" {
  for value in '`id`' '$(id)' 'one;id' 'one|id' 'one&id' 'one<input' 'one>output'; do
    conf="$BATS_TEST_TMPDIR/joinin.conf"
    printf 'unsafe=%s\n' "$value" >"$conf"
    run sourceConf "$conf"
    [ "$status" -eq 1 ]
    [[ "$output" == *'forbidden character'* ]]
  done
}

@test "never executes command substitution from a config value" {
  marker="$BATS_TEST_TMPDIR/executed"
  conf="$BATS_TEST_TMPDIR/joinin.conf"
  printf 'unsafe=$(touch %s)\n' "$marker" >"$conf"
  run sourceConf "$conf"
  [ "$status" -eq 1 ]
  [ ! -e "$marker" ]
}
