#!/usr/bin/env python3
"""Tests for the APK Dependency metadata signing-block stripper."""

from __future__ import annotations

import struct
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

import strip_dependency_metadata as strip  # noqa: E402


def pair(pair_id: int, value: bytes) -> bytes:
    return struct.pack("<Q", len(value) + 4) + struct.pack("<I", pair_id) + value


def signing_block(pairs: list[bytes]) -> bytes:
    payload = b"".join(pairs)
    size = len(payload) + 24
    return (
        struct.pack("<Q", size)
        + payload
        + struct.pack("<Q", size)
        + strip.APK_SIG_BLOCK_MAGIC
    )


def make_apk(pairs: list[bytes] | None) -> bytes:
    prefix = b"PK\x03\x04fake-local-file"
    block = signing_block(pairs) if pairs is not None else b""
    central_directory = b"PK\x01\x02fake-central-directory"
    central_offset = len(prefix) + len(block)
    eocd = bytearray(22)
    eocd[0:4] = strip.EOCD_MAGIC
    struct.pack_into("<I", eocd, 16, central_offset)
    return prefix + block + central_directory + bytes(eocd)


class StripDependencyMetadataTest(unittest.TestCase):
    def test_removes_only_dependency_metadata(self) -> None:
        v2 = pair(0x7109871A, b"v2-signature")
        dependency = pair(strip.DEPENDENCY_METADATA_ID, b"dependency-metadata")
        padding = pair(0x42726577, b"verity-padding")

        with tempfile.TemporaryDirectory() as directory:
            apk = Path(directory) / "app.apk"
            apk.write_bytes(make_apk([v2, dependency, padding]))

            self.assertTrue(strip.strip_apk(apk))

            data = apk.read_bytes()
            eocd = strip.find_eocd(data)
            central_offset = struct.unpack_from("<I", data, eocd + 16)[0]
            start, pairs = strip.read_signing_block(data, central_offset)
            ids = [pair_id for pair_id, _ in pairs]

            self.assertEqual(ids, [0x7109871A, 0x42726577])
            self.assertEqual(pairs[0][1], v2)
            self.assertEqual(pairs[1][1], padding)
            self.assertEqual(data[central_offset:][:4], b"PK\x01\x02")
            self.assertEqual(central_offset, start + len(signing_block([v2, padding])))

    def test_is_idempotent(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            apk = Path(directory) / "app.apk"
            apk.write_bytes(
                make_apk(
                    [
                        pair(0x7109871A, b"v2-signature"),
                        pair(strip.DEPENDENCY_METADATA_ID, b"dependency-metadata"),
                    ]
                )
            )

            self.assertTrue(strip.strip_apk(apk))
            once = apk.read_bytes()
            self.assertFalse(strip.strip_apk(apk))
            self.assertEqual(apk.read_bytes(), once)

    def test_check_mode_reports_block_without_modifying(self) -> None:
        original = make_apk(
            [
                pair(0x7109871A, b"v2-signature"),
                pair(strip.DEPENDENCY_METADATA_ID, b"dependency-metadata"),
            ]
        )
        with tempfile.TemporaryDirectory() as directory:
            apk = Path(directory) / "app.apk"
            apk.write_bytes(original)

            self.assertTrue(strip.strip_apk(apk, check=True))
            self.assertEqual(apk.read_bytes(), original)

    def test_unsigned_apk_is_ignored(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            apk = Path(directory) / "app.apk"
            apk.write_bytes(make_apk(None))

            self.assertFalse(strip.strip_apk(apk))

    def test_signing_block_without_dependency_metadata_is_ignored(self) -> None:
        original = make_apk([pair(0x7109871A, b"v2-signature")])
        with tempfile.TemporaryDirectory() as directory:
            apk = Path(directory) / "app.apk"
            apk.write_bytes(original)

            self.assertFalse(strip.strip_apk(apk))
            self.assertEqual(apk.read_bytes(), original)


if __name__ == "__main__":
    unittest.main()
