#!/usr/bin/env bats

setup() {
  REPO="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
}

@test "JoinMarket source authentication precedes the fail-closed bootstrap backport" {
  run python3 - "$REPO" <<'PY'
from pathlib import Path
import sys
text = (Path(sys.argv[1]) / 'scripts/install.joinmarket.sh').read_text()
patch = text.index('patch --batch --forward --fuzz=0')
assert text.rindex('verify.git.sh', 0, patch) < patch
assert patch < text.index('"${trust_sudo[@]}" ./install.sh')
assert 'joinmarket-python-trust.patch" || exit 1' in text
PY
  [ "$status" -eq 0 ]
}

@test "system prerequisites and all installer paths preserve operator download policy" {
  run python3 - "$REPO" <<'PY'
from pathlib import Path
import sys
text = (Path(sys.argv[1]) / 'scripts/install.joinmarket.sh').read_text()
assert 'trust_env=("${!PIP_@}" REQUESTS_CA_BUNDLE CURL_CA_BUNDLE SSL_CERT_FILE SSL_CERT_DIR)' in text
assert '--preserve-env=' in text
assert 'python3 "${trust_scripts}/joinmarket-python-trust.py" prerequisites || exit 1' in text
assert text.count('"${trust_sudo[@]}" ./install.sh') == 2
PY
  [ "$status" -eq 0 ]
}

@test "successful updates and already-installed returns check pip and application trust" {
  run python3 - "$REPO" <<'PY'
from pathlib import Path
import sys
text = (Path(sys.argv[1]) / 'scripts/install.joinmarket.sh').read_text()
assert text.count('joinmarket-python-trust.py" app || exit 1') == 2
assert text.index('./jmvenv/bin/python') < text.index('echo "# installed JoinMarket')
PY
  [ "$status" -eq 0 ]
}

@test "archived installer backport handles fresh reused and non-venv pip failures" {
  run python3 - "$REPO" <<'PY'
from pathlib import Path
import sys
text = (Path(sys.argv[1]) / 'scripts/joinmarket-python-trust.patch').read_text()
assert 'install-python-trust.py" bootstrap' in text
assert '+        return "$?"' in text
assert '+    return "$setup_status"' in text
assert '+        upgrade_setuptools || return 1' in text
assert 'install-python-trust.py" upgrade-app || return 1' in text
assert "pip install --upgrade 'certifi" not in text
PY
  [ "$status" -eq 0 ]
}
