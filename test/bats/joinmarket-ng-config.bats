#!/usr/bin/env bats

root_dir="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
writer="$root_dir/scripts/set.joinmarket-ng-config.py"

setup() {
  template="$BATS_TEST_TMPDIR/config.toml.template"
  config="$BATS_TEST_TMPDIR/config.toml"

  cat >"$template" <<'EOF'
# JoinMarket NG upstream-like configuration
[tor]
# socks_host = "localhost"
# control_enabled = false
# control_host = "localhost"
# cookie_path = ""
tor_unrelated = "keep"

[bitcoin]
backend_type = "legacy_wallet"
#   rpc_url = "http://localhost:8332"
#  rpc_user = ""
bitcoin_unrelated = "keep"

[network_config]
#   network = "mainnet"
network_unrelated = "keep"

[other]
rpc_user = "must-not-change"
network = "also-untouched"
other_value = "keep"
EOF

  cp "$template" "$config"
}

run_explicit() {
  run python3 "$writer" \
    --config "$config" \
    --network regtest \
    --rpc-user joininbox \
    --rpc-password password \
    --rpc-host 127.0.0.1 \
    --rpc-port 18443
}

assert_toml_values() {
  local expected_network="$1"
  local expected_user="$2"
  local expected_password="$3"
  local expected_host="$4"
  local expected_port="$5"

  run python3 -c '
import sys
import tomllib

with open(sys.argv[1], "rb") as source:
    config = tomllib.load(source)

network, user, password, host, port = sys.argv[2:]
assert config["network_config"]["network"] == network
assert config["bitcoin"]["backend_type"] == "descriptor_wallet"
assert config["bitcoin"]["rpc_url"] == f"http://{host}:{port}"
assert config["bitcoin"]["rpc_user"] == user
assert config["bitcoin"]["rpc_password"] == password
assert config["tor"] == {
    "socks_host": "127.0.0.1",
    "socks_port": 9050,
    "control_enabled": True,
    "control_host": "127.0.0.1",
    "control_port": 9051,
    "cookie_path": "/run/tor/control.authcookie",
    "tor_unrelated": "keep",
}
' "$config" "$expected_network" "$expected_user" "$expected_password" "$expected_host" "$expected_port"
  [ "$status" -eq 0 ]
}

@test "writes explicit JoinMarket NG settings and preserves the destination mode" {
  chmod 640 "$config"

  run_explicit

  [ "$status" -eq 0 ]
  [ "$output" = "Updated $config for regtest (rpc_over_tor=off)" ]
  [ "$(stat -c '%a' "$config")" = "640" ]
  assert_toml_values regtest joininbox password 127.0.0.1 18443
}

@test "reads the RPC password from a protected file" {
  password_file="$BATS_TEST_TMPDIR/rpc-password"
  printf '%s' 'file password = $&\' > "$password_file"
  chmod 600 "$password_file"

  run python3 "$writer" \
    --config "$config" \
    --network mainnet \
    --rpc-user file-user \
    --rpc-password-file "$password_file" \
    --rpc-host 127.0.0.1 \
    --rpc-port 8332

  [ "$status" -eq 0 ]
  assert_toml_values mainnet file-user 'file password = $&\' 127.0.0.1 8332
}

@test "migrates BLOCKCHAIN values from a legacy configuration" {
  legacy_config="$BATS_TEST_TMPDIR/joinmarket.cfg"
  cat >"$legacy_config" <<'EOF'
[BLOCKCHAIN]
network = signet
rpc_user = legacy-user
rpc_password = legacy-password
rpc_host = legacy-rpc
rpc_port = 38332
EOF

  run python3 "$writer" --config "$config" --legacy-config "$legacy_config"

  [ "$status" -eq 0 ]
  [ "$output" = "Updated $config for signet (rpc_over_tor=off)" ]
  assert_toml_values signet legacy-user legacy-password legacy-rpc 38332
}

@test "round trips special characters through TOML strings" {
  rpc_host=$'RPC"\\$&/|\001\u2603.onion'
  rpc_user=$'user"\\$&/|\002\u2603'
  rpc_password=$'pass"\\$&/|\003\u2603'

  run python3 "$writer" \
    --config "$config" \
    --network testnet \
    --rpc-user "$rpc_user" \
    --rpc-password "$rpc_password" \
    --rpc-host "$rpc_host" \
    --rpc-port 18332 \
    --tor-cookie-path $'cookie"\\$&/|\004\u2603'

  [ "$status" -eq 0 ]
  [ "$output" = "Updated $config for testnet (rpc_over_tor=on)" ]
  run python3 -c '
import sys
import tomllib

with open(sys.argv[1], "rb") as source:
    config = tomllib.load(source)

assert config["bitcoin"]["rpc_url"] == f"http://{sys.argv[2]}:18332"
assert config["bitcoin"]["rpc_user"] == sys.argv[3]
assert config["bitcoin"]["rpc_password"] == sys.argv[4]
assert config["tor"]["cookie_path"] == sys.argv[5]
' "$config" "$rpc_host" "$rpc_user" "$rpc_password" $'cookie"\\$&/|\004\u2603'
  [ "$status" -eq 0 ]
}

@test "updates only target sections and inserts missing settings" {
  run_explicit

  [ "$status" -eq 0 ]
  grep -Fqx 'rpc_user = "must-not-change"' "$config"
  grep -Fqx 'network = "also-untouched"' "$config"
  grep -Fqx 'other_value = "keep"' "$config"
  grep -Fqx 'tor_unrelated = "keep"' "$config"
  grep -Fqx 'bitcoin_unrelated = "keep"' "$config"
  grep -Fqx 'network_unrelated = "keep"' "$config"
  grep -Fqx 'socks_port = 9050' "$config"
  grep -Fqx 'control_port = 9051' "$config"
  grep -Fqx 'rpc_password = "password"' "$config"
}

@test "reports onion RPC status case-insensitively" {
  run python3 "$writer" \
    --config "$config" \
    --network mainnet \
    --rpc-user joininbox \
    --rpc-password password \
    --rpc-host NODE.ONION \
    --rpc-port 8332

  [ "$status" -eq 0 ]
  [ "$output" = "Updated $config for mainnet (rpc_over_tor=on)" ]
}

@test "rejects an invalid network without modifying the destination" {
  before=$(<"$config")

  run python3 "$writer" \
    --config "$config" \
    --network invalid \
    --rpc-user joininbox \
    --rpc-password password \
    --rpc-host 127.0.0.1 \
    --rpc-port 8332

  [ "$status" -ne 0 ]
  [[ "$output" == *"network must be"* ]]
  [ "$(<"$config")" = "$before" ]
}

@test "rejects an invalid port without modifying the destination" {
  before=$(<"$config")

  run python3 "$writer" \
    --config "$config" \
    --network mainnet \
    --rpc-user joininbox \
    --rpc-password password \
    --rpc-host 127.0.0.1 \
    --rpc-port 65536

  [ "$status" -ne 0 ]
  [[ "$output" == *"rpc_port must be"* ]]
  [ "$(<"$config")" = "$before" ]
}

@test "rejects malformed TOML atomically" {
  printf '[tor]\nbroken = [\n' >"$config"
  before=$(<"$config")

  run_explicit

  [ "$status" -ne 0 ]
  [[ "$output" == *"not valid TOML"* ]]
  [ "$(<"$config")" = "$before" ]
}

@test "rejects a template missing a required section without modifying it" {
  printf '[tor]\n[bitcoin]\n' >"$config"
  before=$(<"$config")

  run_explicit

  [ "$status" -ne 0 ]
  [[ "$output" == *"missing required section"* ]]
  [ "$(<"$config")" = "$before" ]
}

@test "requires exactly one complete input mode" {
  run python3 "$writer" --config "$config"

  [ "$status" -ne 0 ]
  [[ "$output" == *"explicit mode requires"* ]]

  legacy_config="$BATS_TEST_TMPDIR/joinmarket.cfg"
  printf '[BLOCKCHAIN]\nnetwork = mainnet\nrpc_user = user\nrpc_password = pass\nrpc_host = host\nrpc_port = 8332\n' >"$legacy_config"
  run python3 "$writer" \
    --config "$config" \
    --legacy-config "$legacy_config" \
    --network mainnet

  [ "$status" -ne 0 ]
  [[ "$output" == *"cannot be combined"* ]]
}
