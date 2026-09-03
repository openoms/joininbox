#!/usr/bin/env bats

root_dir="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
build="$root_dir/build_joininbox.sh"
start="$root_dir/scripts/start.joininbox.sh"
main_menu="$root_dir/scripts/menu.sh"
remote_menu="$root_dir/scripts/menu.bitcoinrpc.sh"
config_menu="$root_dir/scripts/menu.config.sh"
update_menu="$root_dir/scripts/menu.update.sh"
advanced_update_menu="$root_dir/scripts/menu.update.advanced.sh"
bitcoin_functions="$root_dir/scripts/_functions.bitcoincore.sh"
bitcoin_install="$root_dir/scripts/install.bitcoincore.sh"
standalone_functions="$root_dir/scripts/standalone/_functions.standalone.sh"
commands="$root_dir/scripts/_commands.sh"
functions="$root_dir/scripts/_functions.sh"

assert_absent() {
  ! grep -Eq "$2" "$1"
}

@test "build installs JoinMarket NG with Python 3.11 or newer only" {
  grep -Fqx '/usr/local/libexec/joininbox/install.joinmarket-ng.sh on || exit 1' "$build"
  grep -Fq 'install -m 755 -o root -g root' "$build"
  grep -Fq '/usr/bin/python3.13' "$build"
  grep -Fq '/usr/bin/python3.12' "$build"
  grep -Fq '/usr/bin/python3.11' "$build"
  assert_absent "$build" 'python3\.(10|9|8)|without-qt|qtgui|joinmarket-clientserver|jmvenv|install\.joinmarket\.sh'
}

@test "active startup, main menu, and update flows do not dispatch legacy JoinMarket" {
  for script in "$build" "$start" "$main_menu" "$update_menu" "$advanced_update_menu"; do
    assert_absent "$script" 'install\.joinmarket\.sh|joinmarket-clientserver|jmvenv|generateJMconfig|checkRPCwallet|stopYG|qtgui|menu\.(quickstart|wallet|yg|payjoin|orderbook)\.sh'
  done
  grep -Fq 'install.joinmarket-ng.sh status' "$start"
  grep -Fq 'install.joinmarket-ng.sh on' "$start"
  grep -Fq 'install.joinmarket-ng.sh integrate' "$start"
  grep -Fq 'install.joinmarket-ng.sh menu' "$main_menu"
  grep -Fq 'install.joinmarket-ng.sh update 0.38.0' "$update_menu"
}

@test "startup synchronizes non-secret state from the NG TOML configuration" {
  grep -Fq 'import tomllib' "$start"
  grep -Fq '/home/joinmarketng/.joinmarket-ng/config.toml' "$start"
  grep -Fq 'network_config' "$start"
  grep -Fq 'RPCoverTor' "$start"
  assert_absent "$start" 'joinmarket\.cfg|\.jmdat|watch-only-descriptor-wallet|wallet-tool|qtgui'
}

@test "main configuration exposes only NG and Bitcoin connection controls" {
  grep -Fq 'JOINMARKETNG "Open JoinMarket NG"' "$main_menu"
  grep -Fq 'NGCONF "Edit the JoinMarket NG configuration"' "$config_menu"
  grep -Fq '"/home/joinmarketng/.joinmarket-ng/config.toml" "joinmarketng"' "$config_menu"
  grep -Fq 'install.joinmarket-ng.sh sync-config' "$config_menu"
  assert_absent "$config_menu" 'joinmarket\.cfg|generateJMconfig|install\.joinmarket\.sh|JMCONF|RESET'
}

@test "remote RPC configuration uses quoted explicit NG arguments and records topology" {
  grep -Fq 'torsocks curl' "$remote_menu"
  grep -Fq -- '--config "$rpcAuthConfig"' "$remote_menu"
  grep -Fq 'configure-remote' "$remote_menu"
  grep -Fq 'printf '\''%s'\'' "$rpc_pass" |' "$remote_menu"
  grep -Fq 'connectedRemoteNode=on' "$remote_menu"
  grep -Fq 'RPCoverTor=on' "$remote_menu"
  grep -Fq 'RPCoverTor=off' "$remote_menu"
  grep -Fq 'network=mainnet' "$remote_menu"
  assert_absent "$remote_menu" 'generateJMconfig|set\.bitcoinrpc\.py|checkRPCwallet|rpc_wallet|echo.*rpc_pass|--rpc-password'
}

@test "local and signet configuration use lifecycle helpers and disable remote RPC state" {
  grep -Fq 'install.joinmarket-ng.sh configure-local "$network"' "$bitcoin_functions"
  grep -Fq '"connectedRemoteNode=off" "RPCoverTor=off"' "$bitcoin_functions"
  grep -Fq 'install.joinmarket-ng.sh configure-local signet' "$bitcoin_install"
  grep -Fq '"network=signet" "connectedRemoteNode=off" "RPCoverTor=off"' "$bitcoin_install"
  grep -Fq 'connectLocalNode mainnet' "$standalone_functions"
  assert_absent "$bitcoin_install" 'joinmarket\.cfg|generateJMconfig|watch-only-descriptor-wallet'
  assert_absent "$standalone_functions" 'watch-only-descriptor-wallet|createwallet'
}

@test "Bitcoin Core installation accepts daemon-specific version output" {
  local version_pattern="^Bitcoin Core (daemon )?version v?[0-9]+(\\.[0-9]+)+"

  grep -Fq "grep -Eq '$version_pattern'" "$bitcoin_functions"
  grep -Fq "grep -Eq '$version_pattern'" "$standalone_functions"
  assert_absent "$bitcoin_functions" 'grep -c "Bitcoin Core version"'
  assert_absent "$standalone_functions" 'grep "Bitcoin Core version"'
}

@test "signet orders Bitcoin Core after network and Tor services" {
  grep -Fq 'Wants=network-online.target tor@default.service' "$bitcoin_functions"
  grep -Fq 'After=network-online.target tor@default.service' "$bitcoin_functions"
}

@test "version, update, and shell command wiring targets JoinMarket NG" {
  grep -Fq 'currentJMNGversion=' "$functions"
  grep -Fq '/home/joinmarketng/venv/bin/python' "$functions"
  grep -Fq 'JMNGCUSTOM' "$advanced_update_menu"
  grep -Fq 'install.joinmarket-ng.sh update "$updateVersion"' "$advanced_update_menu"
  assert_absent "$advanced_update_menu" 'JMPR|JMCOMMIT|JMCUSTOM|install\.joinmarket\.sh|stopYG'
  grep -Fq 'function jm-ng()' "$commands"
  grep -Fq 'install.joinmarket-ng.sh menu' "$commands"
  assert_absent "$commands" 'function stats|function qtgui|joinmarket-clientserver|jmvenv'
}

@test "privileged NG callers use promoted root-owned helpers" {
  for script in "$build" "$start" "$main_menu" "$remote_menu" "$config_menu" \
    "$update_menu" "$advanced_update_menu" "$bitcoin_functions" "$bitcoin_install" \
    "$standalone_functions" "$commands" "$functions"; do
    if [ "$script" = "$start" ]; then
      [ "$(grep -Ec 'sudo /home/joinmarket/install\.joinmarket-ng\.sh bootstrap' "$script")" -eq 1 ]
    else
      assert_absent "$script" 'sudo /home/joinmarket/install\.joinmarket-ng\.sh'
    fi
  done
  grep -Fq '/usr/local/libexec/joininbox/install.joinmarket-ng.sh' "$start"
  grep -Fq '/usr/local/libexec/joininbox/set.joinmarket-ng-config.py' "$build"
}

@test "production builds trust the JoinMarket NG signing key" {
  grep -Fq '1C53A412D11EF3051704419C44912E1E03005B31' "$build"
  grep -Fq 'joinmarket-ng/0c3716b53c132bd46fc92d240beebe7158a06e16/signatures/pubkeys/' "$build"
}

@test "all migrated shell files pass bash syntax validation" {
  local scripts=(
    "$build"
    "$main_menu"
    "$start"
    "$config_menu"
    "$remote_menu"
    "$bitcoin_install"
    "$functions"
    "$bitcoin_functions"
    "$standalone_functions"
    "$update_menu"
    "$advanced_update_menu"
    "$commands"
  )

  run bash -n "${scripts[@]}"
  [ "$status" -eq 0 ]
}

@test "Tor repositories use a fingerprint-checked scoped keyring" {
  local keyring="signed-by=/usr/share/keyrings/deb.torproject.org-keyring.gpg"

  grep -Fq 'A3C4F0F979CAA22CDBA8F512EE8CBC9E886DDD89' "$build"
  grep -Fq '2265EB4CB2BF88D900AE8D1B74A941BA219EC810' "$build"
  grep -Fq 'gpg --show-keys --with-colons' "$build"
  grep -Fq "$keyring" "$build"
  grep -Fq "$keyring" "$functions"
  ! grep -Fq 'apt-key add' "$build"
}
