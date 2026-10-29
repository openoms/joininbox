"""Read the pinned public JoinMarket installer without modifying its checkout."""
from pathlib import Path
import subprocess

COMMIT = "77a426c504cbf6fa56ba0316dfd8da63a76d2bbf"


def public_installer(checkout):
    checkout = Path(checkout).resolve()

    def git(*args):
        return subprocess.check_output(["git", "-C", str(checkout), *args])

    if git("rev-parse", "v0.9.12^{commit}").decode().strip() != COMMIT:
        raise ValueError("v0.9.12 must resolve to the pinned public JoinMarket commit")
    if git("rev-parse", "HEAD").decode().strip() != COMMIT:
        raise ValueError("checkout must be at the public v0.9.12 commit")
    original = git("show", COMMIT + ":install.sh")
    if (checkout / "install.sh").read_bytes() != original:
        raise ValueError("checkout install.sh must be unpatched public v0.9.12")
    return original.decode()
