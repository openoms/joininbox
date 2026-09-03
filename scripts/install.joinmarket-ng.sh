#!/usr/bin/env bash
# JoininBox lifecycle helper for the signed JoinMarket-NG release channel.

set -euo pipefail

APP_ID="joinmarket-ng"
RELEASE_TAG="0.38.0"
SERVICE_USER="joinmarketng"
SERVICE_HOME="/home/${SERVICE_USER}"
VENV_DIR="${SERVICE_HOME}/venv"
HOME_DATA_DIR="${SERVICE_HOME}/.joinmarket-ng"
PERSISTENT_DATA_DIR="/mnt/hdd/app-data/joinmarket-ng"
RUNTIME_DIR="/run/joinmarket-ng"
MAKER_ENV="${RUNTIME_DIR}/maker.env"
PRIVILEGED_DIR="/usr/local/libexec/joininbox"
CONFIG_WRITER="${PRIVILEGED_DIR}/set.joinmarket-ng-config.py"
TUI_PATH="${PRIVILEGED_DIR}/menu.joinmarket-ng.sh"
CLI_WRAPPER="${PRIVILEGED_DIR}/joinmarket-ng-cli"
CLI_LINK_DIR="/usr/local/bin"
CLI_COMMANDS=(jm-ng jm-maker jm-wallet jm-taker jm-tumbler jm-orderbook-watcher)
LEGACY_CONFIG="/home/joinmarket/.joinmarket/joinmarket.cfg"
JOININ_CONFIG="/home/joinmarket/joinin.conf"
HELPER_PATH="${PRIVILEGED_DIR}/install.joinmarket-ng.sh"
COMPATIBILITY_PATH="/home/admin/config.scripts/bonus.joinmarket-ng.sh"
SERVICE_PATH="/etc/systemd/system/joinmarket-ng-maker.service"
SUDOERS_PATH="/etc/sudoers.d/joinmarketng-maker"
GITHUB_RAW="https://raw.githubusercontent.com/joinmarket-ng/joinmarket-ng/main"
GITHUB_RELEASES="https://github.com/joinmarket-ng/joinmarket-ng/releases/download"
TRUSTED_FINGERPRINTS=(
  "1C53A412D11EF3051704419C44912E1E03005B31"
  "9253062A4F92D63459085CA62D230520212A5901"
)

VERIFIED_COMMIT=""
DATA_DIR=""

fail() {
  printf '%s\n' "error: $*" >&2
  return 1
}

is_valid_release_tag() {
  [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-][A-Za-z0-9][A-Za-z0-9._-]*)?$ ]]
}

is_valid_commit() {
  [[ "$1" =~ ^[0-9a-f]{40}$ ]]
}

manifest_commit() {
  local manifest="$1"
  local commit

  commit=$(awk -F': *' '$1 == "commit" { print $2; exit }' "$manifest" | tr -d '[:space:]')
  is_valid_commit "$commit" || return 1
  printf '%s\n' "$commit"
}

manifest_commit_matches() {
  local release_commit
  local local_commit

  release_commit=$(manifest_commit "$1") || return 1
  local_commit=$(manifest_commit "$2") || return 1
  [[ "$release_commit" == "$local_commit" ]]
}

is_raspiblitz() {
  [[ -f /mnt/hdd/raspiblitz.conf || -f /mnt/hdd/app-data/raspiblitz.conf || \
    ( -e "$COMPATIBILITY_PATH" && ! -L "$COMPATIBILITY_PATH" ) ]]
}

set_data_layout() {
  if is_raspiblitz; then
    DATA_DIR="$PERSISTENT_DATA_DIR"
  else
    DATA_DIR="$HOME_DATA_DIR"
  fi
}

config_path() {
  set_data_layout
  printf '%s/config.toml\n' "$DATA_DIR"
}

env_path() {
  printf '%s\n' "$MAKER_ENV"
}

read_bitcoin_conf_key() {
  local config_file="$1"
  local key="$2"

  [[ -r "$config_file" ]] || return 1
  awk -v key="$key" '
    index($0, key "=") == 1 {
      value = substr($0, length(key) + 2)
      sub(/^[[:space:]]+/, "", value)
      sub(/[[:space:]]+$/, "", value)
      first = substr(value, 1, 1)
      last = substr(value, length(value), 1)
      if (length(value) >= 2 && ((first == "\"" && last == "\"") ||
          (first == "\047" && last == "\047"))) {
        value = substr(value, 2, length(value) - 2)
      }
      print value
      exit
    }
  ' "$config_file"
}

normalize_network() {
  case "$1" in
    mainnet | main) printf '%s\n' "mainnet" ;;
    testnet | test) printf '%s\n' "testnet" ;;
    signet | sig) printf '%s\n' "signet" ;;
    *) return 1 ;;
  esac
}

network_rpc_port() {
  case "$1" in
    mainnet) printf '%s\n' "8332" ;;
    testnet) printf '%s\n' "18332" ;;
    signet) printf '%s\n' "38332" ;;
    *) return 1 ;;
  esac
}

standalone_bitcoin_config() {
  case "$1" in
    mainnet | testnet) printf '%s\n' "/home/bitcoin/.bitcoin/bitcoin.conf" ;;
    signet) printf '%s\n' "/home/joinmarket/.bitcoin/bitcoin.conf" ;;
    *) return 1 ;;
  esac
}

joinin_value() {
  local key="$1"

  [[ -r "$JOININ_CONFIG" ]] || return 1
  awk -v key="$key" '
    index($0, key "=") == 1 {
      value = substr($0, length(key) + 2)
      sub(/^[[:space:]]+/, "", value)
      sub(/[[:space:]]+$/, "", value)
      first = substr(value, 1, 1)
      last = substr(value, length(value), 1)
      if (length(value) >= 2 && ((first == "\"" && last == "\"") ||
          (first == "\047" && last == "\047"))) {
        value = substr(value, 2, length(value) - 2)
      }
      print value
      exit
    }
  ' "$JOININ_CONFIG"
}

network_from_joinin_config() {
  local configured_network

  configured_network=$(joinin_value network || true)
  if [[ -z "$configured_network" ]]; then
    configured_network="mainnet"
  fi
  normalize_network "$configured_network" || fail "invalid network in ${JOININ_CONFIG}"
}

LOCAL_RPC_USER=""
LOCAL_RPC_PASSWORD=""
LOCAL_RPC_HOST="127.0.0.1"

load_local_rpc_credentials() {
  local network="$1"
  local bitcoin_config=""
  local standalone_config

  if [[ -r /mnt/hdd/bitcoin/bitcoin.conf ]]; then
    bitcoin_config="/mnt/hdd/bitcoin/bitcoin.conf"
    LOCAL_RPC_USER=$(read_bitcoin_conf_key "$bitcoin_config" rpcuser) || \
      fail "rpcuser is unavailable in ${bitcoin_config}"
    LOCAL_RPC_PASSWORD=$(read_bitcoin_conf_key "$bitcoin_config" rpcpassword) || \
      fail "rpcpassword is unavailable in ${bitcoin_config}"
  elif [[ -r /mnt/hdd/app-data/bitcoin/bitcoin.conf ]]; then
    bitcoin_config="/mnt/hdd/app-data/bitcoin/bitcoin.conf"
    LOCAL_RPC_USER=$(read_bitcoin_conf_key "$bitcoin_config" rpcuser) || \
      fail "rpcuser is unavailable in ${bitcoin_config}"
    LOCAL_RPC_PASSWORD=$(read_bitcoin_conf_key "$bitcoin_config" rpcpassword) || \
      fail "rpcpassword is unavailable in ${bitcoin_config}"
  elif [[ -r /mnt/hdd/mynode/settings/.btcrpcpw ]]; then
    LOCAL_RPC_USER="mynode"
    IFS= read -r LOCAL_RPC_PASSWORD < /mnt/hdd/mynode/settings/.btcrpcpw || true
    [[ -n "$LOCAL_RPC_PASSWORD" ]] || fail "MyNode RPC password is unavailable"
  else
    standalone_config=$(standalone_bitcoin_config "$network") || return 1
    [[ -r "$standalone_config" ]] || \
      fail "local Bitcoin RPC credentials are unavailable for this JoininBox topology"
    bitcoin_config="$standalone_config"
    LOCAL_RPC_USER=$(read_bitcoin_conf_key "$bitcoin_config" rpcuser) || \
      fail "rpcuser is unavailable in ${bitcoin_config}"
    LOCAL_RPC_PASSWORD=$(read_bitcoin_conf_key "$bitcoin_config" rpcpassword) || \
      fail "rpcpassword is unavailable in ${bitcoin_config}"
  fi
}

is_onion_rpc_config() {
  local config_file="$1"

  runuser -u "$SERVICE_USER" -- python3 - "$config_file" <<'PYTHON'
import sys
import tomllib
from pathlib import Path

try:
    data = tomllib.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
    url = data["bitcoin"]["rpc_url"]
    host = url.split("://", 1)[-1].rsplit("@", 1)[-1].split(":", 1)[0]
except (KeyError, OSError, TypeError, ValueError, tomllib.TOMLDecodeError):
    raise SystemExit(1)
raise SystemExit(0 if host.lower().endswith(".onion") else 1)
PYTHON
}

is_local_rpc_config() {
  local config_file="$1"

  runuser -u "$SERVICE_USER" -- python3 - "$config_file" <<'PYTHON'
import sys
import tomllib
from pathlib import Path
from urllib.parse import urlsplit

try:
    data = tomllib.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
    host = urlsplit(data["bitcoin"]["rpc_url"]).hostname
except (KeyError, OSError, TypeError, ValueError, tomllib.TOMLDecodeError):
    raise SystemExit(1)
raise SystemExit(0 if host in {"127.0.0.1", "::1", "localhost"} else 1)
PYTHON
}

validate_rpc_config() {
  local config_file="$1"

  runuser -u "$SERVICE_USER" -- python3 - "$config_file" <<'PYTHON'
import sys
import tomllib
from pathlib import Path
from urllib.parse import urlsplit

try:
    data = tomllib.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
    bitcoin = data["bitcoin"]
    network = data["network_config"]["network"]
    rpc_url = bitcoin["rpc_url"]
    rpc_user = bitcoin["rpc_user"]
    rpc_password = bitcoin["rpc_password"]
    parsed_url = urlsplit(rpc_url)
    if network not in {"mainnet", "testnet", "signet", "regtest"}:
        raise ValueError
    if parsed_url.scheme not in {"http", "https"} or parsed_url.hostname is None:
        raise ValueError
    if not isinstance(rpc_user, str) or not isinstance(rpc_password, str):
        raise ValueError
except (KeyError, OSError, TypeError, ValueError, tomllib.TOMLDecodeError):
    raise SystemExit(1)
PYTHON
}

toml_has_wallet_password() {
  local config_file="$1"

  runuser -u "$SERVICE_USER" -- python3 - "$config_file" <<'PYTHON'
import sys
import tomllib
from pathlib import Path

try:
    data = tomllib.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
    password = data.get("wallet", {}).get("mnemonic_password")
except (OSError, TypeError, tomllib.TOMLDecodeError):
    raise SystemExit(1)
raise SystemExit(0 if password is not None and str(password).strip() else 1)
PYTHON
}

configured_mnemonic_file() {
  local config_file="$1"

  runuser -u "$SERVICE_USER" -- python3 - "$config_file" <<'PYTHON'
import sys
import tomllib
from pathlib import Path

try:
    data = tomllib.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
    mnemonic_file = data.get("wallet", {}).get("mnemonic_file")
except (OSError, TypeError, tomllib.TOMLDecodeError):
    raise SystemExit(1)
if not isinstance(mnemonic_file, str) or not mnemonic_file:
    raise SystemExit(1)
print(mnemonic_file)
PYTHON
}

toml_store_wallet_password() {
  local config_file="$1"
  local password="$2"

  runuser -u "$SERVICE_USER" -- python3 - "$config_file" "$password" <<'PYTHON'
import json
import os
import re
import stat
import sys
import tempfile
import tomllib
from pathlib import Path

path = Path(sys.argv[1])
password = sys.argv[2]
content = path.read_text(encoding="utf-8")
tomllib.loads(content)
line = "mnemonic_password = " + json.dumps(password, ensure_ascii=True)
headers = list(re.finditer(r"^\s*\[([^]]+)\]\s*(?:#.*)?$", content, re.MULTILINE))
wallet = next((match for match in headers if match.group(1).strip() == "wallet"), None)
if wallet is None:
    if content and not content.endswith("\n"):
        content += "\n"
    content += "\n[wallet]\n" + line + "\n"
else:
    section_end = next((match.start() for match in headers if match.start() > wallet.start()), len(content))
    section = content[wallet.end():section_end]
    pattern = re.compile(r"^\s*mnemonic_password\s*=.*$", re.MULTILINE)
    if pattern.search(section):
        section = pattern.sub(lambda _match: line, section, count=1)
    else:
        section = "\n" + line + section
    content = content[:wallet.end()] + section + content[section_end:]
mode = stat.S_IMODE(path.stat().st_mode)
with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", dir=path.parent, delete=False) as output:
    output.write(content)
    output.flush()
    os.fsync(output.fileno())
    temporary = output.name
os.chmod(temporary, mode)
os.replace(temporary, path)
PYTHON
}

systemd_quote() {
  printf '%s' "$1" | python3 -c '
import sys
value = sys.stdin.read()
print(value.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n").replace("\r", "\\r"), end="")
'
}

require_root() {
  [[ "$EUID" -eq 0 ]] || fail "this command must run as root"
}

signature_matches_fingerprint() {
  local signature="$1"
  local manifest="$2"
  local fingerprint="$3"

  gpg --batch --status-fd=1 --verify "$signature" "$manifest" 2>/dev/null | \
    awk -v fingerprint="$fingerprint" \
      '$1 == "[GNUPG:]" && $2 == "VALIDSIG" && $3 == fingerprint { valid = 1 } END { exit !valid }'
}

verify_release() {
  local tag="$1"
  local temporary_dir=""
  local original_gnupg_home="${GNUPGHOME:-}"
  local manifest=""
  local fingerprint=""
  local public_key=""
  local imported_fingerprints=""
  local signature=""
  local local_manifest=""
  local valid_signatures=0
  local commit=""

  is_valid_release_tag "$tag" || fail "release tag must be a signed version tag"
  temporary_dir=$(mktemp -d)
  export GNUPGHOME="${temporary_dir}/gnupg"
  mkdir -m 700 "$GNUPGHOME"
  manifest="${temporary_dir}/release-manifest-${tag}.txt"

  if ! curl -fsSL "${GITHUB_RELEASES}/${tag}/release-manifest-${tag}.txt" -o "$manifest"; then
    rm -rf "$temporary_dir"
    if [[ -n "$original_gnupg_home" ]]; then export GNUPGHOME="$original_gnupg_home"; else unset GNUPGHOME; fi
    fail "could not download signed release metadata for ${tag}"
  fi

  for fingerprint in "${TRUSTED_FINGERPRINTS[@]}"; do
    public_key="${temporary_dir}/${fingerprint}.asc"
    signature="${temporary_dir}/${fingerprint}.sig"
    if ! curl -fsSL "${GITHUB_RAW}/signatures/pubkeys/${fingerprint}.asc" -o "$public_key"; then
      continue
    fi
    imported_fingerprints=$(gpg --batch --with-colons --import-options show-only --import "$public_key" 2>/dev/null | \
      awk -F: '$1 == "fpr" { print $10 }')
    if ! grep -Fxq "$fingerprint" <<< "$imported_fingerprints" || \
      ! gpg --batch --quiet --import "$public_key" 2>/dev/null || \
      ! curl -fsSL "${GITHUB_RAW}/signatures/${tag}/${fingerprint}.sig" -o "$signature"; then
      continue
    fi
    if signature_matches_fingerprint "$signature" "$manifest" "$fingerprint"; then
      valid_signatures=$((valid_signatures + 1))
      continue
    fi
    local_manifest="${temporary_dir}/${fingerprint}-manifest.txt"
    if curl -fsSL "${GITHUB_RAW}/signatures/${tag}/${fingerprint}-manifest.txt" -o "$local_manifest" && \
      signature_matches_fingerprint "$signature" "$local_manifest" "$fingerprint" && \
      manifest_commit_matches "$manifest" "$local_manifest"; then
      valid_signatures=$((valid_signatures + 1))
    fi
  done

  commit=$(manifest_commit "$manifest" || true)
  rm -rf "$temporary_dir"
  if [[ -n "$original_gnupg_home" ]]; then export GNUPGHOME="$original_gnupg_home"; else unset GNUPGHOME; fi
  [[ "$valid_signatures" -gt 0 ]] || fail "no trusted signature verified release ${tag}"
  is_valid_commit "$commit" || fail "release manifest has no valid immutable commit"
  VERIFIED_COMMIT="$commit"
  printf '%s\n' "verified_release=${tag}"
  printf '%s\n' "verified_commit=${VERIFIED_COMMIT}"
}

ensure_service_user() {
  if ! id -u "$SERVICE_USER" >/dev/null 2>&1; then
    useradd --system --create-home --home-dir "$SERVICE_HOME" --shell /bin/bash "$SERVICE_USER"
  fi
  [[ ! -L "$SERVICE_HOME" ]] || fail "${SERVICE_HOME} must not be a symlink"
  install -d -m 750 -o root -g "$SERVICE_USER" "$SERVICE_HOME"
}

ensure_runtime_layout() {
  [[ ! -L "$RUNTIME_DIR" ]] || { fail "${RUNTIME_DIR} must not be a symlink"; return 1; }
  install -d -m 750 -o root -g "$SERVICE_USER" "$RUNTIME_DIR"
  if [[ -e "$MAKER_ENV" || -L "$MAKER_ENV" ]]; then
    [[ -f "$MAKER_ENV" && ! -L "$MAKER_ENV" ]] || \
      { fail "${MAKER_ENV} must be a regular file"; return 1; }
  else
    install -m 600 -o "$SERVICE_USER" -g "$SERVICE_USER" /dev/null "$MAKER_ENV"
  fi
  chown --no-dereference "$SERVICE_USER:$SERVICE_USER" "$MAKER_ENV"
  chmod 600 "$MAKER_ENV"
}

require_safe_data_layout() {
  local data_parent
  local mode
  local path

  set_data_layout
  data_parent=$(dirname "$DATA_DIR")
  [[ -d "$data_parent" && ! -L "$data_parent" ]] || \
    { fail "data parent is not a regular directory: ${data_parent}"; return 1; }
  [[ "$(stat -c '%u' "$data_parent")" -eq 0 ]] || \
    { fail "data parent is not root-owned: ${data_parent}"; return 1; }
  mode=$(stat -c '%a' "$data_parent")
  (( (8#$mode & 8#022) == 0 )) || \
    { fail "data parent is group/world writable: ${data_parent}"; return 1; }
  for path in "$DATA_DIR" "$DATA_DIR/wallets" "$DATA_DIR/logs"; do
    [[ ! -L "$path" ]] || \
      { fail "managed data path must not be a symlink: ${path}"; return 1; }
    [[ ! -e "$path" || -d "$path" ]] || \
      { fail "managed data path is not a directory: ${path}"; return 1; }
  done
}

ensure_data_layout() {
  require_safe_data_layout
  install -d -m 700 -o "$SERVICE_USER" -g "$SERVICE_USER" "$DATA_DIR"
  chown -R --no-dereference "$SERVICE_USER:$SERVICE_USER" "$DATA_DIR"
  runuser -u "$SERVICE_USER" -- install -d -m 700 "$DATA_DIR/wallets" "$DATA_DIR/logs"
  if is_raspiblitz; then
    if [[ -e "$HOME_DATA_DIR" && ! -L "$HOME_DATA_DIR" ]]; then
      fail "${HOME_DATA_DIR} is not a symlink; refusing to risk existing data"
    fi
    ln -sfn "$DATA_DIR" "$HOME_DATA_DIR"
    chown -h "$SERVICE_USER:$SERVICE_USER" "$HOME_DATA_DIR"
  fi
  chmod 700 "$DATA_DIR"
}

ensure_compatibility_path() {
  if [[ -d "$COMPATIBILITY_PATH" ]]; then
    fail "${COMPATIBILITY_PATH} is a directory"
  fi
  install -d -m 755 "$(dirname "$COMPATIBILITY_PATH")"
  rm -f "$COMPATIBILITY_PATH"
  ln -sfn "$HELPER_PATH" "$COMPATIBILITY_PATH"
}

require_root_owned_file() {
  local path="$1"
  local mode

  [[ -f "$path" && ! -L "$path" ]] || fail "privileged file is unavailable: ${path}"
  [[ "$(stat -c '%u' "$path")" -eq 0 ]] || fail "privileged file is not root-owned: ${path}"
  mode=$(stat -c '%a' "$path")
  (( (8#$mode & 8#022) == 0 )) || fail "privileged file is group/world writable: ${path}"
}

require_privileged_helpers() {
  local path

  for path in "$HELPER_PATH" "$CONFIG_WRITER"; do
    require_root_owned_file "$path"
  done
}

bootstrap_command() {
  local source_helper
  local source_dir

  require_root
  source_helper=$(readlink -f "${BASH_SOURCE[0]}")
  source_dir=$(dirname "$source_helper")
  [[ -f "${source_dir}/set.joinmarket-ng-config.py" ]] || \
    fail "TOML writer is unavailable beside the bootstrap helper"
  install -d -m 755 -o root -g root "$PRIVILEGED_DIR"
  if [[ "$source_helper" != "$HELPER_PATH" ]]; then
    install -m 755 -o root -g root "$source_helper" "$HELPER_PATH"
  fi
  if [[ "${source_dir}/set.joinmarket-ng-config.py" != "$CONFIG_WRITER" ]]; then
    install -m 755 -o root -g root "${source_dir}/set.joinmarket-ng-config.py" "$CONFIG_WRITER"
  fi
  require_privileged_helpers
}

install_dependencies() {
  apt-get update
  apt-get install -y build-essential cmake ca-certificates curl git gnupg libffi-dev libsodium-dev \
    pkg-config python3-dev python3-venv torsocks whiptail
}

add_tor_group() {
  if getent group debian-tor >/dev/null; then
    usermod -aG debian-tor "$SERVICE_USER"
  fi
}

run_upstream_installer() {
  local tag="$1"
  local mode="$2"
  local installer=""
  local installer_args=(--yes --version "$tag" --skip-tor)

  verify_release "$tag"
  installer=$(mktemp)
  if ! curl -fsSL "https://raw.githubusercontent.com/joinmarket-ng/joinmarket-ng/${VERIFIED_COMMIT}/install.sh" \
    -o "$installer"; then
    rm -f "$installer"
    fail "could not download immutable upstream installer"
  fi
  chown "$SERVICE_USER:$SERVICE_USER" "$installer"
  chmod 700 "$installer"
  if [[ "$mode" == "update" ]]; then
    installer_args+=(--update)
  fi
  if ! runuser -u "$SERVICE_USER" -- env HOME="$SERVICE_HOME" JMNG_VENV_DIR="$VENV_DIR" \
    JOINMARKET_DATA_DIR="$DATA_DIR" bash "$installer" "${installer_args[@]}"; then
    rm -f "$installer"
    fail "upstream JoinMarket-NG installer failed"
  fi
  rm -f "$installer"
}

install_tui_wrapper() {
  local upstream_menu

  upstream_menu=$(runuser -u "$SERVICE_USER" -- "$VENV_DIR/bin/python" - <<'PYTHON'
from importlib import resources

print(resources.files("jmcore").joinpath("data/menu.joinmarket-ng.sh"))
PYTHON
)
  [[ -f "$upstream_menu" ]] || fail "installed JoinMarket NG TUI is unavailable"
  python3 - "$upstream_menu" "$TUI_PATH" "$HELPER_PATH" "$MAKER_ENV" <<'PYTHON'
import os
import sys
from pathlib import Path

source_path = Path(sys.argv[1])
destination_path = Path(sys.argv[2])
helper_path = sys.argv[3]
maker_env = sys.argv[4]
content = source_path.read_text(encoding="utf-8")
replacements = {
    'BONUS_SCRIPT="/home/admin/config.scripts/bonus.joinmarket-ng.sh"': (
        f'BONUS_SCRIPT="{helper_path}"'
    ),
    'sudo "$BONUS_SCRIPT" store-password "$password"': (
        'printf \'%s\\n\' "$password" | sudo "$BONUS_SCRIPT" store-password-stdin'
    ),
    'MAKER_ENV="${DATA_DIR}/.maker.env"': f'MAKER_ENV="{maker_env}"',
    'rm -f "$DATA_DIR/.maker.env"': ': > "$MAKER_ENV"',
}
for original, replacement in replacements.items():
    if content.count(original) != 1:
        raise SystemExit(f"expected exactly one upstream TUI occurrence: {original}")
    content = content.replace(original, replacement)

history_original = '''                  ensure_wallet_password "$CURRENT_WALLET" || exit 1
                  jm-wallet history "${HIST_ARGS[@]}"'''
history_replacement = '''                  ensure_wallet_password "$CURRENT_WALLET" || exit 1
                  # Retry automatic history reconstruction after a completed background rescan.
                  jm-wallet info >/dev/null || exit 1
                  jm-wallet history "${HIST_ARGS[@]}"'''
if history_original in content:
    if content.count(history_original) != 1:
        raise SystemExit("expected exactly one upstream TUI history invocation")
    content = content.replace(history_original, history_replacement)
elif content.count('jm-wallet info >/dev/null || exit 1') != 1:
    raise SystemExit("upstream TUI history invocation is incompatible")

destination_path.write_text(content, encoding="utf-8")
os.chmod(destination_path, 0o755)
PYTHON
  chown root:root "$TUI_PATH"
}

install_cli_wrappers() {
  local command_name
  local command_path
  local temporary_wrapper

  for command_name in "${CLI_COMMANDS[@]}"; do
    command_path="${CLI_LINK_DIR}/${command_name}"
    if [[ -e "$command_path" || -L "$command_path" ]]; then
      [[ -L "$command_path" && "$(readlink "$command_path")" == "$CLI_WRAPPER" ]] || \
        fail "CLI path is already occupied: ${command_path}"
    fi
  done

  temporary_wrapper=$(mktemp)
  cat > "$temporary_wrapper" <<EOF
#!/usr/bin/env bash
set -euo pipefail

command_name=\$(basename "\$0")
case "\$command_name" in
  jm-ng)
    exec sudo -- "$HELPER_PATH" menu
    ;;
  jm-maker | jm-wallet | jm-taker | jm-tumbler | jm-orderbook-watcher)
    exec sudo -- "$HELPER_PATH" cli "\$command_name" "\$@"
    ;;
  *)
    printf 'unsupported JoinMarket NG command: %s\n' "\$command_name" >&2
    exit 1
    ;;
esac
EOF
  if ! install -m 755 -o root -g root "$temporary_wrapper" "$CLI_WRAPPER"; then
    rm -f "$temporary_wrapper"
    fail "could not install the JoinMarket NG CLI wrapper"
  fi
  rm -f "$temporary_wrapper"

  for command_name in "${CLI_COMMANDS[@]}"; do
    ln -sfn "$CLI_WRAPPER" "${CLI_LINK_DIR}/${command_name}"
  done
}

remove_cli_wrappers() {
  local command_name
  local command_path

  for command_name in "${CLI_COMMANDS[@]}"; do
    command_path="${CLI_LINK_DIR}/${command_name}"
    if [[ -L "$command_path" && "$(readlink "$command_path")" == "$CLI_WRAPPER" ]]; then
      rm -f "$command_path"
    fi
  done
  rm -f "$CLI_WRAPPER"
}

configure_explicit() {
  local config_file
  local args=()

  require_root
  config_file=$(config_path)
  [[ -f "$config_file" ]] || fail "configuration does not exist: ${config_file}"
  args=(--config "$config_file" "$@")
  runuser -u "$SERVICE_USER" -- python3 "$CONFIG_WRITER" "${args[@]}"
}

configure_legacy() {
  local legacy_path="${1:-$LEGACY_CONFIG}"
  local legacy_copy
  local status=0

  [[ -f "$legacy_path" ]] || fail "legacy configuration does not exist: ${legacy_path}"
  legacy_copy=$(mktemp)
  install -m 600 -o "$SERVICE_USER" -g "$SERVICE_USER" "$legacy_path" "$legacy_copy"
  configure_explicit --legacy-config "$legacy_copy" || status=$?
  rm -f "$legacy_copy"
  return "$status"
}

configure_with_password() {
  local password="$1"
  shift
  local password_file
  local status=0

  password_file=$(mktemp)
  chown "$SERVICE_USER:$SERVICE_USER" "$password_file"
  chmod 600 "$password_file"
  printf '%s' "$password" > "$password_file"
  configure_explicit "$@" --rpc-password-file "$password_file" || status=$?
  rm -f "$password_file"
  return "$status"
}

configure_remote() {
  local network="$1"
  local rpc_user="$2"
  local rpc_host="$3"
  local rpc_port="$4"
  local rpc_password

  require_root
  IFS= read -r rpc_password || true
  configure_with_password "$rpc_password" --network "$network" --rpc-user "$rpc_user" \
    --rpc-host "$rpc_host" --rpc-port "$rpc_port"
  unset rpc_password
}

configure_local() {
  local requested_network="${1:-}"
  local network
  local port

  if [[ -n "$requested_network" ]]; then
    network=$(normalize_network "$requested_network") || fail "invalid network: ${requested_network}"
  else
    network=$(network_from_joinin_config)
  fi
  port=$(network_rpc_port "$network")
  load_local_rpc_credentials "$network"
  configure_with_password "$LOCAL_RPC_PASSWORD" --network "$network" --rpc-user "$LOCAL_RPC_USER" \
    --rpc-host "$LOCAL_RPC_HOST" --rpc-port "$port"
  unset LOCAL_RPC_PASSWORD
}

render_service_unit() {
  set_data_layout
  cat <<EOF
[Unit]
Description=JoinMarket-NG Maker Bot
After=network-online.target tor.service
Wants=network-online.target tor.service

[Service]
Type=simple
User=${SERVICE_USER}
Group=${SERVICE_USER}
Environment=HOME=${SERVICE_HOME}
Environment=PATH=${VENV_DIR}/bin:/usr/local/bin:/usr/bin:/bin
EnvironmentFile=-${MAKER_ENV}
ExecStartPre=+${HELPER_PATH} prestart
ExecStart=${HELPER_PATH} run-maker
ExecStopPost=+/usr/bin/truncate -s 0 ${MAKER_ENV}
Restart=on-failure
RestartSec=30
StartLimitIntervalSec=0
StandardOutput=append:${DATA_DIR}/logs/maker.log
StandardError=append:${DATA_DIR}/logs/maker.log

[Install]
WantedBy=multi-user.target
EOF
}

install_service() {
  render_service_unit > "$SERVICE_PATH"
  chmod 644 "$SERVICE_PATH"
  systemctl daemon-reload
}

render_sudoers() {
  cat <<EOF
${SERVICE_USER} ALL=(root) NOPASSWD: ${HELPER_PATH} maker-start
${SERVICE_USER} ALL=(root) NOPASSWD: ${HELPER_PATH} maker-stop
${SERVICE_USER} ALL=(root) NOPASSWD: ${HELPER_PATH} maker-status
${SERVICE_USER} ALL=(root) NOPASSWD: ${HELPER_PATH} store-password-stdin
${SERVICE_USER} ALL=(root) NOPASSWD: ${HELPER_PATH} update
${SERVICE_USER} ALL=(root) NOPASSWD: ${HELPER_PATH} update *
EOF
}

install_sudoers() {
  local temporary_sudoers

  temporary_sudoers=$(mktemp)
  render_sudoers > "$temporary_sudoers"
  visudo -cf "$temporary_sudoers"
  install -m 440 "$temporary_sudoers" "$SUDOERS_PATH"
  rm -f "$temporary_sudoers"
}

disable_legacy_maker() {
  systemctl disable --now yg-privacyenhanced.service >/dev/null 2>&1 || true
}

on_command() {
  local config_file
  local config_existed=0

  require_root
  require_privileged_helpers
  install_dependencies
  ensure_service_user
  ensure_runtime_layout
  ensure_data_layout
  config_file=$(config_path)
  [[ -f "$config_file" ]] && config_existed=1
  add_tor_group
  ensure_compatibility_path
  disable_legacy_maker
  if [[ -x "$VENV_DIR/bin/jm-ng" ]]; then
    run_upstream_installer "$RELEASE_TAG" update
  else
    run_upstream_installer "$RELEASE_TAG" install
  fi
  install_tui_wrapper
  install_cli_wrappers
  ensure_data_layout
  if [[ "$config_existed" -eq 0 ]]; then
    if [[ -f "$LEGACY_CONFIG" ]]; then
      configure_legacy "$LEGACY_CONFIG"
    elif ! configure_local; then
      printf '%s\n' "warning: local Bitcoin RPC credentials are not ready; configure before use" >&2
    fi
  fi
  [[ -f "$config_file" ]] && runuser -u "$SERVICE_USER" -- chmod 600 "$config_file"
  install_service
  install_sudoers
  if toml_has_wallet_password "$config_file"; then
    systemctl enable joinmarket-ng-maker.service
  else
    systemctl disable joinmarket-ng-maker.service >/dev/null 2>&1 || true
  fi
  printf '%s\n' "installed=${APP_ID}"
}

restore_temporary_environment() {
  local backup_file="$1"
  local current_env

  current_env=$(env_path)
  install -m 600 -o "$SERVICE_USER" -g "$SERVICE_USER" "$backup_file" "$current_env"
}

finish_update() {
  local status="$1"
  local backup_file="$2"
  local was_running="$3"

  trap - RETURN
  if [[ "$status" -ne 0 && "$was_running" -eq 1 ]]; then
    if [[ -n "$backup_file" ]] && ! restore_temporary_environment "$backup_file"; then
      printf '%s\n' "warning: failed to restore temporary maker credentials" >&2
    fi
    if ! systemctl start joinmarket-ng-maker.service; then
      printf '%s\n' "warning: failed to restart maker after update failure" >&2
    fi
  fi
  [[ -z "$backup_file" ]] || rm -f "$backup_file"
  return "$status"
}

update_command() {
  local tag="${1:-$RELEASE_TAG}"
  local config_file
  local environment_file
  local backup_file=""
  local was_running=0

  trap 'finish_update "$?" "${backup_file:-}" "${was_running:-0}"' RETURN

  require_root
  is_valid_release_tag "$tag" || fail "release tag must be a signed version tag"
  [[ -x "$VENV_DIR/bin/jm-ng" ]] || fail "${APP_ID} is not installed"
  ensure_service_user
  ensure_runtime_layout
  require_safe_data_layout
  config_file=$(config_path)
  environment_file=$(env_path)
  if systemctl is-active --quiet joinmarket-ng-maker.service; then
    was_running=1
    if [[ -f "$environment_file" ]] && ! toml_has_wallet_password "$config_file"; then
      backup_file=$(mktemp)
      install -m 600 "$environment_file" "$backup_file"
    fi
    systemctl stop joinmarket-ng-maker.service
  fi
  run_upstream_installer "$tag" update
  [[ "$?" -eq 0 ]] || return 1
  install_tui_wrapper
  [[ "$?" -eq 0 ]] || return 1
  install_cli_wrappers
  [[ "$?" -eq 0 ]] || return 1
  ensure_data_layout
  [[ "$?" -eq 0 ]] || return 1
  install_service
  [[ "$?" -eq 0 ]] || return 1
  install_sudoers
  [[ "$?" -eq 0 ]] || return 1
  if [[ "$was_running" -eq 1 ]]; then
    if toml_has_wallet_password "$config_file"; then
      systemctl start joinmarket-ng-maker.service
    elif [[ -n "$backup_file" ]]; then
      restore_temporary_environment "$backup_file"
      systemctl start joinmarket-ng-maker.service
    else
      printf '%s\n' "maker was not restarted because no password is available" >&2
    fi
  fi
  printf '%s\n' "updated=${tag}"
}

off_command() {
  local environment_file

  require_root
  set_data_layout
  environment_file=$(env_path)
  systemctl disable --now joinmarket-ng-maker.service >/dev/null 2>&1 || true
  rm -f "$SERVICE_PATH" "$SUDOERS_PATH" "$environment_file"
  rm -f "$TUI_PATH"
  remove_cli_wrappers
  systemctl daemon-reload
  rm -rf "$VENV_DIR"
  rm -rf "$RUNTIME_DIR"
  userdel "$SERVICE_USER" >/dev/null 2>&1 || true
  printf '%s\n' "preserved_data=${DATA_DIR}"
}

status_command() {
  local installed=0
  local running=0
  local version="$RELEASE_TAG"

  if [[ -x "$VENV_DIR/bin/jm-ng" ]]; then
    installed=1
    version=$(runuser -u "$SERVICE_USER" -- "$VENV_DIR/bin/python" -c \
      'from importlib.metadata import version; print(version("jmcore"))' 2>/dev/null || printf '%s' "$RELEASE_TAG")
  fi
  if systemctl is-active --quiet joinmarket-ng-maker.service 2>/dev/null; then
    running=1
  fi
  printf '%s\n' "appID=${APP_ID}"
  printf '%s\n' "version=${version}"
  printf '%s\n' "isInstalled=${installed}"
  printf '%s\n' "isRunning=${running}"
}

menu_command() {
  local config_file
  local run_command=()

  require_root
  [[ -x "$VENV_DIR/bin/jm-ng" ]] || fail "${APP_ID} is not installed"
  require_root_owned_file "$TUI_PATH"
  ensure_runtime_layout
  config_file=$(config_path)
  run_command=("$VENV_DIR/bin/jm-ng")
  if is_onion_rpc_config "$config_file"; then
    run_command=(torsocks "${run_command[@]}")
  fi
  runuser -u "$SERVICE_USER" -- env HOME="$SERVICE_HOME" JOINMARKET_DATA_DIR="$DATA_DIR" \
    PATH="${VENV_DIR}/bin:/usr/local/bin:/usr/bin:/bin" JM_NG_MENU="$TUI_PATH" "${run_command[@]}"
}

cli_command() {
  local command_name="${1:-}"
  local config_file
  local run_command=()

  require_root
  shift || true
  case "$command_name" in
    jm-maker | jm-wallet | jm-taker | jm-tumbler | jm-orderbook-watcher) ;;
    *) fail "unsupported JoinMarket NG command: ${command_name}" ;;
  esac
  [[ -x "${VENV_DIR}/bin/${command_name}" ]] || fail "${APP_ID} command is not installed: ${command_name}"
  config_file=$(config_path)
  [[ -f "$config_file" ]] || fail "configuration does not exist: ${config_file}"

  run_command=("${VENV_DIR}/bin/${command_name}" "$@")
  if is_onion_rpc_config "$config_file"; then
    run_command=(torsocks "${run_command[@]}")
  fi
  runuser -u "$SERVICE_USER" -- env HOME="$SERVICE_HOME" JOINMARKET_DATA_DIR="$DATA_DIR" \
    PATH="${VENV_DIR}/bin:/usr/local/bin:/usr/bin:/bin" "${run_command[@]}"
}

integrate_command() {
  require_root
  require_privileged_helpers
  [[ -x "$VENV_DIR/bin/jm-ng" ]] || fail "${APP_ID} is not installed"
  install_tui_wrapper
  install_cli_wrappers
}

prestart_command() {
  local config_file
  local mnemonic_file

  require_root
  config_file=$(config_path)
  [[ -f "$config_file" ]] || fail "configuration does not exist: ${config_file}"
  validate_rpc_config "$config_file" || fail "RPC configuration is invalid"
  if is_local_rpc_config "$config_file"; then
    configure_local
  fi
  mnemonic_file=$(configured_mnemonic_file "$config_file") || \
    fail "configured mnemonic_file is unavailable"
  [[ -f "$mnemonic_file" ]] || fail "configured mnemonic_file does not exist"
}

sync_config_command() {
  local config_file
  local mnemonic_file

  require_root
  config_file=$(config_path)
  [[ -f "$config_file" ]] || fail "configuration does not exist: ${config_file}"
  validate_rpc_config "$config_file" || fail "RPC configuration is invalid"
  if is_local_rpc_config "$config_file"; then
    configure_local
  fi
  mnemonic_file=$(configured_mnemonic_file "$config_file" || true)
  if [[ -n "$mnemonic_file" && ! -f "$mnemonic_file" ]]; then
    fail "configured mnemonic_file does not exist"
  fi
}

run_maker_command() {
  local config_file

  config_file=$(config_path)
  if is_onion_rpc_config "$config_file"; then
    exec torsocks "$VENV_DIR/bin/jm-maker" start
  fi
  exec "$VENV_DIR/bin/jm-maker" start
}

maker_start_command() {
  local config_file
  local environment_file
  local password

  require_root
  ensure_runtime_layout
  config_file=$(config_path)
  environment_file=$(env_path)
  [[ -f "$config_file" ]] || fail "configuration does not exist: ${config_file}"
  if ! toml_has_wallet_password "$config_file" && ! grep -q '^MNEMONIC_PASSWORD=' "$environment_file" 2>/dev/null; then
    IFS= read -r -s -p "Wallet encryption password (Enter to skip if unencrypted): " password
    printf '\n'
    umask 077
    printf 'MNEMONIC_PASSWORD="%s"\n' "$(systemd_quote "$password")" | runuser \
      -u "$SERVICE_USER" -- tee "$environment_file" >/dev/null
    runuser -u "$SERVICE_USER" -- chmod 600 "$environment_file"
    unset password
  fi
  systemctl start joinmarket-ng-maker.service
}

maker_stop_command() {
  require_root
  ensure_runtime_layout
  systemctl stop joinmarket-ng-maker.service
  truncate -s 0 "$(env_path)"
}

maker_status_command() {
  require_root
  systemctl status joinmarket-ng-maker.service --no-pager -l
}

store_password_command() {
  local config_file

  require_root
  [[ "$#" -eq 1 ]] || fail "store-password requires exactly one password argument"
  config_file=$(config_path)
  [[ -f "$config_file" ]] || fail "configuration does not exist: ${config_file}"
  toml_store_wallet_password "$config_file" "$1"
  systemctl enable joinmarket-ng-maker.service
  printf '%s\n' "wallet password stored"
}

store_password_stdin_command() {
  local password

  require_root
  IFS= read -r password || true
  store_password_command "$password"
  unset password
}

usage() {
  printf '%s\n' "usage: $0 {status|verify-release|bootstrap|on|update|off|menu|cli|integrate|configure|configure-remote|configure-legacy|configure-local|sync-config|prestart|maker-start|maker-stop|maker-status|store-password|store-password-stdin|run-maker}"
}

main() {
  local command="${1:-}"

  case "$command" in
    status) status_command ;;
    verify-release) verify_release "${2:-$RELEASE_TAG}" ;;
    bootstrap) bootstrap_command ;;
    on) on_command ;;
    update) update_command "${2:-$RELEASE_TAG}" ;;
    off) off_command ;;
    menu) menu_command ;;
    cli)
      shift
      cli_command "$@"
      ;;
    integrate) integrate_command ;;
    configure)
      shift
      configure_explicit "$@"
      ;;
    configure-remote) configure_remote "${2:-}" "${3:-}" "${4:-}" "${5:-}" ;;
    configure-legacy) configure_legacy "${2:-$LEGACY_CONFIG}" ;;
    configure-local) configure_local "${2:-}" ;;
    sync-config) sync_config_command ;;
    prestart) prestart_command ;;
    maker-start) maker_start_command ;;
    maker-stop) maker_stop_command ;;
    maker-status) maker_status_command ;;
    store-password)
      shift
      store_password_command "$@"
      ;;
    store-password-stdin) store_password_stdin_command ;;
    run-maker) run_maker_command ;;
    *)
      usage >&2
      return 1
      ;;
  esac
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
