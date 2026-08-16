#!/usr/bin/env bats

REPO_ROOT="$BATS_TEST_DIRNAME/.."

@test "every maintained shell script parses with bash" {
  while IFS= read -r script; do
    bash -n "$REPO_ROOT/$script" || return 1
  done < <(cd "$REPO_ROOT" && find scripts ci -type f -name '*.sh' -print)
}

@test "every maintained Python script parses without importing dependencies" {
  while IFS= read -r script; do
    python3 -c 'import ast, pathlib, sys; ast.parse(pathlib.Path(sys.argv[1]).read_text(), filename=sys.argv[1])' "$REPO_ROOT/$script" || return 1
  done < <(cd "$REPO_ROOT" && find scripts ci -type f -name '*.py' -print)
}

@test "systemd service assets contain the required sections and command" {
  while IFS= read -r unit; do
    grep -q '^\[Unit\]$' "$REPO_ROOT/$unit"
    grep -q '^\[Service\]$' "$REPO_ROOT/$unit"
    grep -q '^\[Install\]$' "$REPO_ROOT/$unit"
    grep -q '^ExecStart=' "$REPO_ROOT/$unit"
  done < <(cd "$REPO_ROOT" && find scripts -type f -name '*.service' -print)
}

@test "runtime scripts parse joinin.conf as data instead of sourcing it" {
  run grep -REn '(^|[[:space:]])(source|\.)[[:space:]]+/home/joinmarket/joinin\.conf' "$REPO_ROOT/scripts"
  [ "$status" -eq 1 ]

  # Keep the parser available; the scan above prevents consumers from
  # bypassing it by executing the user-writable file as shell code.
  grep -q '^function sourceConf()' "$REPO_ROOT/scripts/_functions.sh"
}
