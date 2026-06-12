#!/usr/bin/env bash
set -euo pipefail

image="${1:-${GITHUB_WORKSPACE:-$(pwd)}/ci/amd64/builds/joininbox-amd64-debian-qemu/joininbox-amd64-debian.qcow2}"
ssh_port="${SSH_PORT:-2222}"
ssh_password="${SSH_PASSWORD:-joininbox}"
qemu_pid_file="${RUNNER_TEMP:-/tmp}/joininbox-qemu.pid"

if [ ! -f "${image}" ]; then
  echo "Missing image: ${image}" >&2
  exit 1
fi

sudo apt-get update
sudo apt-get install -y ovmf qemu-system-x86 sshpass

ssh_opts=(
  -o StrictHostKeyChecking=no
  -o UserKnownHostsFile=/dev/null
  -o ConnectTimeout=5
  -p "${ssh_port}"
)

bios="${OVMF_BIOS:-}"
if [ -z "${bios}" ]; then
  for candidate in \
    /usr/share/OVMF/OVMF_CODE_4M.fd \
    /usr/share/OVMF/OVMF_CODE.fd \
    /usr/share/OVMF/OVMF.fd \
    /usr/share/ovmf/OVMF_CODE_4M.fd \
    /usr/share/ovmf/OVMF_CODE.fd \
    /usr/share/ovmf/OVMF.fd \
    OVMF.fd; do
    if [ -f "${candidate}" ]; then
      bios="${candidate}"
      break
    fi
  done
fi

if [ -z "${bios}" ] || [ ! -f "${bios}" ]; then
  echo "No OVMF BIOS file found. Set OVMF_BIOS to the firmware path." >&2
  exit 1
fi

cleanup() {
  if [ -f "${qemu_pid_file}" ]; then
    qemu_pid="$(cat "${qemu_pid_file}")"
    if kill -0 "${qemu_pid}" 2>/dev/null; then
      kill "${qemu_pid}" 2>/dev/null || true
      timeout 30s tail --pid="${qemu_pid}" -f /dev/null 2>/dev/null ||
        kill -9 "${qemu_pid}" 2>/dev/null ||
        true
    fi
  fi
}
trap cleanup EXIT

rm -f "${qemu_pid_file}"

qemu-system-x86_64 \
  -m 2048 \
  -smp 2 \
  -bios "${bios}" \
  -drive "file=${image},format=qcow2" \
  -netdev "user,id=net0,hostfwd=tcp:127.0.0.1:${ssh_port}-:22" \
  -device e1000,netdev=net0 \
  -display none \
  -snapshot \
  -pidfile "${qemu_pid_file}" \
  -daemonize

echo "Waiting for SSH in the booted image"
for attempt in {1..120}; do
  if sshpass -p "${ssh_password}" ssh "${ssh_opts[@]}" joinmarket@127.0.0.1 "true" 2>/dev/null; then
    break
  fi
  if [ "${attempt}" -eq 120 ]; then
    echo "Timed out waiting for SSH" >&2
    exit 1
  fi
  sleep 5
done

sshpass -p "${ssh_password}" ssh "${ssh_opts[@]}" joinmarket@127.0.0.1 \
  "sudo apt-get update && sudo apt-get install -y bats && /home/joinmarket/joininbox/test/run-bats-local.sh"
