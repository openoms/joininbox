#!/bin/bash
# test-prepare-release.sh - regression test for prepare.release.sh
#
# Verifies the shareable-image reset path without root or a real system:
#   1. the 'joinmarket' password is LOCKED before imaging (no operator hash
#      ships in the image; fail closed if first-boot generation fails)
#   2. first-boot artifacts (marker + initial-password file) are removed
#   3. the one-shot first-boot unit is re-enabled for the next boot
#   4. the script reaches the final shutdown step
#
# All privileged operations are intercepted by a mock 'sudo' that rewrites
# absolute paths into a temporary fakeroot.
#
# Run: bash tests/test-prepare-release.sh

set -u

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEST_ROOT="$(mktemp -d)"
MOCK_BIN="${TEST_ROOT}/bin"
MOCK_LOG="${TEST_ROOT}/mock.log"
mkdir -p "${MOCK_BIN}"
touch "${MOCK_LOG}"

cleanup() { rm -rf "${TEST_ROOT}"; }
trap cleanup EXIT

# --- fakeroot state -------------------------------------------------------
mkdir -p \
  "${TEST_ROOT}/root/.ssh" \
  "${TEST_ROOT}/etc/ssh" \
  "${TEST_ROOT}/etc/wpa_supplicant" \
  "${TEST_ROOT}/home/joinmarket" \
  "${TEST_ROOT}/var/lib/joininbox"

touch "${TEST_ROOT}/root/.ssh/authorized_keys" \
      "${TEST_ROOT}/etc/resolv.conf" \
      "${TEST_ROOT}/home/joinmarket/joinin.conf" \
      "${TEST_ROOT}/var/lib/joininbox/firstboot-done" \
      "${TEST_ROOT}/root/joininbox-initial-password"

# operator has an ACTIVE password hash after completing first boot
echo 'joinmarket:$6$operatorhash:19000:0:99999:7:::' >"${TEST_ROOT}/etc/shadow"

# --- mock sudo ------------------------------------------------------------
cat >"${MOCK_BIN}/sudo" <<'EOF'
#!/bin/bash
# Rewrites absolute path arguments into TEST_ROOT and simulates privileged
# commands. Logs invocations of interest to MOCK_LOG.
cmd="$1"; shift
rewritten=()
for a in "$@"; do
  case "$a" in
    /*) rewritten+=("${TEST_ROOT}${a}") ;;
    *)  rewritten+=("$a") ;;
  esac
done
case "$cmd" in
  passwd)
    # only 'passwd -l <user>' is used by the script
    if [ "$1" = "-l" ]; then
      sed -i "s/^$2:/$2:!/" "${TEST_ROOT}/etc/shadow"
      echo "passwd -l $2" >>"${MOCK_LOG}"
      exit 0
    fi
    echo "mock sudo: unexpected passwd args: $*" >&2; exit 1
    ;;
  systemctl|shutdown)
    echo "$cmd $*" >>"${MOCK_LOG}"; exit 0
    ;;
  rm|cp|tee)
    "$cmd" "${rewritten[@]}"
    ;;
  *)
    echo "mock sudo: unhandled command: $cmd $*" >&2; exit 1
    ;;
esac
EOF
chmod +x "${MOCK_BIN}/sudo"

# --- run the script under test -------------------------------------------
PATH="${MOCK_BIN}:$PATH" TEST_ROOT="${TEST_ROOT}" MOCK_LOG="${MOCK_LOG}" \
  bash "${REPO_ROOT}/scripts/standalone/prepare.release.sh" >"${TEST_ROOT}/run.log" 2>&1

# --- assertions -----------------------------------------------------------
failures=0
check() {
  if eval "$2"; then
    echo "ok - $1"
  else
    echo "FAIL - $1" >&2
    failures=$((failures + 1))
  fi
}

check "joinmarket password is locked in the image" \
  "grep -q '^joinmarket:!' '${TEST_ROOT}/etc/shadow'"

check "passwd -l joinmarket was invoked" \
  "grep -q '^passwd -l joinmarket$' '${MOCK_LOG}'"

check "first-boot marker is removed" \
  "[ ! -e '${TEST_ROOT}/var/lib/joininbox/firstboot-done' ]"

check "initial-password file is removed" \
  "[ ! -e '${TEST_ROOT}/root/joininbox-initial-password' ]"

check "first-boot unit is re-enabled" \
  "grep -q 'systemctl enable joininbox-firstboot.service' '${MOCK_LOG}'"

check "script reaches the shutdown step" \
  "grep -q '^shutdown' '${MOCK_LOG}'"

echo
if [ "${failures}" -gt 0 ]; then
  echo "${failures} assertion(s) FAILED" >&2
  echo "--- script output ---" >&2
  cat "${TEST_ROOT}/run.log" >&2
  exit 1
fi
echo "all assertions passed"
exit 0
