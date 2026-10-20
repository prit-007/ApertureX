#!/usr/bin/env python3
"""Remove AGP's "Dependency metadata" APK Signing Block.

AGP 9 adds signing block 0x504B4453 to release APKs. F-Droid's `check apk`
job rejects reference binaries containing it ("Found extra signing block
'Dependency metadata'"). The block is outside the data covered by APK
Signature Scheme v2, so removing it keeps the existing signature valid.

Usage:
    strip_dependency_metadata.py [--check] app/build/app/outputs/flutter-apk/*.apk
"""

from __future__ import annotations

import argparse
import struct
import sys
from pathlib import Path

APK_SIG_BLOCK_MAGIC = b"APK Sig Block 42"
DEPENDENCY_METADATA_ID = 0x504B4453
EOCD_MAGIC = b"PK\x05\x06"
EOCD_MIN_SIZE = 22


def find_eocd(data: bytes) -> int:
    """Return the offset of the ZIP end-of-central-directory record."""
    pos = len(data) - EOCD_MIN_SIZE
    while pos >= 0:
        if data[pos : pos + 4] == EOCD_MAGIC:
            comment_len = struct.unpack_from("<H", data, pos + 20)[0]
            if pos + EOCD_MIN_SIZE + comment_len == len(data):
                return pos
        pos -= 1
    raise ValueError("ZIP end-of-central-directory record not found")


def read_signing_block(data: bytes, cd_offset: int):
    """Return (block_start, [(id, raw_pair), ...]) or None if unsigned."""
    if cd_offset < 24 or data[cd_offset - 16 : cd_offset] != APK_SIG_BLOCK_MAGIC:
        return None

    size = struct.unpack_from("<Q", data, cd_offset - 24)[0]
    start = cd_offset - size - 8
    if start < 0:
        raise ValueError("APK Signing Block extends before start of file")

    pairs = []
    pos = start + 8
    end = cd_offset - 24
    while pos < end:
        if pos + 8 > end:
            raise ValueError("truncated APK Signing Block pair length")
        pair_len = struct.unpack_from("<Q", data, pos)[0]
        if pair_len < 4 or pos + 8 + pair_len > end:
            raise ValueError("invalid APK Signing Block pair length")
        pair_id = struct.unpack_from("<I", data, pos + 8)[0]
        pairs.append((pair_id, bytes(data[pos : pos + 8 + pair_len])))
        pos += 8 + pair_len

    if pos != end:
        raise ValueError("APK Signing Block size does not match its pairs")
    return start, pairs


def strip_apk(path: Path, check: bool = False) -> bool:
    """Remove dependency metadata from *path*.

    Returns True when the file contains the block. With ``check=True`` the file
    is not modified and finding the block is reported as a failure by main().
    """
    data = path.read_bytes()
    eocd = find_eocd(data)
    cd_offset = struct.unpack_from("<I", data, eocd + 16)[0]
    block = read_signing_block(data, cd_offset)
    if block is None:
        return False

    start, pairs = block
    kept = [pair for pair_id, pair in pairs if pair_id != DEPENDENCY_METADATA_ID]
    if len(kept) == len(pairs):
        return False

    if check:
        return True

    new_pairs = b"".join(kept)
    new_size = len(new_pairs) + 24
    new_block = (
        struct.pack("<Q", new_size)
        + new_pairs
        + struct.pack("<Q", new_size)
        + APK_SIG_BLOCK_MAGIC
    )
    new_cd_offset = start + len(new_block)
    output = bytearray(data[:start] + new_block + data[cd_offset:])

    new_eocd = find_eocd(output)
    struct.pack_into("<I", output, new_eocd + 16, new_cd_offset)
    path.write_bytes(output)
    return True


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="fail if the block is present")
    parser.add_argument("apks", nargs="+", type=Path)
    args = parser.parse_args(argv)

    failed = False
    for apk in args.apks:
        if not apk.is_file():
            parser.error(f"not a file: {apk}")
        try:
            found = strip_apk(apk, check=args.check)
        except ValueError as error:
            print(f"{apk}: {error}", file=sys.stderr)
            failed = True
            continue

        if args.check:
            if found:
                print(f"{apk}: contains Dependency metadata signing block", file=sys.stderr)
                failed = True
            else:
                print(f"{apk}: no Dependency metadata signing block")
        elif found:
            print(f"{apk}: removed Dependency metadata signing block")
        else:
            print(f"{apk}: no Dependency metadata signing block")

    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
