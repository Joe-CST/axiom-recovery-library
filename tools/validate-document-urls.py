#!/usr/bin/env python3
"""Probe every document URL without downloading the complete PDF."""

from __future__ import annotations

import argparse
import csv
import ssl
import urllib.error
import urllib.request
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path


def probe(row: dict[str, str]) -> tuple[str, bool, str]:
    name = row["filename"]
    request = urllib.request.Request(
        row["url"],
        headers={
            "User-Agent": "Mozilla/5.0 PrepperLibrarySourceValidator/1.7",
            "Range": "bytes=0-31",
            "Accept-Encoding": "identity",
        },
    )
    try:
        with urllib.request.urlopen(request, timeout=45, context=ssl.create_default_context()) as response:
            prefix = response.read(5)
            content_type = response.headers.get("Content-Type", "")
            ok = prefix == b"%PDF-"
            detail = f"HTTP {response.status}; {content_type}; prefix={prefix!r}"
            return name, ok, detail
    except Exception as error:  # noqa: BLE001 - diagnostics should include every source failure
        return name, False, f"{type(error).__name__}: {error}"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", type=Path)
    parser.add_argument("--workers", type=int, default=10)
    args = parser.parse_args()
    with args.manifest.open(newline="", encoding="utf-8") as stream:
        rows = list(csv.DictReader(stream))
    by_name = {row["filename"]: row for row in rows}
    failures = 0
    required_failures = 0
    with ThreadPoolExecutor(max_workers=max(1, args.workers)) as pool:
        futures = [pool.submit(probe, row) for row in rows]
        for future in as_completed(futures):
            name, ok, detail = future.result()
            marker = "OK" if ok else "FAIL"
            required = by_name[name]["required"].lower() == "true"
            print(f"{marker}\t{'required' if required else 'optional'}\t{name}\t{detail}", flush=True)
            if not ok:
                failures += 1
                required_failures += int(required)
    print(
        f"SUMMARY total={len(rows)} failed={failures} required_failed={required_failures}",
        flush=True,
    )
    return 1 if required_failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
