#!/usr/bin/env bats

root_dir="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
script="$root_dir/scripts/install.joinmarket-ng.sh"

setup() {
  source "$script"
  runuser() {
    shift 3
    "$@"
  }
}

@test "bash syntax is valid" {
  run bash -n "$script"
  [ "$status" -eq 0 ]
}

@test "pins 0.38.0 and invokes an immutable verified installer with secure flags" {
  run grep -F 'RELEASE_TAG="0.38.0"' "$script"
  [ "$status" -eq 0 ]
  run grep -F 'joinmarket-ng/${VERIFIED_COMMIT}/install.sh' "$script"
  [ "$status" -eq 0 ]
  run grep -F 'installer_args=(--yes --version "$tag" --skip-tor)' "$script"
  [ "$status" -eq 0 ]
  [ "$(grep -Ec -- '--skip-verify|--no-hash-deps' "$script")" -eq 0 ]
  grep -Fq '"1C53A412D11EF3051704419C44912E1E03005B31"' "$script"
  grep -Fq '"9253062A4F92D63459085CA62D230520212A5901"' "$script"
  ! grep -Fq 'trusted-keys.txt' "$script"
  grep -Fq 'VALIDSIG' "$script"
}

@test "only version-shaped signed release tags are accepted" {
  is_valid_release_tag 0.38.0
  is_valid_release_tag 1.2.3-rc.1
  ! is_valid_release_tag main
  ! is_valid_release_tag master
  ! is_valid_release_tag 0.36
  ! is_valid_release_tag '0.38.0;main'
}

@test "manifest commit matching requires equal lowercase 40 character commits" {
  commit=0123456789abcdef0123456789abcdef01234567
  printf 'commit: %s\n' "$commit" > "$BATS_TEST_TMPDIR/release"
  printf 'commit: %s\n' "$commit" > "$BATS_TEST_TMPDIR/local"
  manifest_commit_matches "$BATS_TEST_TMPDIR/release" "$BATS_TEST_TMPDIR/local"
  printf 'commit: 0123456789ABCDEF0123456789abcdef01234567\n' > "$BATS_TEST_TMPDIR/local"
  ! manifest_commit_matches "$BATS_TEST_TMPDIR/release" "$BATS_TEST_TMPDIR/local"
  printf 'commit: short\n' > "$BATS_TEST_TMPDIR/local"
  ! manifest_commit_matches "$BATS_TEST_TMPDIR/release" "$BATS_TEST_TMPDIR/local"
}

@test "network normalization and fixed JoininBox RPC ports map correctly" {
  [ "$(normalize_network main)" = mainnet ]
  [ "$(normalize_network testnet)" = testnet ]
  [ "$(normalize_network sig)" = signet ]
  [ "$(network_rpc_port mainnet)" = 8332 ]
  [ "$(network_rpc_port testnet)" = 18332 ]
  [ "$(network_rpc_port signet)" = 38332 ]
  [ "$(standalone_bitcoin_config mainnet)" = /home/bitcoin/.bitcoin/bitcoin.conf ]
  [ "$(standalone_bitcoin_config testnet)" = /home/bitcoin/.bitcoin/bitcoin.conf ]
  [ "$(standalone_bitcoin_config signet)" = /home/joinmarket/.bitcoin/bitcoin.conf ]
  ! normalize_network regtest
}

@test "bitcoin.conf parser preserves all special characters after the first equals sign" {
  bitcoin_conf="$BATS_TEST_TMPDIR/bitcoin.conf"
  printf 'rpcuser=user=with spaces&$\\\nrpcpassword="pass=with&$\\quotes"\n' > "$bitcoin_conf"
  [ "$(read_bitcoin_conf_key "$bitcoin_conf" rpcuser)" = 'user=with spaces&$\' ]
  [ "$(read_bitcoin_conf_key "$bitcoin_conf" rpcpassword)" = 'pass=with&$\quotes' ]
}

@test "joinin.conf parser removes assignment quotes without evaluating shell input" {
  JOININ_CONFIG="$BATS_TEST_TMPDIR/joinin.conf"
  printf "network='signet'\nunsafe='\$(touch /tmp/must-not-run)'\n" > "$JOININ_CONFIG"
  [ "$(joinin_value network)" = signet ]
  [ "$(joinin_value unsafe)" = '$(touch /tmp/must-not-run)' ]
  [ ! -e /tmp/must-not-run ]
}

@test "onion RPC detection reads the bitcoin TOML section" {
  onion_config="$BATS_TEST_TMPDIR/onion.toml"
  direct_config="$BATS_TEST_TMPDIR/direct.toml"
  printf '[bitcoin]\nrpc_url = "http://NODE.ONION:8332"\n' > "$onion_config"
  printf '[bitcoin]\nrpc_url = "http://127.0.0.1:8332"\n' > "$direct_config"
  is_onion_rpc_config "$onion_config"
  ! is_onion_rpc_config "$direct_config"
}

@test "local RPC detection distinguishes loopback from manually configured remote nodes" {
  local_config="$BATS_TEST_TMPDIR/local.toml"
  remote_config="$BATS_TEST_TMPDIR/remote.toml"
  printf '[bitcoin]\nrpc_url = "http://localhost:8332"\n' > "$local_config"
  printf '[bitcoin]\nrpc_url = "http://node.example:8332"\n' > "$remote_config"
  is_local_rpc_config "$local_config"
  ! is_local_rpc_config "$remote_config"
}

@test "RPC validation rejects malformed or incomplete TOML before topology handling" {
  valid_config="$BATS_TEST_TMPDIR/valid.toml"
  invalid_config="$BATS_TEST_TMPDIR/invalid.toml"
  cat > "$valid_config" <<'EOF'
[bitcoin]
rpc_url = "http://127.0.0.1:8332"
rpc_user = "user"
rpc_password = "password"
[network_config]
network = "mainnet"
EOF
  printf '[bitcoin]\nrpc_url = [\n' > "$invalid_config"
  validate_rpc_config "$valid_config"
  ! validate_rpc_config "$invalid_config"
}

@test "TOML password update escapes values and writes only the wallet section" {
  config="$BATS_TEST_TMPDIR/config.toml"
  password=$'quote" slash\\ control\t'
  cat > "$config" <<'EOF'
[bitcoin]
mnemonic_password = "not-wallet"

[wallet]
mnemonic_file = "/tmp/wallet"

[maker]
enabled = true
EOF
  toml_store_wallet_password "$config" "$password"
  run python3 - "$config" "$password" <<'PYTHON'
import sys
import tomllib
from pathlib import Path

data = tomllib.loads(Path(sys.argv[1]).read_text())
assert data["wallet"]["mnemonic_password"] == sys.argv[2]
assert data["bitcoin"]["mnemonic_password"] == "not-wallet"
PYTHON
  [ "$status" -eq 0 ]
}

@test "service definition runs prestart as root and removes temporary credentials" {
  unit="$BATS_TEST_TMPDIR/joinmarket-ng-maker.service"
  render_service_unit > "$unit"
  run grep -F 'User=joinmarketng' "$unit"
  [ "$status" -eq 0 ]
  run grep -F 'ExecStartPre=+/usr/local/libexec/joininbox/install.joinmarket-ng.sh prestart' "$unit"
  [ "$status" -eq 0 ]
  run grep -F 'ExecStart=/usr/local/libexec/joininbox/install.joinmarket-ng.sh run-maker' "$unit"
  [ "$status" -eq 0 ]
  run grep -F 'EnvironmentFile=-/run/joinmarket-ng/maker.env' "$unit"
  [ "$status" -eq 0 ]
  run grep -F 'ExecStopPost=+/usr/bin/truncate -s 0 /run/joinmarket-ng/maker.env' "$unit"
  [ "$status" -eq 0 ]
  run grep -F 'RestartSec=30' "$unit"
  [ "$status" -eq 0 ]
}

@test "sudoers grants only maker controls, password storage, and signed updates" {
  sudoers="$BATS_TEST_TMPDIR/joinmarketng-maker"
  render_sudoers > "$sudoers"
  [ "$(wc -l < "$sudoers")" -eq 6 ]
  run grep -Ev 'maker-start|maker-stop|maker-status|store-password-stdin|update( \*)?$' "$sudoers"
  [ "$status" -eq 1 ]
  run grep -F 'ALL=(root)' "$sudoers"
  [ "$status" -eq 0 ]
  ! grep -Fq "$COMPATIBILITY_PATH" "$sudoers"
  ! grep -Fq 'store-password *' "$sudoers"
}

@test "uninstall preserves data while deleting only the venv and integration files" {
  run grep -F 'rm -rf "$VENV_DIR"' "$script"
  [ "$status" -eq 0 ]
  run grep -F 'userdel "$SERVICE_USER"' "$script"
  [ "$status" -eq 0 ]
  run grep -F 'preserved_data=${DATA_DIR}' "$script"
  [ "$status" -eq 0 ]
  [ "$(grep -Ec 'rm -rf .*DATA_DIR|userdel -r' "$script")" -eq 0 ]
}

@test "preserved data is recursively reassigned to a recreated service account" {
  grep -Fq 'install -d -m 750 -o root -g "$SERVICE_USER" "$SERVICE_HOME"' "$script"
  grep -Fq 'chown -R --no-dereference "$SERVICE_USER:$SERVICE_USER" "$DATA_DIR"' "$script"
  [ "$(grep -Fc 'ensure_service_user' "$script")" -eq 3 ]
}

@test "root data setup rejects service-controlled symlinks" {
  local data_dir="$BATS_TEST_TMPDIR/data"
  local target_dir="$BATS_TEST_TMPDIR/target"

  mkdir "$target_dir"
  ln -s "$target_dir" "$data_dir"
  set_data_layout() { DATA_DIR="$data_dir"; }
  stat() {
    case "$2" in
      %u) printf '%s\n' 0 ;;
      %a) printf '%s\n' 755 ;;
    esac
  }
  run require_safe_data_layout
  [ "$status" -ne 0 ]
  [[ "$output" == *"managed data path must not be a symlink"* ]]
}

@test "runtime credentials reject a substituted parent directory" {
  local target_dir="$BATS_TEST_TMPDIR/runtime-target"

  mkdir "$target_dir"
  RUNTIME_DIR="$BATS_TEST_TMPDIR/runtime"
  MAKER_ENV="$RUNTIME_DIR/maker.env"
  ln -s "$target_dir" "$RUNTIME_DIR"
  run ensure_runtime_layout
  [ "$status" -ne 0 ]
  [[ "$output" == *"must not be a symlink"* ]]
}

@test "failed updates restore credentials and restart a previously active maker" {
  local mock_bin="$BATS_TEST_TMPDIR/bin"
  local state_dir="$BATS_TEST_TMPDIR/state"
  local calls="$BATS_TEST_TMPDIR/systemctl.calls"

  mkdir -p "$mock_bin" "$state_dir" "$BATS_TEST_TMPDIR/venv/bin"
  touch "$BATS_TEST_TMPDIR/venv/bin/jm-ng"
  chmod +x "$BATS_TEST_TMPDIR/venv/bin/jm-ng"
  printf 'wallet password\n' > "$state_dir/.maker.env"
  cat > "$mock_bin/systemctl" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$SYSTEMCTL_CALLS"
case "$1" in
  is-active) exit 0 ;;
  stop) rm -f "$ENVIRONMENT_FILE" ;;
esac
EOF
  chmod +x "$mock_bin/systemctl"

  VENV_DIR="$BATS_TEST_TMPDIR/venv"
  SERVICE_USER="$(id -un)"
  DATA_DIR="$state_dir"
  PATH="$mock_bin:$PATH"
  SYSTEMCTL_CALLS="$calls"
  ENVIRONMENT_FILE="$state_dir/.maker.env"
  export SYSTEMCTL_CALLS ENVIRONMENT_FILE
  require_root() { return 0; }
  set_data_layout() { DATA_DIR="$state_dir"; }
  config_path() { printf '%s/config.toml\n' "$state_dir"; }
  env_path() { printf '%s/.maker.env\n' "$state_dir"; }
  toml_has_wallet_password() { return 1; }
  run_upstream_installer() { return 0; }
  install_tui_wrapper() { return 1; }
  ensure_service_user() { return 0; }
  ensure_runtime_layout() { return 0; }

  run update_command 0.38.0
  [ "$status" -ne 0 ]
  [ "$(cat "$state_dir/.maker.env")" = "wallet password" ]
  [ "$(grep -Fc 'start joinmarket-ng-maker.service' "$calls")" -eq 1 ]
}

@test "privileged operations use root-owned non-writable helper copies" {
  grep -Fq 'PRIVILEGED_DIR="/usr/local/libexec/joininbox"' "$script"
  grep -Fq 'require_privileged_helpers' "$script"
  grep -Fq "8#022" "$script"
  grep -Fq 'bootstrap) bootstrap_command' "$script"
}

@test "RPC configuration transports passwords through temporary files" {
  grep -Fq -- '--rpc-password-file "$password_file"' "$script"
  [ "$(grep -Ec -- 'configure_explicit .*--rpc-password ' "$script")" -eq 0 ]
  grep -Fq 'runuser -u "$SERVICE_USER" -- python3 "$CONFIG_WRITER"' "$script"
  grep -Fq 'runuser -u "$SERVICE_USER" -- python3 - "$config_file" "$password"' "$script"
  ! grep -Eq '^[[:space:]]+(chown|chmod).*config_file' "$script"
}

@test "the appliance TUI uses the root helper and stdin password transport" {
  grep -Fq 'JM_NG_MENU="$TUI_PATH"' "$script"
  grep -Fq 'store-password-stdin' "$script"
  grep -Fq 'MAKER_ENV="${RUNTIME_DIR}/maker.env"' "$script"
  grep -Fq "'MAKER_ENV=\"\${DATA_DIR}/.maker.env\"'" "$script"
  grep -Fq "'rm -f \"\$DATA_DIR/.maker.env\"'" "$script"
  grep -Fq "expected exactly one upstream TUI occurrence" "$script"
  grep -Fq 'jm-wallet info >/dev/null || exit 1' "$script"
  grep -Fq 'upstream TUI history invocation is incompatible' "$script"
  grep -Fq 'PATH="${VENV_DIR}/bin:/usr/local/bin:/usr/bin:/bin" JM_NG_MENU="$TUI_PATH"' "$script"
}

@test "the appliance exposes allowlisted NG commands through root-owned wrappers" {
  grep -Fq 'CLI_WRAPPER="${PRIVILEGED_DIR}/joinmarket-ng-cli"' "$script"
  grep -Fq 'CLI_COMMANDS=(jm-ng jm-maker jm-wallet jm-taker jm-tumbler jm-orderbook-watcher)' "$script"
  grep -Fq 'exec sudo -- "$HELPER_PATH" cli "\$command_name" "\$@"' "$script"
  grep -Fq 'JOINMARKET_DATA_DIR="$DATA_DIR"' "$script"
  grep -Fq 'runuser -u "$SERVICE_USER"' "$script"
  grep -Fq 'install_cli_wrappers' "$script"
  grep -Fq 'remove_cli_wrappers' "$script"
  ! grep -Eq 'cli_command.*(eval|bash -c|sh -c)' "$script"
}

@test "secret literals are not emitted by the helper" {
  run bash -c 'grep -En "(echo|printf).*\\$(LOCAL_RPC_USER|LOCAL_RPC_PASSWORD|password)" "$1" | grep -v ">"' _ "$script"
  [ "$status" -eq 1 ]
}

@test "unknown command fails through the main router without privileged operations" {
  run bash "$script" unknown-command
  [ "$status" -ne 0 ]
  [[ "$output" == usage:* ]]
}
