#!/usr/bin/env bats

SCRIPT="$BATS_TEST_DIRNAME/../scripts/standalone/first.boot.credentials.sh"

setup() {
  ROOT="$BATS_TEST_TMPDIR/root"
  BIN="$BATS_TEST_TMPDIR/bin"
  LOG="$BATS_TEST_TMPDIR/calls.log"
  mkdir -p "$ROOT/var/lib/joininbox" "$ROOT/root" "$ROOT/etc/systemd/system/multi-user.target.wants" "$BIN"
  printf 'Debian GNU/Linux\n' >"$ROOT/etc/issue"
  : >"$LOG"

  cat >"$BIN/id" <<'EOF'
#!/bin/bash
exit 0
EOF
  chmod +x "$BIN/id"

  sed \
    -e "s#MARKER_DIR=\"/var/lib/joininbox\"#MARKER_DIR=\"$ROOT/var/lib/joininbox\"#" \
    -e "s#PASSWORD_FILE=\"/root/joininbox-initial-password\"#PASSWORD_FILE=\"$ROOT/root/joininbox-initial-password\"#" \
    -e "s#ISSUE_FILE=\"/etc/issue\"#ISSUE_FILE=\"$ROOT/etc/issue\"#" \
    -e "s#ISSUE_ORIG=\"/etc/issue.joininbox-orig\"#ISSUE_ORIG=\"$ROOT/etc/issue.joininbox-orig\"#" \
    -e "s#/etc/systemd/system/multi-user.target.wants/#$ROOT/etc/systemd/system/multi-user.target.wants/#" \
    "$SCRIPT" >"$BATS_TEST_TMPDIR/script.sh"

  for command in chpasswd chage systemctl; do
    cat >"$BIN/$command" <<'EOF'
#!/bin/bash
printf '%s %s\n' "$(basename "$0")" "$*" >>"$CALL_LOG"
if [ "$(basename "$0")" = chpasswd ]; then cat >>"$CALL_LOG"; fi
EOF
    chmod +x "$BIN/$command"
  done
  export PATH="$BIN:$PATH" CALL_LOG="$LOG"
}

@test "generates one credential, secures artifacts and disables itself" {
  run bash "$BATS_TEST_TMPDIR/script.sh"
  [ "$status" -eq 0 ]
  [ -f "$ROOT/var/lib/joininbox/firstboot-done" ]
  [ "$(stat -c %a "$ROOT/var/lib/joininbox/firstboot-done")" = 600 ]
  [ -f "$ROOT/root/joininbox-initial-password" ]
  [ "$(stat -c %a "$ROOT/root/joininbox-initial-password")" = 600 ]
  password="$(cat "$ROOT/root/joininbox-initial-password")"
  [ "${#password}" -eq 20 ]
  grep -q "joinmarket:$password" "$LOG"
  grep -q '^chage -d 0 joinmarket$' "$LOG"
  grep -q '^systemctl disable joininbox-firstboot.service$' "$LOG"
  grep -q "$password" "$ROOT/etc/issue"
  ! grep -q "$password" <<<"$output"
}

@test "marker makes subsequent runs idempotent" {
  touch "$ROOT/var/lib/joininbox/firstboot-done"
  run bash "$BATS_TEST_TMPDIR/script.sh"
  [ "$status" -eq 0 ]
  [ ! -s "$LOG" ]
  [ ! -e "$ROOT/root/joininbox-initial-password" ]
}

@test "missing target user exits without creating credentials" {
  cat >"$BIN/id" <<'EOF'
#!/bin/bash
exit 1
EOF
  chmod +x "$BIN/id"
  run bash "$BATS_TEST_TMPDIR/script.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"user 'joinmarket' not found"* ]]
  [ ! -e "$ROOT/root/joininbox-initial-password" ]
}

@test "systemd unit orders credential generation before SSH" {
  unit="$BATS_TEST_DIRNAME/../scripts/standalone/joininbox-firstboot.service"
  grep -q '^Before=ssh.service' "$unit"
  grep -q '^ExecStart=/usr/local/sbin/joininbox-firstboot.sh' "$unit"
  grep -q '^ConditionPathExists=!/var/lib/joininbox/firstboot-done' "$unit"
  grep -q '^StandardOutput=null' "$unit"
}
