#!/usr/bin/env python3
"""Real pip, local HTTPS, and installer-function regression tests (Python 3.10+).

Run: python tests/bootstrap_regression.py PUBLIC_JM_V0_9_12_CHECKOUT EMPTY_SCRATCH
Wheels are fetched from PyPI and checked against its published SHA-256.
No system trust files are changed. Test keys are generated only in SCRATCH.
"""

import functools
import hashlib
import http.server
import json
import os
from pathlib import Path
import shutil
import ssl
import subprocess
import sys
import threading
import urllib.request

from python_trust_source import public_installer

REPO = Path(__file__).resolve().parents[1]
ORIGINAL = public_installer(sys.argv[1])
WORK = Path(sys.argv[2]).resolve()
if WORK.exists() and any(WORK.iterdir()):
    raise ValueError("scratch directory must be empty")
WORK.mkdir(parents=True, exist_ok=True)
WHEELS = WORK / "wheels"
WHEELS.mkdir()
HELPER = REPO / "scripts/joinmarket-python-trust.py"
RESULTS = []


def run(args, env=None, ok=True):
    result = subprocess.run([str(a) for a in args], env=env, text=True,
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    if (result.returncode == 0) != ok:
        raise AssertionError(str(args) + "\n" + result.stdout)
    return result.stdout


def record(name):
    RESULTS.append(name)
    print("PASS " + name, flush=True)


for package, version in (("pip", "23.3.2"), ("pip", "25.0.1"), ("pip", "26.0.1"),
                         ("pip", "26.2.1"), ("pip", "26.2.2"),
                         ("certifi", "2025.8.3"), ("certifi", "2026.10.19"), ("setuptools", "80.9.0")):
    with urllib.request.urlopen("https://pypi.org/pypi/%s/%s/json" % (package, version)) as response:
        metadata = json.load(response)
    wheel = next(f for f in metadata["urls"] if f["filename"].endswith(".whl"))
    dest = WHEELS / wheel["filename"]
    if not dest.exists():
        urllib.request.urlretrieve(wheel["url"], dest)
    assert hashlib.sha256(dest.read_bytes()).hexdigest() == wheel["digests"]["sha256"]
    (WORK / (package + "-" + version + ".json")).write_text(json.dumps(wheel, indent=2))
record("PyPI wheel hashes verified")

for name in ("server", "other"):
    key, cert = WORK / (name + ".key"), WORK / (name + ".pem")
    config = WORK / (name + ".cnf")
    config.write_text("[req]\ndistinguished_name=dn\nx509_extensions=ext\nprompt=no\n"
                      "[dn]\nCN=" + name + " test CA\n[ext]\nbasicConstraints=critical,CA:TRUE\n"
                      "keyUsage=critical,keyCertSign,cRLSign\nsubjectKeyIdentifier=hash\n")
    run(["openssl", "req", "-x509", "-newkey", "rsa:2048", "-nodes", "-days", "2",
         "-keyout", key, "-out", cert, "-config", config])


class QuietHandler(http.server.SimpleHTTPRequestHandler):
    def log_message(self, format, *args):
        pass


server = http.server.ThreadingHTTPServer(("127.0.0.1", 0),
    functools.partial(QuietHandler, directory=str(WHEELS)))
context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
leaf_config = WORK / "leaf.cnf"
leaf_config.write_text("basicConstraints=critical,CA:FALSE\nkeyUsage=critical,digitalSignature,keyEncipherment\n"
                       "extendedKeyUsage=serverAuth\nsubjectAltName=IP:127.0.0.1,DNS:localhost\n"
                       "authorityKeyIdentifier=keyid,issuer\nsubjectKeyIdentifier=hash\n")
run(["openssl", "req", "-new", "-newkey", "rsa:2048", "-nodes", "-subj", "/CN=localhost",
     "-keyout", WORK / "leaf.key", "-out", WORK / "leaf.csr"])
run(["openssl", "x509", "-req", "-in", WORK / "leaf.csr", "-CA", WORK / "server.pem",
     "-CAkey", WORK / "server.key", "-CAcreateserial", "-days", "2", "-extfile", leaf_config,
     "-out", WORK / "leaf.pem"])
context.load_cert_chain(str(WORK / "leaf.pem"), str(WORK / "leaf.key"))
server.socket = context.wrap_socket(server.socket, server_side=True)
thread = threading.Thread(target=server.serve_forever, daemon=True)
thread.start()
URL = "https://127.0.0.1:%d" % server.server_port
BASE = {k: v for k, v in os.environ.items()
        if not k.startswith("PIP_") and k not in
        ("REQUESTS_CA_BUNDLE", "CURL_CA_BUNDLE", "SSL_CERT_FILE", "SSL_CERT_DIR", "PYTHONPATH")}
(WORK / "empty-ca-dir").mkdir(exist_ok=True)
BASE.update(PIP_CONFIG_FILE=os.devnull, PIP_NO_INDEX="1", PIP_FIND_LINKS=URL,
            PIP_DISABLE_PIP_VERSION_CHECK="1", PIP_RETRIES="0", PIP_TIMEOUT="3",
            SSL_CERT_FILE=str(WORK / "server.pem"), SSL_CERT_DIR=str(WORK / "empty-ca-dir"),
            PIP_CERT=str(WORK / "server.pem"))


def venv(name, version):
    path = WORK / name
    run([sys.executable, "-m", "venv", path])
    python = path / "bin/python"
    env = dict(BASE, PIP_FIND_LINKS=WHEELS.as_uri())
    run([python, "-m", "pip", "install", "--no-deps", "pip==" + version], env)
    return python


try:
    for version in ("23.3.2", "26.2.1"):
        python = venv("positive-" + version, version)
        run([python, HELPER, "bootstrap"], BASE)
        assert run([python, "-c", "import pip;print(pip.__version__)"], BASE).strip() == "26.2.2"
        run([python, HELPER, "app"], BASE)
        run([python, HELPER, "upgrade-app"], BASE)
        assert run([python, "-c", "import importlib.util;print(importlib.util.find_spec('certifi'))"], BASE).strip() == "None"
        record("pip " + version + " absent application certifi accepted without installation")
        run([python, "-m", "pip", "install", "certifi>=2026.10.19"], BASE)
        run([python, HELPER, "app"], BASE)
        snapshot = "import certifi,pathlib,hashlib;p=pathlib.Path(certifi.where());print(hashlib.sha256(p.read_bytes()).hexdigest(),p.stat().st_mtime_ns)"
        before = run([python, "-c", snapshot], BASE)
        run([python, HELPER, "upgrade-app"], BASE)
        assert run([python, "-c", snapshot], BASE) == before
        record("pip " + version + " actual HTTPS bootstrap and application roots")

        python = venv("negative-" + version, version)
        # Simulate the pre-existing public-root path without possessing any
        # affected private key: pip's vendor store trusts the local server.
        bundle = Path(run([python, "-c", "from pip._vendor import certifi;print(certifi.where())"]).strip())
        with bundle.open("a") as stream:
            stream.write((WORK / "server.pem").read_text())
        rejected_env = dict(BASE, PIP_CERT=str(WORK / "other.pem"),
                            SSL_CERT_FILE=str(WORK / "other.pem"))
        # Real CLI baseline exercises modern pip's additive truststore as well
        # as old pip's certifi-only defaults. Both accept the injected root.
        baseline_env = dict(rejected_env)
        if version == "23.3.2":
            baseline_env.pop("PIP_CERT")  # old pip defaults to certifi alone
        run([python, "-m", "pip", "download", "--no-deps", "--dest",
             WORK / ("baseline-download-" + version), "pip==26.2.2"], baseline_env)
        output = run([python, HELPER, "bootstrap"], rejected_env, ok=False)
        assert "CERTIFICATE_VERIFY_FAILED" in output, output
        record("pip " + version + " rejects wrong CA despite additive vendor trust")

        constraint = WORK / ("constraint-" + version + ".txt")
        constraint.write_text("pip==" + version + "\n")
        output = run([python, HELPER, "bootstrap"], dict(BASE, PIP_CONSTRAINT=constraint.as_uri()), ok=False)
        assert "ResolutionImpossible" in output or "conflicting dependencies" in output, output
        record("pip " + version + " preserves conflicting operator constraint")

    python = WORK / "positive-26.2.1/bin/python"
    for key, value, message in (("PIP_TRUSTED_HOST", "127.0.0.1", "trusted-host"),
                                ("PIP_FIND_LINKS", "http://127.0.0.1", "requires HTTPS")):
        output = run([python, HELPER, "bootstrap"], dict(BASE, **{key: value}), ok=False)
        assert message in output, output
        record("rejects " + key)
    # Explicit Requests CA must not be silently overwritten by a safe PIP_CERT.
    output = run([WORK / "negative-26.2.1/bin/python", HELPER, "bootstrap"],
                 dict(BASE, REQUESTS_CA_BUNDLE=str(WORK / "other.pem")), ok=False)
    assert "CERTIFICATE_VERIFY_FAILED" in output, output
    record("preserves Requests CA precedence")
    output = run([WORK / "negative-23.3.2/bin/python", HELPER, "bootstrap"],
                 dict(BASE, PIP_USE_FEATURE="truststore"), ok=False)
    assert "Disable opt-in truststore" in output, output
    record("old pip opt-in additive truststore rejected")

    run([python, "-m", "pip", "install", "certifi==2025.8.3"], BASE)
    output = run([python, HELPER, "app"], BASE, ok=False)
    assert "Affected eMudhra SSL root" in output, output
    app_constraint = WORK / "app-constraint.txt"
    app_constraint.write_text("certifi==2025.8.3\n")
    output = run([python, HELPER, "upgrade-app"],
                 dict(BASE, PIP_CONSTRAINT=app_constraint.as_uri()), ok=False)
    assert "ResolutionImpossible" in output or "conflicting dependencies" in output, output
    run([python, HELPER, "app"], BASE, ok=False)
    record("stale application certifi and its resolver constraint fail closed")
    app_constraint.write_text("certifi==2026.10.19\n")
    run([python, HELPER, "upgrade-app"], dict(BASE, PIP_CONSTRAINT=app_constraint.as_uri()))
    run([python, HELPER, "app"], BASE)
    assert run([python, "-c", "import certifi;print(certifi.__version__)"], BASE).strip() == "2026.10.19"
    record("present affected application certifi repaired and rechecked in new interpreter")

    for statement, message in (("import missing_certifi_dependency", "missing_certifi_dependency"),
                               ("raise ImportError('broken certifi import')", "broken certifi import")):
        shadow = WORK / message.replace(" ", "-")
        shadow.mkdir()
        (shadow / "certifi.py").write_text(statement + "\n")
        for mode in ("app", "upgrade-app"):
            output = run([python, HELPER, mode], dict(BASE, PYTHONPATH=str(shadow)), ok=False)
            assert message in output, output
        record("unexpected application import error fails closed: " + message)

    # Verify the last Python 3.8/3.9 pip releases really have affected roots.
    import zipfile
    for version in ("25.0.1", "26.0.1"):
        with zipfile.ZipFile(WHEELS / ("pip-" + version + "-py3-none-any.whl")) as wheel:
            old_bundle = WORK / ("pip-" + version + ".pem")
            old_bundle.write_bytes(wheel.read("pip/_vendor/certifi/cacert.pem"))
        output = run([python, "-c", "import runpy; m=runpy.run_path(%r);m['check_bundle'](%r)" %
                      (str(HELPER), str(old_bundle))], BASE, ok=False)
        assert "Affected eMudhra SSL root" in output, output
        record("last old-Python pip " + version + " still contains affected roots")

    # Synthetic future capability, not a substitute for the real pip TLS tests.
    capability = ("import runpy,pip; from pip._internal.commands import create_command; "
                  "m=runpy.run_path(%r); c=create_command('install'); "
                  "c.parser.remove_option('--use-deprecated'); pip.__version__='99.0'; "
                  "import pip._internal.commands; pip._internal.commands.create_command=lambda _: c; "
                  "m['bootstrap']()") % str(HELPER)
    output = run([python, "-c", capability], BASE, ok=False)
    assert "Unknown pip truststore capability" in output, output
    record("unknown modern pip capability rejected before network (mocked capability)")

    # Exercise the real venv_setup shell function, without native dependency builds.
    # Only these installer-function cases use a scratch-patched public source.
    installer = WORK / "public-installer"
    installer.mkdir()
    (installer / "install.sh").write_text(ORIGINAL)
    patch = subprocess.run(["patch", "--batch", "--forward", "--fuzz=0", "-p1"],
                           cwd=installer,
                           input=(REPO / "scripts/joinmarket-python-trust.patch").read_text(),
                           text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    assert patch.returncode == 0, patch.stdout
    source = (installer / "install.sh").read_text().rsplit('main "${@}"', 1)[0]
    functions = WORK / "installer-functions.sh"
    functions.write_text(source)
    for reuse in (False, True):
        fixture = WORK / ("installer-reuse" if reuse else "installer-fresh")
        fixture.mkdir(exist_ok=True)
        shutil.copy(HELPER, fixture / "install-python-trust.py")
        if reuse:
            run([sys.executable, "-m", "venv", fixture / "jmvenv"])
        shell = ('source "$1"; jm_source="$2"; python="$3"; '
                 'check_skip_build() { ' + ('return 0' if reuse else 'return 1') + '; }; venv_setup')
        run(["bash", "-c", shell, "test", functions, fixture, sys.executable], BASE)
        app_python = fixture / "jmvenv/bin/python"
        run([app_python, HELPER, "app"], BASE)
        # Execute the actual post-install repair line, not a duplicate command.
        repair = next(line for line in source.splitlines() if 'install-python-trust.py" upgrade-app' in line)
        run(["bash", "-c", 'jm_source="$1"; trust_python="$2"; ' + repair,
             "test", fixture, app_python], BASE)
        assert run([app_python, "-c", "import importlib.util;print(importlib.util.find_spec('certifi'))"], BASE).strip() == "None"
        record("executed installer venv_setup and absent-certifi postcondition " + ("reuse" if reuse else "fresh"))

    # Execute the actual owner's installed early-return block with real Python;
    # only the home path and sudo boundary are replaced with scratch-local ones.
    owner = (REPO / "scripts/install.joinmarket.sh").read_text()
    early = owner[owner.index('if [ "$install" = "install" ]; then\n  # install joinmarket'):
                  owner.index('if [ "$install" = "update" ]; then\n  stopYG')]
    early = early.replace("/home/", str(WORK / "early-home") + "/")
    home = WORK / "early-home/test/joinmarket-clientserver"
    home.mkdir(parents=True)
    (home / "jmvenv").symlink_to(WORK / "installer-fresh/jmvenv", target_is_directory=True)
    early_python = home / "jmvenv/bin/python"
    shell = 'install=install; user=test; currentJMversion=v0.9.12; trust_sudo=(); trust_scripts="$1"; ' + early
    run(["bash", "-c", shell, "test", HELPER.parent], BASE)
    assert run([early_python, "-c", "import importlib.util;print(importlib.util.find_spec('certifi'))"], BASE).strip() == "None"
    record("actual owner early-return accepts absent certifi without installing it")
    run([early_python, "-m", "pip", "install", "certifi==2025.8.3"], BASE)
    output = run(["bash", "-c", shell, "test", HELPER.parent], BASE, ok=False)
    assert "Affected eMudhra SSL root" in output and "is installed" not in output, output
    record("actual owner early-return rejects present affected certifi")
    run([early_python, HELPER, "upgrade-app"], BASE)
    run(["bash", "-c", shell, "test", HELPER.parent], BASE)
    record("actual owner early-return accepts present fixed certifi")

    for version in ((3, 8), (3, 9)):
        output = run([python, "-c", "import runpy,sys; m=runpy.run_path(%r);sys.version_info=%r;m['bootstrap']()" %
                      (str(HELPER), version)], BASE, ok=False)
        assert "requires Python >=3.10" in output, output
        record("explicit Python %d.%d bootstrap policy gate preserved" % version)

    for reuse in (False, True):
        fixture = WORK / ("installer-reuse-failure" if reuse else "installer-fresh-failure")
        fixture.mkdir(exist_ok=True)
        shutil.copy(HELPER, fixture / "install-python-trust.py")
        if reuse:
            run([sys.executable, "-m", "venv", fixture / "jmvenv"])
        shell = ('source "$1"; jm_source="$2"; python="$3"; '
                 'check_skip_build() { ' + ('return 0' if reuse else 'return 1') + '; }; venv_setup')
        output = run(["bash", "-c", shell, "test", functions, fixture, sys.executable],
                     dict(BASE, PIP_CONSTRAINT=constraint.as_uri()), ok=False)
        assert "ResolutionImpossible" in output or "conflicting dependencies" in output, output
        record("installer propagates bootstrap constraint failure " + ("reuse" if reuse else "fresh"))

    # Known affected roots are rejected before network access and after updates.
    old = WORK / "negative-26.2.1/bin/python"
    bundle = run([old, "-c", "from pip._vendor import certifi;print(certifi.where())"]).strip()
    output = run([python, "-c", "import runpy; m=runpy.run_path(%r);m['check_bundle'](%r)" % (str(HELPER), bundle)], BASE, ok=False)
    assert "Affected eMudhra SSL root" in output, output
    output = run([python, HELPER, "bootstrap"], dict(BASE, PIP_CERT=bundle), ok=False)
    assert "Affected eMudhra SSL root" in output, output
    record("actual affected vendor roots rejected as bootstrap CA")
    output = run([old, HELPER, "app"], BASE, ok=False)
    assert "Affected eMudhra SSL root" in output, output
    absent_python = WORK / "installer-reuse/jmvenv/bin/python"
    output = run([absent_python, HELPER, "app"], dict(BASE, PIP_CERT=bundle), ok=False)
    assert "Affected eMudhra SSL root" in output, output
    record("absent certifi does not bypass pip or explicit CA checks")
finally:
    server.shutdown()
    (WORK / "results.json").write_text(json.dumps(RESULTS, indent=2))
print("%d regression checks passed (one mocked capability check)" % len(RESULTS))
