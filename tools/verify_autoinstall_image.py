#!/usr/bin/env python3
"""Verify the boot-partition payload inside a Prepper Library image."""

from __future__ import annotations

import argparse
import hashlib
import io
import struct
import sys
from pathlib import Path
from zipfile import ZipFile


FAT_TYPES = {0x01, 0x04, 0x06, 0x0B, 0x0C, 0x0E}


def fat_offset(image: Path) -> int:
    with image.open("rb") as stream:
        mbr = stream.read(512)
    assert mbr[510:512] == b"\x55\xaa", "invalid MBR signature"
    for index in range(4):
        entry = mbr[446 + index * 16 : 462 + index * 16]
        part_type = entry[4]
        first_lba = struct.unpack_from("<I", entry, 8)[0]
        sectors = struct.unpack_from("<I", entry, 12)[0]
        if part_type in FAT_TYPES and first_lba and sectors:
            return first_lba * 512
    raise AssertionError("FAT boot partition not found")


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("image", type=Path)
    parser.add_argument("builder_zip", type=Path)
    parser.add_argument("--dependency-dir", type=Path)
    parser.add_argument(
        "--expected-profile",
        choices=("core", "sd256", "sd512", "full"),
        default="full",
    )
    args = parser.parse_args()
    if args.dependency_dir:
        sys.path.insert(0, str(args.dependency_dir.resolve()))
    from pyfatfs.PyFatFS import PyFatFS

    required = [
        "user-data",
        "network-config",
        "meta-data",
        "PREPPER-READ-ME.txt",
        "prepper-autoinstall/prepper-builder.zip",
        "prepper-autoinstall/prepper-config.env",
        "prepper-autoinstall/prepper-autoinstall.env",
        "prepper-autoinstall/prepper-stage1.sh",
        "prepper-autoinstall/prepper-autoinstall.sh",
        "prepper-autoinstall/prepper-autoinstall.service",
    ]
    fat = PyFatFS(
        str(args.image), offset=fat_offset(args.image), read_only=True, lazy_load=False
    )
    try:
        missing = [path for path in required if not fat.exists(path)]
        assert not missing, f"missing payload files: {missing}"
        embedded_zip = fat.readbytes("prepper-autoinstall/prepper-builder.zip")
        assert digest(embedded_zip) == digest(args.builder_zip.read_bytes()), "builder ZIP mismatch"
        with ZipFile(io.BytesIO(embedded_zip)) as archive:
            assert archive.testzip() is None, "embedded builder ZIP is corrupt"
            version = archive.read("prepper-pi4-image/VERSION").decode().strip()
            assert version == "1.7.0", f"unexpected embedded builder version: {version}"
        user_data = fat.readtext("user-data")
        assert user_data.startswith("#cloud-config\n"), "invalid cloud-init header"
        assert "prepper-stage1.sh" in user_data, "cloud-init launcher is missing"
        assert "__ADMIN_PASSWORD_HASH__" not in user_data, "password placeholder remains"
        assert "ssh_pwauth: true" in user_data, "SSH password authentication is disabled"
        assert "enable_ssh: true" in user_data, "SSH is not enabled on first boot"
        assert "PasswordAuthentication yes" in user_data, "sshd password setting is missing"
        assert "PermitRootLogin no" in user_data, "direct SSH root login is not disabled"
        config = fat.readtext("prepper-autoinstall/prepper-config.env")
        assert "REPLACE-WITH" not in config, "hotspot password placeholder remains"
        assert f"CONTENT_PROFILE={args.expected_profile}" in config, (
            f"image does not use {args.expected_profile} content profile"
        )
        cmdline = fat.readtext("cmdline.txt")
        assert "rootdelay=10" in cmdline.split(), "boot-device delay is missing"
        service = fat.readtext("prepper-autoinstall/prepper-autoinstall.service")
        assert "After=network-online.target cloud-final.service" in service, (
            "autoinstall service does not wait for cloud-final"
        )
        with ZipFile(io.BytesIO(embedded_zip)) as archive:
            installer = archive.read("prepper-pi4-image/install.sh").decode()
            assert "Raspberry Pi 3 Model B" in installer, "Pi 3 support is missing"
            assert "Raspberry Pi 4 Model B" in installer, "Pi 4 support is missing"
            assert "Raspberry Pi 5 Model B" in installer, "Pi 5 support is missing"
            assert "nmcli connection up prepper-hotspot ifname wlan0" in installer, (
                "hotspot activation is not bound to wlan0"
            )
            assert "for _attempt in $(seq 1 30)" in installer, (
                "hotspot activation retry loop is missing"
            )
            assert "openssh-server" in installer, "OpenSSH server package is missing"
            assert "prepper-download-maps" in installer, "offline map installer is missing"
            assert "prepper-download-all" in installer, "shared content orchestrator is missing"
            assert "prepper-build-catalog" in installer, "search catalog builder is missing"
            assert "prepper-content-download.service" in installer, (
                "persistent content download service is not enabled"
            )
            service = archive.read(
                "prepper-pi4-image/systemd/prepper-content-download.service"
            ).decode()
            assert "EnvironmentFile=/etc/prepper-library/config.env" in service, (
                "content service does not load the selected image profile"
            )
            assert "${CONTENT_PROFILE}" in service, (
                "content service does not resume the selected image profile"
            )
            orchestrator = archive.read(
                "prepper-pi4-image/scripts/prepper-download-all"
            ).decode()
            for profile in ("sd256", "sd512", "full"):
                assert profile in orchestrator, f"content profile is missing: {profile}"
            assert "PREPPER_RESERVE_GIB=24" in orchestrator, "256 GB reserve is missing"
            assert "PREPPER_RESERVE_GIB=48" in orchestrator, "512 GB reserve is missing"
            assert "PREPPER_RESERVE_GIB=80" in orchestrator, "1 TB reserve is missing"
            kiwix_start = archive.read(
                "prepper-pi4-image/scripts/prepper-kiwix-start"
            ).decode()
            assert "Raspberry Pi 3" in kiwix_start and "THREADS=2" in kiwix_start, (
                "Pi 3 memory tuning is missing"
            )
            assert "north-america-region.geojson" in installer, "map coverage is missing"
            assert "pmtiles-linux-arm64.tar.gz" in installer, "PMTiles CLI is missing"
            map_downloader = archive.read(
                "prepper-pi4-image/scripts/prepper-download-maps"
            ).decode()
            assert "build.protomaps.com" in map_downloader, "map source is missing"
            assert "--maxzoom=15" in map_downloader, "street-level map detail is missing"
            map_page = archive.read(
                "prepper-pi4-image/assets/maps/web/index.html"
            ).decode()
            assert "Offline North America Map" in map_page, "offline map page is missing"
            maplibre = archive.read(
                "prepper-pi4-image/assets/maps/web/vendor/maplibre-gl.js"
            ).decode()
            assert "maplibre-gl-worker.js" in maplibre, "MapLibre worker reference is missing"
            assert "maplibre-gl-worker.mjs" not in maplibre, "MapLibre worker uses an unsupported extension"
            worker = archive.read(
                "prepper-pi4-image/assets/maps/web/vendor/maplibre-gl-worker.js"
            )
            assert len(worker) > 400_000, "MapLibre worker is missing or incomplete"
            autoinstall = archive.read(
                "prepper-pi4-image/autoinstall/prepper-autoinstall.sh"
            ).decode()
            assert '/usr/local/sbin/prepper-download-all "${CONTENT_PROFILE}"' in autoinstall, (
                "autoinstall does not use the shared content orchestrator"
            )
            for portal_file in ("guide.html", "library.html", "library.js", "costa-logo.png"):
                assert f"prepper-pi4-image/assets/portal/{portal_file}" in archive.namelist(), (
                    f"mobile portal asset is missing: {portal_file}"
                )
    finally:
        fat.close()
    print("PASS: boot partition, cloud-init launcher, configuration, and embedded ZIP verified")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
