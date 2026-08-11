#!/usr/bin/env bats

root_dir="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
PATH="/home/joinmarket/bitcoin:/usr/local/bin:$PATH"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    skip "$1 is required"
  fi
}

setup() {
  require_command bitcoind
  require_command bitcoin-cli
  require_command curl
  require_command jq

  rpc_user="joininbox"
  rpc_pass="joininbox"
  rpc_port="$((20000 + (RANDOM % 20000)))"
  p2p_port="$((40000 + (RANDOM % 20000)))"
  bitcoin_datadir="${BATS_TEST_TMPDIR}/bitcoin"
  joinmarket_cfg="${BATS_TEST_TMPDIR}/joinmarket.cfg"
  joinin_conf="${BATS_TEST_TMPDIR}/joinin.conf"

  mkdir -p "$bitcoin_datadir"

  bitcoind \
    -regtest \
    -datadir="$bitcoin_datadir" \
    -server \
    -daemonwait \
    -rpcuser="$rpc_user" \
    -rpcpassword="$rpc_pass" \
    -rpcport="$rpc_port" \
    -port="$p2p_port" \
    -fallbackfee=0.0001

  cat >"$joinmarket_cfg" <<EOF
rpc_user = $rpc_user
rpc_password = $rpc_pass
rpc_host = 127.0.0.1
rpc_port = $rpc_port
rpc_wallet_file = watch-only-descriptor-wallet
EOF
  : >"$joinin_conf"
}

teardown() {
  if [ -n "${bitcoin_datadir:-}" ] && [ -d "$bitcoin_datadir" ]; then
    bitcoin-cli \
      -regtest \
      -datadir="$bitcoin_datadir" \
      -rpcuser="$rpc_user" \
      -rpcpassword="$rpc_pass" \
      -rpcport="$rpc_port" \
      stop >/dev/null 2>&1 || true
  fi
}

load_joininbox_bitcoin_functions() {
  # shellcheck source=scripts/_functions.bitcoincore.sh
  # shellcheck disable=SC1091
  source "$root_dir/scripts/_functions.bitcoincore.sh"
  # shellcheck disable=SC2034
  JMcfgPath="$joinmarket_cfg"
  # shellcheck disable=SC2034
  joininConfPath="$joinin_conf"

  mktemp() {
    if [ "${1:-}" = "-p" ] && [ "${2:-}" = "/dev/shm/" ]; then
      command mktemp "${BATS_TEST_TMPDIR}/joininbox.XXXXXX"
    else
      command mktemp "$@"
    fi
  }
}

wallet_info() {
  bitcoin-cli \
    -regtest \
    -datadir="$bitcoin_datadir" \
    -rpcuser="$rpc_user" \
    -rpcpassword="$rpc_pass" \
    -rpcport="$rpc_port" \
    -rpcwallet=watch-only-descriptor-wallet \
    getwalletinfo
}

check_wallet_migration_with_enter() {
  printf "\n" | checkWalletMigration
}

check_rpc_wallet_with_enter() {
  printf "\n" | checkRPCwallet
}

@test "checkRPCwallet creates the configured descriptor watch-only wallet" {
  load_joininbox_bitcoin_functions

  run checkRPCwallet

  [ "$status" -eq 0 ]
  [[ "$output" == *"The wallet: watch-only-descriptor-wallet is present and loaded"* ]]

  run wallet_info
  [ "$status" -eq 0 ]
  [ "$(jq -r '.descriptors' <<<"$output")" = "true" ]
  [ "$(jq -r '.private_keys_enabled' <<<"$output")" = "false" ]
  run grep -q "walletMigrationDone" "$joinin_conf"
  [ "$status" -ne 0 ]
}

@test "customRPC uses the descriptor wallet RPC endpoint" {
  bitcoin-cli \
    -regtest \
    -datadir="$bitcoin_datadir" \
    -rpcuser="$rpc_user" \
    -rpcpassword="$rpc_pass" \
    -rpcport="$rpc_port" \
    -named createwallet \
    wallet_name=watch-only-descriptor-wallet \
    descriptors=true \
    disable_private_keys=true >/dev/null

  load_joininbox_bitcoin_functions

  run customRPC "# Wallet info" "getwalletinfo" ""

  [ "$status" -eq 0 ]
  [[ "$output" == *'"walletname": "watch-only-descriptor-wallet"'* ]]
  [[ "$output" == *'"descriptors": true'* ]]
  [[ "$output" == *'"private_keys_enabled": false'* ]]
}

@test "checkRPCwallet migrates a persisted wallet.dat configuration on Bitcoin Core v30 or later" {
  bitcoin-cli \
    -regtest \
    -datadir="$bitcoin_datadir" \
    -rpcuser="$rpc_user" \
    -rpcpassword="$rpc_pass" \
    -rpcport="$rpc_port" \
    -named createwallet \
    wallet_name=wallet.dat \
    descriptors=true \
    disable_private_keys=true >/dev/null
  sed \
    "s/^rpc_wallet_file =.*/rpc_wallet_file = wallet.dat/" \
    "$joinmarket_cfg" >"${joinmarket_cfg}.legacy"
  mv "${joinmarket_cfg}.legacy" "$joinmarket_cfg"

  load_joininbox_bitcoin_functions

  run check_rpc_wallet_with_enter

  [ "$status" -eq 0 ]
  [[ "$output" == *"Migrating the configured Bitcoin Core wallet"* ]]
  [[ "$output" == *"WALLET MIGRATION NOTICE"* ]]
  grep -q "^rpc_wallet_file = watch-only-descriptor-wallet$" "$joinmarket_cfg"
  grep -q "^walletMigrationDone=true$" "$joinin_conf"

  run wallet_info
  [ "$status" -eq 0 ]
  [ "$(jq -r '.descriptors' <<<"$output")" = "true" ]
  [ "$(jq -r '.private_keys_enabled' <<<"$output")" = "false" ]
}

@test "migrateLegacyRPCWalletConfig keeps wallet.dat on Bitcoin Core v29.2" {
  sed \
    "s/^rpc_wallet_file =.*/rpc_wallet_file = wallet.dat/" \
    "$joinmarket_cfg" >"${joinmarket_cfg}.legacy"
  mv "${joinmarket_cfg}.legacy" "$joinmarket_cfg"

  load_joininbox_bitcoin_functions
  getConnectedBitcoinCoreVersion() {
    echo 290200
  }
  getRPC >/dev/null

  run migrateLegacyRPCWalletConfig

  [ "$status" -eq 0 ]
  [[ "$output" == *"v29.x or earlier; keeping wallet.dat"* ]]
  grep -q "^rpc_wallet_file = wallet.dat$" "$joinmarket_cfg"
}

@test "checkWalletMigration shows the notice once when wallet.dat exists" {
  bitcoin-cli \
    -regtest \
    -datadir="$bitcoin_datadir" \
    -rpcuser="$rpc_user" \
    -rpcpassword="$rpc_pass" \
    -rpcport="$rpc_port" \
    -named createwallet \
    wallet_name=wallet.dat \
    descriptors=true \
    disable_private_keys=true >/dev/null

  load_joininbox_bitcoin_functions
  # shellcheck disable=SC2034
  rpc_host="127.0.0.1"
  # shellcheck disable=SC2034
  rpc_wallet="watch-only-descriptor-wallet"

  run check_wallet_migration_with_enter

  [ "$status" -eq 0 ]
  [[ "$output" == *"WALLET MIGRATION NOTICE"* ]]
  grep -q "^walletMigrationDone=true$" "$joinin_conf"

  run checkWalletMigration
  [ "$status" -eq 0 ]
  [ "$output" = "" ]
}
