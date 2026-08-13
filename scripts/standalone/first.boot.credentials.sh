#!/bin/bash

# joininbox-firstboot.sh - one-shot first-boot credential generation
#
# Installed to /usr/local/sbin/joininbox-firstboot.sh by build_joininbox.sh
# and run ONCE on the device by joininbox-firstboot.service (ordered
# Before=ssh.service) at the first boot.
#
# Generates a unique random password for the 'joinmarket' user ON THE
# DEVICE - never at image build time. This keeps the credential out of
# public CI build logs and out of published/shareable images.
#
# The password is NEVER written to stdout, the journal or syslog - only to
# the local console message (/etc/issue) and a root-only backup file.

set -u

TARGET_USER="joinmarket"
MARKER_DIR="/var/lib/joininbox"
MARKER_FILE="${MARKER_DIR}/firstboot-done"
PASSWORD_FILE="/root/joininbox-initial-password"
ISSUE_FILE="/etc/issue"
ISSUE_ORIG="/etc/issue.joininbox-orig"
UNIT_NAME="joininbox-firstboot.service"

# Idempotency: if the marker exists the credentials were already generated
# on this device - do nothing, even if the unit is still enabled.
if [ -f "${MARKER_FILE}" ]; then
  exit 0
fi

# Nothing to do if the target user does not exist on this system.
if ! id "${TARGET_USER}" >/dev/null 2>&1; then
  echo "joininbox-firstboot: user '${TARGET_USER}' not found - skipping" >&2
  exit 0
fi

mkdir -p "${MARKER_DIR}"
chmod 700 "${MARKER_DIR}"

# Generate a random password: 20 alphanumeric chars from /dev/urandom
# (~119 bits of entropy, >= 16 chars as required).
initialPassword=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 20)
if [ ${#initialPassword} -lt 16 ]; then
  echo "joininbox-firstboot: password generation failed" >&2
  exit 1
fi

# Set the password (via stdin, never on a command line) and force it to be
# changed at the first login. Debian's default sshd (UsePAM yes) prompts
# for a new password after authentication when the account is expired.
echo "${TARGET_USER}:${initialPassword}" | chpasswd || exit 1
chage -d 0 "${TARGET_USER}" || exit 1

# Root-only backup copy of the initial password.
umask 077
echo "${initialPassword}" >"${PASSWORD_FILE}"
chmod 600 "${PASSWORD_FILE}"

# Show the initial password on the local console only (agetty displays
# /etc/issue before the login prompt). Keep a pristine copy of /etc/issue
# so prepare.release.sh can restore it when building a shareable image.
if [ -f "${ISSUE_FILE}" ] && [ ! -f "${ISSUE_ORIG}" ]; then
  cp "${ISSUE_FILE}" "${ISSUE_ORIG}" 2>/dev/null || true
fi
{
  echo ""
  echo "JoininBox: the unique initial password of the '${TARGET_USER}' user is:"
  echo "${initialPassword}"
  echo "It must be changed on the first login. A root-only copy is kept in"
  echo "${PASSWORD_FILE} (mode 600)."
} >>"${ISSUE_FILE}"

# Mark as done - the script never runs again on this device, even if the
# unit cannot be disabled below (e.g. read-only systemd state).
touch "${MARKER_FILE}"
chmod 600 "${MARKER_FILE}"

# Disable the one-shot unit so it is not even evaluated on later boots.
systemctl disable "${UNIT_NAME}" >/dev/null 2>&1 || true
rm -f "/etc/systemd/system/multi-user.target.wants/${UNIT_NAME}"

unset initialPassword
exit 0
