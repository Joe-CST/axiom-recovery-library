#!/usr/bin/env python3
"""Inject the Prepper Library ZIP and cloud-init launcher into a Pi OS image."""

from __future__ import annotations

import argparse
import hashlib
import re
import secrets
import shlex
import shutil
import struct
import sys
from pathlib import Path


SAFE_VALUE = re.compile(r"^[A-Za-z0-9._-]+$")
COUNTRY = re.compile(r"^[A-Z]{2}$")
FAT_TYPES = {0x01, 0x04, 0x06, 0x0B, 0x0C, 0x0E}


def parser() -> argparse.ArgumentParser:
    result = argparse.ArgumentParser(description=__doc__)
    result.add_argument("--base-image", type=Path, required=True)
    result.add_argument("--output-image", type=Path, required=True)
    result.add_argument("--builder-zip", type=Path, required=True)
    result.add_argument("--project-dir", type=Path, required=True)
    result.add_argument("--credentials-file", type=Path, required=True)
    result.add_argument("--dependency-dir", type=Path)
    result.add_argument("--country", default="US")
    result.add_argument(
        "--profile", choices=("core", "sd256", "sd512", "full"), default="full"
    )
    result.add_argument("--ssid", default="PREP-LIBRARY")
    result.add_argument("--hotspot-password")
    result.add_argument("--admin-password")
    result.add_argument(
        "--fixed-identity",
        action="store_true",
        help="Keep the configured hostname and SSID exactly as supplied",
    )
    return result


def checked_value(label: str, value: str, minimum: int = 1, maximum: int = 63) -> str:
    if not minimum <= len(value) <= maximum or not SAFE_VALUE.fullmatch(value):
        raise SystemExit(
            f"{label} must be {minimum}-{maximum} characters using only letters, "
            "numbers, dot, underscore, or dash"
        )
    return value


def random_password(length: int = 24) -> str:
    alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789"
    return "".join(secrets.choice(alphabet) for _ in range(length))


def checked_wpa_password(value: str) -> str:
    if not 8 <= len(value) <= 63:
        raise SystemExit("Hotspot password must contain 8-63 ASCII characters")
    if any(ord(character) < 32 or ord(character) > 126 for character in value):
        raise SystemExit("Hotspot password must contain printable ASCII characters only")
    return value


def mbr_fat_offset(image: Path) -> int:
    with image.open("rb") as stream:
        mbr = stream.read(512)
    if len(mbr) != 512 or mbr[510:512] != b"\x55\xaa":
        raise SystemExit("The base image does not contain a valid MBR partition table")
    candidates: list[tuple[int, int, int]] = []
    for index in range(4):
        entry = mbr[446 + index * 16 : 462 + index * 16]
        part_type = entry[4]
        first_lba = struct.unpack_from("<I", entry, 8)[0]
        sectors = struct.unpack_from("<I", entry, 12)[0]
        if first_lba and sectors:
            candidates.append((part_type, first_lba, sectors))
    for part_type, first_lba, _sectors in candidates:
        if part_type in FAT_TYPES:
            return first_lba * 512
    raise SystemExit("No FAT boot partition was found in the base image")


def write_payload(
    image: Path,
    project: Path,
    builder_zip: Path,
    config: bytes,
    autoinstall_env: bytes,
    user_data: bytes,
) -> None:
    from pyfatfs.PyFatFS import PyFatFS

    offset = mbr_fat_offset(image)
    fat = PyFatFS(
        str(image), offset=offset, preserve_case=True, read_only=False, lazy_load=False
    )
    try:
        if not fat.exists("config.txt"):
            raise SystemExit("FAT partition does not look like a Raspberry Pi boot partition")
        if not fat.exists("prepper-autoinstall"):
            fat.makedir("prepper-autoinstall")

        cmdline = fat.readtext("cmdline.txt").strip()
        if "rootdelay=" not in cmdline:
            cmdline = f"{cmdline} rootdelay=10"

        files = {
            "cmdline.txt": f"{cmdline}\n".encode("ascii"),
            "prepper-autoinstall/prepper-builder.zip": builder_zip.read_bytes(),
            "prepper-autoinstall/prepper-config.env": config,
            "prepper-autoinstall/prepper-autoinstall.env": autoinstall_env,
            "prepper-autoinstall/prepper-stage1.sh": (
                project / "autoinstall" / "prepper-stage1.sh"
            ).read_bytes(),
            "prepper-autoinstall/prepper-autoinstall.sh": (
                project / "autoinstall" / "prepper-autoinstall.sh"
            ).read_bytes(),
            "prepper-autoinstall/prepper-autoinstall.service": (
                project / "autoinstall" / "prepper-autoinstall.service"
            ).read_bytes(),
            "user-data": user_data,
            "network-config": (project / "autoinstall" / "network-config").read_bytes(),
            "meta-data": (project / "autoinstall" / "meta-data").read_bytes(),
            "PREPPER-READ-ME.txt": (
                "Prepper Library autoinstall image\r\n"
                "\r\n"
                "Flash this image directly to a card or SSD of its labeled size.\r\n"
                "Use a Raspberry Pi 3B/B+, Pi 4B, or Pi 5B; attach Ethernet, then\r\n"
                "power on. Do not remove power while PREPPER-INSTALL.log changes.\r\n"
                "PREPPER_READY.txt will\r\n"
                "appear here when the offline library is complete.\r\n"
            ).encode("ascii"),
        }
        for destination, data in files.items():
            print(f"Injecting {destination} ({len(data)} bytes)", flush=True)
            if fat.exists(destination):
                fat.remove(destination)
            fat.writebytes(destination, data)
    finally:
        fat.close()


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(16 * 1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def main() -> int:
    args = parser().parse_args()
    if args.dependency_dir:
        sys.path.insert(0, str(args.dependency_dir.resolve()))
    try:
        from passlib.hash import sha512_crypt
        from pyfatfs.PyFatFS import PyFatFS as _PyFatFS  # noqa: F401
    except ImportError as error:
        raise SystemExit(
            "Install dependencies first: python -m pip install pyfatfs passlib"
        ) from error

    if not COUNTRY.fullmatch(args.country):
        raise SystemExit("--country must be a two-letter uppercase regulatory code")
    ssid = checked_value("SSID", args.ssid, 1, 28)
    hotspot_password = checked_wpa_password(args.hotspot_password or random_password())
    admin_password = checked_value(
        "Administrator password", args.admin_password or random_password(), 16, 63
    )

    for required in (args.base_image, args.builder_zip, args.project_dir):
        if not required.exists():
            raise SystemExit(f"Missing required input: {required}")
    args.output_image.parent.mkdir(parents=True, exist_ok=True)
    args.credentials_file.parent.mkdir(parents=True, exist_ok=True)
    if args.base_image.resolve() != args.output_image.resolve():
        shutil.copyfile(args.base_image, args.output_image)

    config = (
        f"HOTSPOT_SSID={ssid}\n"
        f"HOTSPOT_PASSWORD={shlex.quote(hotspot_password)}\n"
        f"WIFI_COUNTRY={args.country}\n"
        "BOX_HOSTNAME=box\n"
        "HOTSPOT_ADDRESS=10.10.10.1/24\n"
        f"CONTENT_PROFILE={args.profile}\n"
        f"UNIQUE_CLONE_IDENTITY={'false' if args.fixed_identity else 'true'}\n"
    ).encode("utf-8")
    autoinstall_env = f"CONTENT_PROFILE={args.profile}\n".encode("ascii")
    password_hash = sha512_crypt.using(rounds=656000).hash(admin_password)
    user_data = (
        args.project_dir / "autoinstall" / "user-data.template"
    ).read_text(encoding="utf-8").replace("__ADMIN_PASSWORD_HASH__", password_hash).encode("utf-8")

    write_payload(
        args.output_image,
        args.project_dir,
        args.builder_zip,
        config,
        autoinstall_env,
        user_data,
    )

    identity_note = (
        "The Wi-Fi name remains exactly as shown.\n"
        if args.fixed_identity
        else "The Pi adds a four-character suffix on first boot.\n"
    )
    args.credentials_file.write_text(
        "PREPPER LIBRARY CREDENTIALS\n"
        "===========================\n\n"
        f"Wi-Fi base name: {ssid}\n"
        f"{identity_note}"
        f"Wi-Fi password: {hotspot_password}\n"
        "Portal: http://10.10.10.1\n"
        "Local administrator: prepper\n"
        f"Local administrator password: {admin_password}\n"
        f"Wi-Fi regulatory country: {args.country}\n"
        f"Content profile: {args.profile}\n\n"
        "Keep this file somewhere safe. SSH password login is enabled for the prepper account.\n"
        "Direct SSH login as root is disabled.\n",
        encoding="utf-8",
    )
    print(f"Created: {args.output_image}")
    print(f"SHA-256: {sha256(args.output_image)}")
    print(f"Credentials: {args.credentials_file}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
