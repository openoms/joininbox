#!/usr/bin/env python3
"""Set JoinMarket NG connection settings in an existing TOML template."""

from __future__ import annotations

import argparse
import configparser
import json
import os
from dataclasses import dataclass
from pathlib import Path
import re
import stat
import tempfile
import tomllib
from typing import Sequence


VALID_NETWORKS = frozenset({"mainnet", "testnet", "signet", "regtest"})
DEFAULT_TOR_COOKIE_PATH = "/run/tor/control.authcookie"
TABLE_HEADER_PATTERN = re.compile(r"^\s*(?:\[\[.*\]\]|\[.*\])\s*(?:#.*)?$")
TARGET_SECTION_PATTERN = re.compile(
    r"^\s*\[(tor|bitcoin|network_config)\]\s*(?:#.*)?$"
)


class ConfigurationError(Exception):
    """Raised when configuration input cannot be safely applied."""


@dataclass(frozen=True)
class RpcSettings:
    network: str
    rpc_user: str
    rpc_password: str
    rpc_host: str
    rpc_port: int


TARGET_VALUES = {
    "bitcoin": lambda settings, _cookie_path: {
        "backend_type": "descriptor_wallet",
        "rpc_url": f"http://{settings.rpc_host}:{settings.rpc_port}",
        "rpc_user": settings.rpc_user,
        "rpc_password": settings.rpc_password,
    },
    "network_config": lambda settings, _cookie_path: {
        "network": settings.network,
    },
    "tor": lambda _settings, cookie_path: {
        "socks_host": "127.0.0.1",
        "socks_port": 9050,
        "control_enabled": True,
        "control_host": "127.0.0.1",
        "control_port": 9051,
        "cookie_path": cookie_path,
    },
}


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Set JoinMarket NG connection settings in an existing config.toml."
    )
    parser.add_argument("--config", required=True, type=Path, metavar="PATH")
    parser.add_argument("--legacy-config", type=Path, metavar="PATH")
    parser.add_argument("--network")
    parser.add_argument("--rpc-user")
    password_group = parser.add_mutually_exclusive_group()
    password_group.add_argument("--rpc-password")
    password_group.add_argument("--rpc-password-file", type=Path, metavar="PATH")
    parser.add_argument("--rpc-host")
    parser.add_argument("--rpc-port", type=int)
    parser.add_argument(
        "--tor-cookie-path", default=DEFAULT_TOR_COOKIE_PATH, metavar="PATH"
    )
    return parser


def require_legacy_value(parser: configparser.ConfigParser, key: str) -> str:
    if not parser.has_option("BLOCKCHAIN", key):
        raise ConfigurationError(f"legacy configuration is missing BLOCKCHAIN.{key}")
    return parser.get("BLOCKCHAIN", key)


def read_legacy_settings(path: Path) -> RpcSettings:
    legacy = configparser.ConfigParser(interpolation=None)
    try:
        with path.open(encoding="utf-8") as source:
            legacy.read_file(source)
    except (OSError, UnicodeError, configparser.Error) as error:
        raise ConfigurationError("could not read legacy configuration") from error

    if not legacy.has_section("BLOCKCHAIN"):
        raise ConfigurationError("legacy configuration is missing BLOCKCHAIN section")

    port_text = require_legacy_value(legacy, "rpc_port")
    try:
        rpc_port = int(port_text)
    except ValueError as error:
        raise ConfigurationError("legacy configuration has an invalid rpc_port") from error

    return RpcSettings(
        network=require_legacy_value(legacy, "network"),
        rpc_user=require_legacy_value(legacy, "rpc_user"),
        rpc_password=require_legacy_value(legacy, "rpc_password"),
        rpc_host=require_legacy_value(legacy, "rpc_host"),
        rpc_port=rpc_port,
    )


def explicit_settings(arguments: argparse.Namespace) -> RpcSettings:
    rpc_password = arguments.rpc_password
    if arguments.rpc_password_file is not None:
        try:
            rpc_password = arguments.rpc_password_file.read_text(encoding="utf-8")
        except (OSError, UnicodeError) as error:
            raise ConfigurationError("could not read RPC password file") from error
    if rpc_password is None:
        raise ConfigurationError("rpc_password is unavailable")

    return RpcSettings(
        network=arguments.network,
        rpc_user=arguments.rpc_user,
        rpc_password=rpc_password,
        rpc_host=arguments.rpc_host,
        rpc_port=arguments.rpc_port,
    )


def input_settings(arguments: argparse.Namespace, parser: argparse.ArgumentParser) -> RpcSettings:
    explicit_names = ("network", "rpc_user", "rpc_host", "rpc_port")
    explicit_present = [name for name in explicit_names if getattr(arguments, name) is not None]
    password_present = (
        arguments.rpc_password is not None or arguments.rpc_password_file is not None
    )

    if arguments.legacy_config is not None:
        if explicit_present or password_present:
            parser.error("--legacy-config cannot be combined with explicit RPC options")
        return read_legacy_settings(arguments.legacy_config)

    if len(explicit_present) != len(explicit_names) or not password_present:
        parser.error(
            "explicit mode requires --network, --rpc-user, --rpc-password or "
            "--rpc-password-file, --rpc-host, and --rpc-port"
        )
    return explicit_settings(arguments)


def validate_settings(settings: RpcSettings) -> None:
    if settings.network not in VALID_NETWORKS:
        raise ConfigurationError("network must be mainnet, testnet, signet, or regtest")
    if not settings.rpc_user:
        raise ConfigurationError("rpc_user must not be empty")
    if not settings.rpc_host:
        raise ConfigurationError("rpc_host must not be empty")
    if not 1 <= settings.rpc_port <= 65535:
        raise ConfigurationError("rpc_port must be between 1 and 65535")


def read_destination(path: Path) -> tuple[str, int]:
    try:
        file_status = path.lstat()
    except OSError as error:
        raise ConfigurationError("destination configuration does not exist") from error

    if not stat.S_ISREG(file_status.st_mode):
        raise ConfigurationError("destination configuration must be a regular file")

    try:
        content = path.read_text(encoding="utf-8")
        tomllib.loads(content)
    except (OSError, UnicodeError, tomllib.TOMLDecodeError) as error:
        raise ConfigurationError("destination configuration is not valid TOML") from error
    return content, stat.S_IMODE(file_status.st_mode)


def line_ending(lines: list[str]) -> str:
    for line in lines:
        if line.endswith("\r\n"):
            return "\r\n"
        if line.endswith("\n"):
            return "\n"
    return "\n"


def target_sections(lines: list[str]) -> dict[str, tuple[int, int]]:
    section_headers: list[int] = []
    required: dict[str, int] = {}

    for index, line in enumerate(lines):
        if TABLE_HEADER_PATTERN.match(line):
            section_headers.append(index)
            target_match = TARGET_SECTION_PATTERN.match(line)
            if target_match:
                required[target_match.group(1)] = index

    missing = set(TARGET_VALUES) - set(required)
    if missing:
        raise ConfigurationError(
            "destination configuration is missing required section(s): "
            + ", ".join(sorted(missing))
        )

    sections: dict[str, tuple[int, int]] = {}
    for name, start in required.items():
        end = next((header for header in section_headers if header > start), len(lines))
        sections[name] = (start, end)
    return sections


def setting_line(key: str, value: str | int | bool, indentation: str, ending: str) -> str:
    if isinstance(value, str):
        rendered_value = json.dumps(value, ensure_ascii=True)
    elif isinstance(value, bool):
        rendered_value = str(value).lower()
    else:
        rendered_value = str(value)
    return f"{indentation}{key} = {rendered_value}{ending}"


def update_section(
    lines: list[str], start: int, end: int, values: dict[str, str | int | bool], ending: str
) -> list[str]:
    active: dict[str, tuple[int, str]] = {}
    commented: dict[str, tuple[int, str]] = {}

    for index in range(start + 1, end):
        line = lines[index]
        for key in values:
            stripped = line.lstrip(" \t")
            indentation = line[: len(line) - len(stripped)]
            if stripped.startswith(f"{key}") and stripped[len(key) :].lstrip(" \t").startswith("="):
                active[key] = (index, indentation)
            elif stripped.startswith("#"):
                uncommented = stripped[1:].lstrip(" \t")
                if uncommented.startswith(f"{key}") and uncommented[len(key) :].lstrip(
                    " \t"
                ).startswith("="):
                    commented.setdefault(key, (index, indentation))

    replacements: dict[int, str] = {}
    missing: list[str] = []
    for key, value in values.items():
        location = active.get(key) or commented.get(key)
        if location is None:
            missing.append(key)
            continue
        index, indentation = location
        replacements[index] = setting_line(key, value, indentation, ending)

    updated = [
        replacements.get(index, line)
        for index, line in enumerate(lines[start:end], start=start)
    ]
    if missing:
        if updated and not updated[-1].endswith(("\n", "\r")):
            updated[-1] += ending
        updated.extend(setting_line(key, values[key], "", ending) for key in missing)
    return updated


def render_configuration(content: str, settings: RpcSettings, cookie_path: str) -> str:
    lines = content.splitlines(keepends=True)
    ending = line_ending(lines)
    values_by_section = {
        name: builder(settings, cookie_path) for name, builder in TARGET_VALUES.items()
    }
    sections = target_sections(lines)

    for name, (start, end) in sorted(sections.items(), key=lambda item: item[1][0], reverse=True):
        lines[start:end] = update_section(lines, start, end, values_by_section[name], ending)

    rendered = "".join(lines)
    try:
        tomllib.loads(rendered)
    except tomllib.TOMLDecodeError as error:
        raise ConfigurationError("updated destination configuration is not valid TOML") from error
    return rendered


def write_atomically(path: Path, content: str, mode: int) -> None:
    temporary_path: Path | None = None
    try:
        with tempfile.NamedTemporaryFile(
            mode="w", encoding="utf-8", dir=path.parent, prefix=f".{path.name}.", delete=False
        ) as temporary:
            temporary_path = Path(temporary.name)
            temporary.write(content)
            temporary.flush()
            os.fsync(temporary.fileno())
        os.chmod(temporary_path, mode)
        os.replace(temporary_path, path)
    except OSError as error:
        raise ConfigurationError("could not atomically write destination configuration") from error
    finally:
        if temporary_path is not None:
            try:
                temporary_path.unlink()
            except FileNotFoundError:
                pass


def main(argv: Sequence[str] | None = None) -> int:
    parser = build_parser()
    arguments = parser.parse_args(argv)
    try:
        settings = input_settings(arguments, parser)
        validate_settings(settings)
        content, mode = read_destination(arguments.config)
        rendered = render_configuration(content, settings, arguments.tor_cookie_path)
        write_atomically(arguments.config, rendered, mode)
    except ConfigurationError as error:
        print(f"error: {error}", file=os.sys.stderr)
        return 1

    rpc_over_tor = settings.rpc_host.lower().endswith(".onion")
    print(
        f"Updated {arguments.config} for {settings.network} "
        f"(rpc_over_tor={'on' if rpc_over_tor else 'off'})"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
