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

ovmf_code="${OVMF_CODE:-${OVMF_BIOS:-}}"
ovmf_vars_template="${OVMF_VARS:-}"
ovmf_vars="${RUNNER_TEMP:-/tmp}/joininbox-ovmf-vars.fd"
qemu_firmware_args=()

if [ -z "${ovmf_code}" ]; then
  for candidate in \
    /usr/share/OVMF/OVMF_CODE_4M.fd \
    /usr/share/OVMF/OVMF_CODE_4M.secboot.fd \
    /usr/share/OVMF/OVMF_CODE_4M.ms.fd \
    /usr/share/OVMF/OVMF_CODE.fd \
    /usr/share/OVMF/OVMF.fd \
    /usr/share/ovmf/OVMF_CODE_4M.fd \
    /usr/share/ovmf/OVMF_CODE_4M.secboot.fd \
    /usr/share/ovmf/OVMF_CODE_4M.ms.fd \
    /usr/share/ovmf/OVMF_CODE.fd \
    /usr/share/ovmf/OVMF.fd \
    OVMF.fd; do
    if [ -f "${candidate}" ]; then
      ovmf_code="${candidate}"
      break
    fi
  done
fi

if [ -z "${ovmf_code}" ] || [ ! -f "${ovmf_code}" ]; then
  echo "No OVMF firmware found. Set OVMF_CODE or OVMF_BIOS to the firmware path." >&2
  find /usr/share/OVMF /usr/share/ovmf -maxdepth 1 -type f -name '*.fd' -print 2>/dev/null || true
  exit 1
fi

case "${ovmf_code##*/}" in
  *CODE*)
    if [ -z "${ovmf_vars_template}" ]; then
      for candidate in \
        "${ovmf_code/CODE/VARS}" \
        /usr/share/OVMF/OVMF_VARS_4M.fd \
        /usr/share/OVMF/OVMF_VARS.fd \
        /usr/share/ovmf/OVMF_VARS_4M.fd \
        /usr/share/ovmf/OVMF_VARS.fd; do
        if [ -f "${candidate}" ]; then
          ovmf_vars_template="${candidate}"
          break
        fi
      done
    fi

    if [ -z "${ovmf_vars_template}" ] || [ ! -f "${ovmf_vars_template}" ]; then
      echo "No OVMF VARS template found for ${ovmf_code}. Set OVMF_VARS to the template path." >&2
      find /usr/share/OVMF /usr/share/ovmf -maxdepth 1 -type f -name '*.fd' -print 2>/dev/null || true
      exit 1
    fi

    cp "${ovmf_vars_template}" "${ovmf_vars}"
    qemu_firmware_args=(
      -drive "if=pflash,format=raw,readonly=on,file=${ovmf_code}"
      -drive "if=pflash,format=raw,file=${ovmf_vars}"
    )
    ;;
  *)
    qemu_firmware_args=(-bios "${ovmf_code}")
    ;;
esac

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
  "${qemu_firmware_args[@]}" \
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
