#!/usr/bin/env python3
"""Bootstrap pip without reintroducing the affected eMudhra SSL roots."""
import hashlib
import os
from pathlib import Path
import re
import ssl
import subprocess
import sys
from urllib.parse import urlsplit

BLOCKED = {
    "86a1ecba089c4a8d3bbe2734c612ba341d813e043cf9e8a862cd5c57a36bbe6b",
    "d7a7a0fb5d7e2731d771e9484ebcdef71d5f0c3e0a2948782bc83ee0ea699ef4",
}


def check_bundle(bundle):
    pem = Path(bundle).read_text(encoding="ascii")
    certs = re.findall(r"-----BEGIN CERTIFICATE-----.*?-----END CERTIFICATE-----", pem, re.S)
    if not certs:
        raise RuntimeError("No CA roots in " + str(bundle))
    roots = {hashlib.sha256(ssl.PEM_cert_to_DER_cert(c)).hexdigest() for c in certs}
    if roots & BLOCKED:
        raise RuntimeError("Affected eMudhra SSL root in " + str(bundle) + "; update its owner package")
    ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT).load_verify_locations(str(bundle))


def application_certifi():
    try:
        import certifi
    except ModuleNotFoundError as error:
        if error.name != "certifi":
            raise
        return None
    return certifi


def check(app=False):
    from pip._vendor import certifi
    check_bundle(certifi.where())
    from pip._internal.commands import create_command
    options, _ = create_command("install").parse_args([])
    for bundle in (options.cert, os.environ.get("REQUESTS_CA_BUNDLE"),
                   os.environ.get("CURL_CA_BUNDLE"), os.environ.get("SSL_CERT_FILE")):
        if bundle:
            check_bundle(bundle)
    # Modern pip adds system trust to its vendored certifi bundle.
    roots = ssl.create_default_context().get_ca_certs(binary_form=True)
    if {hashlib.sha256(c).hexdigest() for c in roots} & BLOCKED:
        raise RuntimeError("Affected eMudhra SSL root in system trust; update ca-certificates")
    if app:
        certifi = application_certifi()
        if certifi is not None:
            check_bundle(certifi.where())


def safe_pip(arguments):
    import pip
    from pip._internal.commands import create_command
    from pip._vendor.packaging.version import Version
    command = create_command("install")
    options, _ = command.parse_args([])
    if options.trusted_hosts:
        raise RuntimeError("Refusing trusted-host TLS bypass during certificate bootstrap")
    sources = list(options.find_links)
    if not options.no_index:
        sources += [options.index_url] + list(options.extra_index_urls)
    if any(urlsplit(s).scheme not in ("", "file", "https") for s in sources):
        raise RuntimeError("Certificate bootstrap requires HTTPS sources or local wheels")
    deprecated = command.parser.get_option("--use-deprecated")
    legacy = []
    if deprecated and "legacy-certs" in (deprecated.choices or ()):
        legacy = ["--use-deprecated=legacy-certs"]
    elif Version(pip.__version__) >= Version("24.2"):
        raise RuntimeError("Unknown pip truststore capability; refusing additive bootstrap trust")
    elif "truststore" in options.features_enabled:
        raise RuntimeError("Disable opt-in truststore for this old pip before bootstrapping")
    # requests overrides pip's --cert. Preserve the operator's effective CA,
    # including pip configuration files, rather than silently replacing it.
    ca = (os.environ.get("REQUESTS_CA_BUNDLE") or os.environ.get("CURL_CA_BUNDLE")
          or options.cert or os.environ.get("SSL_CERT_FILE")
          or ssl.get_default_verify_paths().cafile)
    if not ca:
        raise RuntimeError("No file-based bootstrap CA roots; configure PIP_CERT explicitly")
    check_bundle(ca)
    env = dict(os.environ, REQUESTS_CA_BUNDLE=ca, CURL_CA_BUNDLE=ca, SSL_CERT_FILE=ca)
    # All operator index, constraint, and build-constraint settings survive.
    subprocess.run([sys.executable, "-m", "pip"] + legacy + ["--cert", ca] + arguments,
                   env=env, check=True)


def bootstrap():
    # Last pip for 3.8 is 25.0.1, and for 3.9 is 26.0.1. Neither has fixed
    # vendored certifi. Do not silently resolve to one of these old versions.
    if sys.version_info < (3, 10):
        raise RuntimeError("Certificate bootstrap requires Python >=3.10 for pip>=26.2.2; "
                           "Python 3.8/3.9 need a maintained pip backport or an explicit Python upgrade")
    safe_pip(["install", "--upgrade", "pip>=26.2.2"])
    # New interpreter: do not inspect the pre-upgrade pip cached in sys.modules.
    subprocess.run([sys.executable, __file__, "check"], check=True)


def main():
    mode = sys.argv[1]
    if mode == "bootstrap":
        bootstrap()
    elif mode == "prerequisites":
        safe_pip(["install", "libtool", "asn1crypto", "cffi", "pycparser"])
    elif mode == "upgrade-app":
        check()
        # certifi is optional: Twisted-only installations use the OS roots.
        # Without --upgrade an already-fixed package is left alone. Constraints
        # remain in force, including when the installed package needs repair.
        if application_certifi() is not None:
            safe_pip(["install", "certifi>=2026.10.19"])
        subprocess.run([sys.executable, __file__, "app"], check=True)
    elif mode in ("check", "app"):
        check(app=mode == "app")
    else:
        raise RuntimeError("Unknown certificate check mode")


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, RuntimeError, subprocess.CalledProcessError) as error:
        sys.exit("Python certificate check failed: " + str(error))
