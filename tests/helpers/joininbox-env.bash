# Shared environment for the joininbox bats tests.
# Prepares a minimal /home/joinmarket so the real scripts can be sourced and
# executed: the scripts hardcode /home/joinmarket paths and source
# _functions.sh + the joinin.conf config at load time.
#
# On CI runners sudo is passwordless. Locally the suite can be run inside a
# user namespace with a bind-mounted /home/joinmarket (see tests/README.md).

JM_HOME="/home/joinmarket"
TEST_WALLET="$JM_HOME/.joinmarket/wallets/validator-test.jmdat"
REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"

joininbox_setup_file() {
  if [ ! -d "$JM_HOME" ]; then
    sudo mkdir -p "$JM_HOME"
    sudo touch "$JM_HOME/.bats-created"
  fi
  sudo cp "$REPO_ROOT/scripts/_functions.sh" "$JM_HOME/"
  sudo cp "$REPO_ROOT/scripts/_functions.menu.sh" "$JM_HOME/"
  sudo cp "$REPO_ROOT/scripts/_functions.bitcoincore.sh" "$JM_HOME/"
  sudo mkdir -p "$JM_HOME/.joinmarket/wallets"
  printf 'RPCoverTor=off\nrunBehindTor=off\n' | sudo tee "$JM_HOME/joinin.conf" >/dev/null
  sudo touch "$TEST_WALLET"
}

joininbox_teardown_file() {
  if [ -f "$JM_HOME/.bats-created" ]; then
    # the directory was created by the test suite - remove it whole
    sudo rm -rf "$JM_HOME"
  else
    # pre-existing directory - only remove what the suite added
    sudo rm -f "$JM_HOME/_functions.sh" "$JM_HOME/_functions.menu.sh" \
      "$JM_HOME/_functions.bitcoincore.sh" "$JM_HOME/joinin.conf" "$TEST_WALLET"
    sudo rm -rf "$JM_HOME/.joinmarket"
  fi
}
