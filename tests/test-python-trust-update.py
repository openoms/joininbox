#!/usr/bin/env python3
"""Execute the owner updater with mocked OS/build steps and the real backport.

Usage: python tests/test-python-trust-update.py JOINMARKET_CHECKOUT SCRATCH
No /home writes, sudo, device access, or package installation is performed.
"""
import json
import os
from pathlib import Path
import re
import subprocess
import sys

from python_trust_source import public_installer

repo = Path(__file__).resolve().parents[1]
jm = Path(sys.argv[1])
work = Path(sys.argv[2]).absolute()
work.mkdir(parents=True, exist_ok=True)
original = public_installer(jm)
fixture = work / "original-install.sh"
fixture.write_text(original)
text = (repo / "scripts/install.joinmarket.sh").read_text()
match = re.search(r"function installJoinMarket\(\) \{.*?\n\}", text, re.S)
assert match
function = match.group()
function = function.replace("/home/", str(work / "home") + "/")
policy = text[text.index("trust_env=("):text.index("\ntrust_scripts=")]
script = work / "harness.sh"
script.write_text('''#!/bin/bash
set -e
user=test
''' + policy + '''
trust_scripts="$REPO/scripts"
qtgui=false
JM_PYTHON=""
testedJMversion=v0.9.12
PGPsigner=test
PGPpkeys=test
PGPcheck=test
sudo() {
  if [[ "$1" == --preserve-env=* ]]; then
    [[ "$1" == *PIP_CONSTRAINT* && "$1" == *PIP_REQUIRE_HASHES* && "$1" == *REQUESTS_CA_BUNDLE* ]] || return 90
    shift
  fi
  if [ "$1" = -u ]; then shift 2; fi
  case "$1" in
    apt-get|pip) return 0 ;;
    python3) echo prerequisites >> "$LOG"; return 0 ;;
    git)
      case "$2" in
        clone) mkdir -p joinmarket-clientserver; cp "$FIXTURE" joinmarket-clientserver/install.sh ;;
        reset|fetch|checkout) return 0 ;;
      esac
      ;;
    bash) echo verify >> "$LOG"; return "${FAIL_VERIFY:-0}" ;;
    patch) echo patch >> "$LOG"; command "$@" ;;
    sed) return 0 ;;
    ./install.sh)
      grep -q 'install-python-trust.py.*bootstrap' install.sh || return 91
      [ -f install-python-trust.py ] || return 92
      echo installer >> "$LOG"
      return "${FAIL_INSTALL:-0}"
      ;;
    ./jmvenv/bin/python) echo postcondition >> "$LOG"; return "${FAIL_POST:-0}" ;;
    *) command "$@" ;;
  esac
}
git() { echo v0.9.12; }
''' + function + '''
installJoinMarket "$install" v0.9.12
''')
results = []
for mode in ("install", "update", "testPR", "commit"):
    for failure in (None, "FAIL_INSTALL", "FAIL_POST"):
        home = work / "home/test"
        home.mkdir(parents=True, exist_ok=True)
        # Each test starts from a pristine source copy, like the actual updater.
        import shutil
        shutil.rmtree(home / "joinmarket-clientserver", ignore_errors=True)
        log = work / (mode + "-" + str(failure) + ".log")
        log.write_text("")
        env = dict(os.environ, REPO=str(repo), FIXTURE=str(fixture), LOG=str(log), install=mode,
                   PIP_CONSTRAINT="operator-constraint", PIP_REQUIRE_HASHES="1")
        if failure:
            env[failure] = "1"
        p = subprocess.run(["bash", str(script)], env=env, text=True, stdout=subprocess.PIPE,
                           stderr=subprocess.STDOUT)
        assert (p.returncode != 0) == bool(failure), p.stdout
        events = log.read_text().splitlines()
        assert events[0] == "prerequisites", events
        assert events.index("patch") < events.index("installer"), events
        if mode in ("install", "update"):
            assert events.index("verify") < events.index("patch"), events
        if failure == "FAIL_INSTALL":
            assert "postcondition" not in events, events
        else:
            assert events[-1] == "postcondition", events
        if failure:
            assert "# installed JoinMarket" not in p.stdout, p.stdout
        patched = (home / "joinmarket-clientserver/install.sh").read_text()
        assert 'install-python-trust.py" upgrade-app || return 1' in patched
        assert "pip install --upgrade 'certifi" not in patched
        results.append(mode + ":" + str(failure))
        print("PASS " + results[-1])

# Unknown source variants must not fall through to the old installer.
changed = work / "changed"
changed.mkdir(exist_ok=True)
(changed / "install.sh").write_text(original.replace("    pip install --upgrade pip", "    echo changed-bootstrap"))
p = subprocess.run(["patch", "--batch", "--forward", "--fuzz=0", "-p1"], cwd=changed,
                   input=(repo / "scripts/joinmarket-python-trust.patch").read_text(),
                   text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
assert p.returncode != 0, p.stdout
results.append("unknown installer variant rejects backport")
print("PASS " + results[-1])
(work / "results.json").write_text(json.dumps(results, indent=2))
print("%d owner-path harness checks passed (OS, package, and native build steps mocked)" % len(results))
